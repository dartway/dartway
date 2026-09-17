import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  Future<int> identities(String value) async => (await harness().db.query(
    'SELECT count(*) AS n FROM dw_identity WHERE value = @value',
    params: {'value': value},
  )).single.get<int>('n');

  DwAccountService accounts() => harness().server.server.accounts;

  group('deleting an account', () {
    Future<int> countOf(String table, int accountId) async =>
        (await harness().db.query(
          'SELECT count(*)::int AS n FROM $table WHERE account_id = @id',
          params: {'id': accountId},
        )).single.get<int>('n');

    test('DwDeleteMyAccount removes the account, its identities, its keys and '
        "the project's rows, and ends its sessions", () async {
      const email = 'leaving@example.com';
      final session = await harness().app.signIn(harness().caller(), email);
      final member = harness().caller(token: session.token);

      final answer = await member.call(const DwDeleteMyAccount());
      expect(answer.status, 200, reason: answer.text);

      expect(await identities(email), 0);
      expect(await countOf('profile', session.id), 0);
      expect(await countOf('dw_auth_key', session.id), 0);
      expect(
        await harness().db.query(
          'SELECT 1 FROM dw_account WHERE id = @id',
          params: {'id': session.id},
        ),
        isEmpty,
      );
      expect(
        (await member.call(const DwSignOut())).status,
        401,
        reason: 'the session ended with the account',
      );

      // The identifier is free: it makes a new account.
      final again = await accounts().ensure(DwIdentifierKind.email, email);
      expect(again.created, isTrue);
      expect(again.accountId, isNot(session.id));
    });

    test(
      'a refusing onAccountDeleting keeps the account and its session',
      () async {
        final session = await harness().app.signIn(
          harness().caller(),
          'staying@example.com',
        );
        harness().app.undeletable.add(session.id);
        final member = harness().caller(token: session.token);

        final answer = await member.call(const DwDeleteMyAccount());
        expect(answer.status, 403, reason: answer.text);
        expect(await countOf('profile', session.id), 1);
        expect(await identities('staying@example.com'), 1);
        expect((await member.call(const DwSignOut())).status, 200);
      },
    );

    test('signed out, there is nothing to delete', () async {
      expect(
        (await harness().caller().call(const DwDeleteMyAccount())).status,
        401,
      );
    });
  });

  group('server.accounts', () {
    test('ensure creates once, normalizes, runs onAccountCreated in the same '
        'transaction; find sees it', () async {
      final created = await accounts().ensure(
        DwIdentifierKind.email,
        ' Admin@Example.com ',
      );
      expect(created.created, isTrue);
      expect(harness().app.createdAccounts, contains(created.accountId));
      expect(
        harness().app.accountOrigins[created.accountId],
        isA<DwToolOrigin>(),
        reason: 'a tool, not a sign-in without registration',
      );
      final profile = await harness().db.query(
        'SELECT name, identifier FROM profile WHERE account_id = @id',
        params: {'id': created.accountId},
      );
      expect(profile.single['identifier'], 'admin@example.com');
      expect(profile.single['name'], '', reason: 'empty registration');

      final again = await accounts().ensure(
        DwIdentifierKind.email,
        'admin@example.com',
      );
      expect(again, (accountId: created.accountId, created: false));
      expect(
        await accounts().find(DwIdentifierKind.email, 'ADMIN@example.com'),
        created.accountId,
      );
      expect(
        await accounts().find(DwIdentifierKind.email, 'nobody@example.com'),
        isNull,
      );
    });

    test('an identifier normalize rejects is an ArgumentError', () async {
      await expectLater(
        accounts().ensure(DwIdentifierKind.phone, 'not a phone'),
        throwsArgumentError,
      );
      expect(
        () => accounts().find(DwIdentifierKind.email, 'no-at-sign'),
        throwsArgumentError,
      );
    });

    test('concurrent ensures, and a sign-in of the same identifier, share '
        'one account', () async {
      const email = 'race-ensure@example.com';
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          accounts().ensure(DwIdentifierKind.email, email),
      ]);
      expect(results.map((r) => r.accountId).toSet(), hasLength(1));
      expect(results.where((r) => r.created), hasLength(1));
      expect(await identities(email), 1);

      final session = await harness().app.signIn(harness().caller(), email);
      expect(session.id, results.first.accountId);
      expect(session.isNewAccount, isFalse);
    });

    test('revokeKeys closes the live sessions of every key of the account, '
        'and only of that account', () async {
      final (_, session) = await harness().signedIn('live-revoked@example.com');
      final first = await harness().live(token: session.token);
      final second = await harness().live(token: session.token);
      final (_, keptSession) = await harness().signedIn(
        'live-kept@example.com',
      );
      final bystander = await harness().live(token: keptSession.token);
      for (final c in [first, second, bystander]) {
        expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
      }

      await accounts().revokeKeys(session.id);

      for (final c in [first, second]) {
        expect((await c.expect<DwChannelClosedMessage>()).channel, 'notes');
        expect((await c.expect<DwAuthenticatedMessage>()).rejected, isTrue);
      }
      await bystander.expectSilence();
      expect((await first.authenticate(session.token)).rejected, isTrue);
    });
  });

  group('ctx.accounts', () {
    test('revokeKeys closes live sessions after the command commits, and not '
        'at all when it is refused', () async {
      final (admin, _) = await harness().signedIn('ctx-admin@example.com');
      final (_, session) = await harness().signedIn('ctx-victim@example.com');
      final victim = await harness().live(token: session.token);
      expect(await victim.subscribe('notes'), isA<DwSubscribedMessage>());

      expect(
        (await admin.call(RevokeSessions(session.id, ending: 'refuse'))).status,
        409,
      );
      await victim.expectSilence();

      expect((await admin.call(RevokeSessions(session.id))).status, 200);
      expect((await victim.expect<DwChannelClosedMessage>()).channel, 'notes');
      expect((await victim.expect<DwAuthenticatedMessage>()).rejected, isTrue);
    });

    test('ensure inside a command joins its transaction', () async {
      final answer = await harness().caller().call(
        const EnsureAccount('from-command@example.com'),
      );
      final id = answer.value(const EnsureAccount(''));
      expect(
        await accounts().find(
          DwIdentifierKind.email,
          'from-command@example.com',
        ),
        id,
      );
    });
  });

  group('DwAccountService over a bare database', () {
    test('creates with onAccountCreated bound to the transaction', () async {
      final service = DwAccountService(harness().db, harness().app.auth());
      final created = await service.ensure(
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
        await service.find(DwIdentifierKind.phone, '+15550001111'),
        created.accountId,
      );
    });

    test('a hook that publishes throws instead of dropping it, and the '
        'account is not created', () async {
      final base = harness().app.auth();
      final auth = DwAuthConfig(
        normalize: base.normalize,
        deliverCode: base.deliverCode,
        onAccountCreated: (ctx, accountId, kind, identifier, origin) async =>
            ctx.publish(
              const DwLiveChannel(TestChannel.notes),
              NoteView(id: accountId, text: 'welcome'),
            ),
      );
      final service = DwAccountService(harness().db, auth);
      await expectLater(
        service.ensure(DwIdentifierKind.email, 'detached@example.com'),
        throwsStateError,
      );
      expect(
        await service.find(DwIdentifierKind.email, 'detached@example.com'),
        isNull,
      );
    });
  });
}
