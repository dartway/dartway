import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Sessions: the token cache that spares calls a query, revocation that
/// defeats it at once, and sessions on the live socket.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      auth: app.auth(keyTouchInterval: const Duration(milliseconds: 400)),
      settings: const DwServerSettings(
        tokenCacheTtl: Duration(milliseconds: 600),
      ),
    ),
  );

  Future<void> revokeBehindTheServersBack(int accountId) =>
      harness().db.execute(
        'UPDATE dw_auth_key SET revoked_at = now() WHERE account_id = @id',
        params: {'id': accountId},
      );

  group('token cache', () {
    test(
      'a token seen recently costs no query: revoked behind the server\'s '
      'back it still works until the cache entry expires, then 401',
      () async {
        final (caller, session) = await harness().signedIn(
          'cached@example.com',
        );
        expect((await caller.call(const MyNotes())).status, 200);
        await revokeBehindTheServersBack(session.id);
        expect(
          (await caller.call(const MyNotes())).status,
          200,
          reason: 'served from the cache, without reading the key',
        );
        await eventually(
          () async => (await caller.call(const MyNotes())).status == 401,
          timeout: const Duration(seconds: 5),
        );
      },
    );

    test('sign-out ends the session at once, cache or not', () async {
      final (caller, _) = await harness().signedIn('signout@example.com');
      expect((await caller.call(const MyNotes())).status, 200);
      expect((await caller.call(const DwSignOut())).status, 200);
      expect((await caller.call(const MyNotes())).status, 401);
      expect((await caller.call(const ListNotes(ownerId: -1))).status, 401);
    });

    test('revokeKeys through the server ends every key of the account at '
        'once, and only of that account', () async {
      final (first, session) = await harness().signedIn('revoked@example.com');
      await harness().db.execute(
        "UPDATE dw_code_ticket SET created_at = now() - interval '1 hour'",
      );
      final secondSession = await harness().app.signIn(
        harness().caller(),
        'revoked@example.com',
      );
      final second = harness().caller(token: secondSession.token);
      final (bystander, _) = await harness().signedIn('kept@example.com');
      for (final c in [first, second, bystander]) {
        expect((await c.call(const MyNotes())).status, 200);
      }
      await harness().server.server.accounts.revokeKeys(session.id);
      expect((await first.call(const MyNotes())).status, 401);
      expect((await second.call(const MyNotes())).status, 401);
      expect((await bystander.call(const MyNotes())).status, 200);
    });

    test('a revocation by a command takes effect after it commits, and not '
        'at all when the command is refused', () async {
      final (admin, _) = await harness().signedIn('cmd-admin@example.com');
      final (victim, session) = await harness().signedIn(
        'cmd-victim@example.com',
      );
      expect((await victim.call(const MyNotes())).status, 200);
      expect(
        (await admin.call(RevokeSessions(session.id, ending: 'refuse'))).status,
        409,
      );
      expect((await victim.call(const MyNotes())).status, 200);
      expect((await admin.call(RevokeSessions(session.id))).status, 200);
      expect((await victim.call(const MyNotes())).status, 401);
    });

    test('last_used_at is written at most once per touch interval', () async {
      final (caller, session) = await harness().signedIn('touch@example.com');
      Future<DateTime> lastUsed() async => (await harness().db.query(
        'SELECT last_used_at FROM dw_auth_key WHERE account_id = @id',
        params: {'id': session.id},
      )).single.get<DateTime>('last_used_at');

      await caller.call(const MyNotes());
      final first = await lastUsed();
      for (var i = 0; i < 5; i++) {
        await caller.call(const MyNotes());
      }
      expect(await lastUsed(), first, reason: 'within the interval');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await caller.call(const MyNotes());
      final touched = await lastUsed();
      expect(touched.isAfter(first), isTrue);
      await caller.call(const MyNotes());
      expect(await lastUsed(), touched);
    });
  });

  group('live sessions', () {
    test('a valid token binds the account, an unknown one is rejected, none '
        'unbinds', () async {
      final (_, session) = await harness().signedIn('bind@example.com');
      final socket = await harness().live();
      final rejected = await socket.authenticate('not-a-token');
      expect(rejected.rejected, isTrue);
      expect(rejected.accountId, isNull);
      expect(
        (await socket.subscribe('notes') as DwSubscriptionRefusedMessage)
            .isUnauthenticated,
        isTrue,
      );
      expect((await socket.authenticate(session.token)).accountId, session.id);
      final anonymous = await socket.authenticate(null);
      expect((anonymous.accountId, anonymous.rejected), (null, false));
    });

    test('every connection id is new and unguessable', () async {
      final ids = {
        for (var i = 0; i < 5; i++) (await harness().live()).connectionId,
      };
      expect(ids, hasLength(5));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
      }
    });

    test('sign-out revokes the key everywhere: the named connection loses '
        'its subscriptions quietly, other connections on the key are '
        'rejected, other keys of the account stay', () async {
      final (caller, session) = await harness().signedIn('out@example.com');
      final named = await harness().live(token: session.token);
      final sameKey = await harness().live(token: session.token);
      await harness().db.execute(
        "UPDATE dw_code_ticket SET created_at = now() - interval '1 hour'",
      );
      final otherSession = await harness().app.signIn(
        harness().caller(),
        'out@example.com',
      );
      final otherDevice = await harness().live(token: otherSession.token);
      for (final socket in [named, sameKey, otherDevice]) {
        expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
      }
      expect(
        await named.subscribe('account:${session.id}'),
        isA<DwSubscribedMessage>(),
      );

      caller.liveConnection = named.connectionId;
      expect((await caller.call(const DwSignOut())).status, 200);

      final closed = [
        (await named.expect<DwChannelClosedMessage>()).channel,
        (await named.expect<DwChannelClosedMessage>()).channel,
      ];
      expect(closed, unorderedEquals(['notes', 'account:${session.id}']));
      await named.expectSilence();

      expect((await sameKey.expect<DwChannelClosedMessage>()).channel, 'notes');
      expect((await sameKey.expect<DwAuthenticatedMessage>()).rejected, isTrue);

      await otherDevice.expectSilence();
      expect(
        (await harness()
                .caller(token: otherSession.token)
                .call(const MyNotes()))
            .status,
        200,
      );

      final again = await harness().live();
      expect((await again.authenticate(session.token)).rejected, isTrue);
      final revoked = await harness().db.query(
        'SELECT revoked_at FROM dw_auth_key WHERE account_id = @id ORDER BY id',
        params: {'id': session.id},
      );
      expect(revoked.map((r) => r['revoked_at'] != null), [true, false]);
    });

    test(
      'switching accounts closes the subscriptions of the previous one',
      () async {
        final (_, a) = await harness().signedIn('switch-a@example.com');
        final (_, b) = await harness().signedIn('switch-b@example.com');
        final socket = await harness().live(token: a.token);
        expect(
          await socket.subscribe('account:${a.id}'),
          isA<DwSubscribedMessage>(),
        );
        socket.send(DwAuthenticateMessage(b.token));
        expect(
          (await socket.expect<DwChannelClosedMessage>()).channel,
          'account:${a.id}',
        );
        expect((await socket.expect<DwAuthenticatedMessage>()).accountId, b.id);
      },
    );

    test('a subscription sent right after auth is checked for the new '
        'account', () async {
      final (_, session) = await harness().signedIn('gate@example.com');
      final socket = await harness().live();
      socket.send(DwAuthenticateMessage(session.token));
      socket.send(DwSubscribeMessage('account:${session.id}'));
      expect(
        await socket.expect<DwSubscribedMessage>(),
        isA<DwSubscribedMessage>(),
      );
    });
  });
}
