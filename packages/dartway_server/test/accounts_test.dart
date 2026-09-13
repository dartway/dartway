import 'package:dartway_server/dartway_server.dart';
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  Future<int> identities(String value) async => (await harness().db.query(
    'SELECT count(*) AS n FROM dw_identity WHERE value = @value',
    params: {'value': value},
  )).single.get<int>('n');

  group('server.accounts', () {
    test('ensure creates once, normalizes, runs onAccountCreated in the same '
        'transaction; find sees it', () async {
      final accounts = harness().server.server.accounts;
      final created = await accounts.ensure(
        DwIdentifierKind.email,
        ' Admin@Example.com ',
      );
      expect(created.created, isTrue);
      expect(harness().app.createdAccounts, contains(created.accountId));
      final profile = await harness().db.query(
        'SELECT name, identifier FROM profile WHERE account_id = @id',
        params: {'id': created.accountId},
      );
      expect(profile.single['identifier'], 'admin@example.com');
      expect(profile.single['name'], '', reason: 'empty registration');

      final again = await accounts.ensure(
        DwIdentifierKind.email,
        'admin@example.com',
      );
      expect(again, (accountId: created.accountId, created: false));
      expect(
        await accounts.find(DwIdentifierKind.email, 'ADMIN@example.com'),
        created.accountId,
      );
      expect(
        await accounts.find(DwIdentifierKind.email, 'nobody@example.com'),
        isNull,
      );
    });

    test('an identifier normalize rejects is an ArgumentError', () async {
      final accounts = harness().server.server.accounts;
      await expectLater(
        accounts.ensure(DwIdentifierKind.phone, 'not a phone'),
        throwsArgumentError,
      );
      expect(
        () => accounts.find(DwIdentifierKind.email, 'no-at-sign'),
        throwsArgumentError,
      );
    });

    test('concurrent ensures, and a sign-in of the same identifier, share '
        'one account', () async {
      const email = 'race-ensure@example.com';
      final accounts = harness().server.server.accounts;
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          accounts.ensure(DwIdentifierKind.email, email),
      ]);
      expect(results.map((r) => r.accountId).toSet(), hasLength(1));
      expect(results.where((r) => r.created), hasLength(1));
      expect(await identities(email), 1);

      final connection = await harness().connect();
      final session = await harness().app.signIn(connection, email);
      expect(session.id, results.first.accountId);
      expect(session.isNewAccount, isFalse);
      await connection.close();
    });

    test('revokeKeys closes the live sessions of every key of the account, '
        'and only of that account', () async {
      final (first, session) = await harness().signedIn('revoked@example.com');
      final second = await harness().connect();
      await second.authenticate(session.token);
      final (bystander, _) = await harness().signedIn('kept@example.com');
      for (final c in [first, second, bystander]) {
        expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
      }

      await harness().server.server.accounts.revokeKeys(session.id);

      for (final c in [first, second]) {
        expect((await c.expect<DwChannelClosedMessage>()).channel, 'notes');
        expect((await c.expect<DwAuthenticatedMessage>()).rejected, isTrue);
      }
      await bystander.expectSilence();
      expect(
        (await first.authenticate(session.token)).rejected,
        isTrue,
        reason: 'the key is revoked in the database',
      );
      for (final c in [first, second, bystander]) {
        await c.close();
      }
    });
  });

  group('ctx.accounts', () {
    test('revokeKeys takes effect after the command commits, and not at all '
        'when it is refused', () async {
      final (admin, _) = await harness().signedIn('ctx-admin@example.com');
      final (victim, session) = await harness().signedIn(
        'ctx-victim@example.com',
      );
      expect(await victim.subscribe('notes'), isA<DwSubscribedMessage>());

      final refused = await admin.command(
        RevokeSessions(session.id, ending: 'refuse'),
      );
      expect(refused.status, DwResultStatus.refused);
      await victim.expectSilence();
      expect(
        (await victim.request(const MyNotes())).status,
        DwResultStatus.ok,
        reason: 'the revocation rolled back with the refusal',
      );

      expect(
        (await admin.command(RevokeSessions(session.id))).status,
        DwResultStatus.ok,
      );
      expect((await victim.expect<DwChannelClosedMessage>()).channel, 'notes');
      expect((await victim.expect<DwAuthenticatedMessage>()).rejected, isTrue);
      expect(
        (await victim.request(const MyNotes())).status,
        DwResultStatus.unauthenticated,
      );
      await admin.close();
      await victim.close();
    });

    test('ensure inside a command joins its transaction', () async {
      final connection = await harness().connect();
      final result = await connection.command(
        const EnsureAccount('from-command@example.com'),
      );
      final id = result.okCommandValue(const EnsureAccount(''), testProtocol);
      expect(
        await harness().server.server.accounts.find(
          DwIdentifierKind.email,
          'from-command@example.com',
        ),
        id,
      );
      await connection.close();
    });
  });

  group('DwAccounts over a bare database', () {
    test('creates with onAccountCreated bound to the transaction', () async {
      final accounts = DwAccounts(harness().db, harness().app.auth());
      final created = await accounts.ensure(
        DwIdentifierKind.phone,
        '+15550001111',
      );
      expect(created.created, isTrue);
      final profile = await harness().db.query(
        'SELECT identifier FROM profile WHERE account_id = @id',
        params: {'id': created.accountId},
      );
      expect(profile.single['identifier'], '+15550001111');
      expect(
        await accounts.find(DwIdentifierKind.phone, '+15550001111'),
        created.accountId,
      );
    });

    test('a hook that publishes throws instead of dropping it, and the '
        'account is not created', () async {
      final base = harness().app.auth();
      final auth = DwAuth(
        normalize: base.normalize,
        deliverCode: base.deliverCode,
        onAccountCreated:
            (ctx, accountId, kind, identifier, registration) async =>
                ctx.publish(
                  const DwChannel(TestChannel.notes),
                  NoteView(id: accountId, text: 'welcome'),
                ),
      );
      final accounts = DwAccounts(harness().db, auth);
      await expectLater(
        accounts.ensure(DwIdentifierKind.email, 'detached@example.com'),
        throwsStateError,
      );
      expect(
        await accounts.find(DwIdentifierKind.email, 'detached@example.com'),
        isNull,
      );
    });
  });
}
