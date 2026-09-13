import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  test('a valid token binds the account, an unknown one is rejected, null '
      'unbinds', () async {
    final (connection, session) = await harness().signedIn('bind@example.com');
    final rejected = await connection.authenticate('not-a-token');
    expect(rejected.rejected, isTrue);
    expect(rejected.accountId, isNull);
    expect(
      (await connection.request(const MyNotes())).status,
      DwResultStatus.unauthenticated,
    );
    final again = await connection.authenticate(session.token);
    expect(again.accountId, session.id);
    final anonymous = await connection.authenticate(null);
    expect(anonymous.accountId, isNull);
    expect(anonymous.rejected, isFalse);
    await connection.close();
  });

  test('last_used_at is written at most once per touch interval', () async {
    final (connection, session) = await harness().signedIn('touch@example.com');
    Future<DateTime> lastUsed() async => (await harness().db.query(
      'SELECT last_used_at FROM dw_auth_key WHERE account_id = @id',
      params: {'id': session.id},
    )).single.get<DateTime>('last_used_at');

    await harness().db.execute(
      "UPDATE dw_auth_key SET last_used_at = now() - interval '1 hour' "
      'WHERE account_id = @id',
      params: {'id': session.id},
    );
    final stale = await lastUsed();
    await connection.authenticate(session.token);
    final touched = await lastUsed();
    expect(touched.isAfter(stale), isTrue);
    await connection.authenticate(session.token);
    expect(await lastUsed(), touched);
    await connection.close();
  });

  test('sign-out revokes the key everywhere: subscriptions close, other '
      'connections holding the key are rejected, other keys stay', () async {
    final (first, session) = await harness().signedIn('out@example.com');
    final second = await harness().connect();
    expect((await second.authenticate(session.token)).accountId, session.id);
    // The same account on another key (another device).
    final otherDevice = await harness().connect();
    final otherSession = await harness().app
        .signIn(otherDevice, 'OUT@example.com')
        .catchError((Object _) async {
          await harness().db.execute(
            "UPDATE dw_code_ticket SET created_at = now() - interval '1 minute'",
          );
          return harness().app.signIn(otherDevice, 'out@example.com');
        });
    expect(otherSession.id, session.id);
    await otherDevice.authenticate(otherSession.token);

    for (final c in [first, second, otherDevice]) {
      expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
    }
    expect(
      await first.subscribe('account:${session.id}'),
      isA<DwSubscribedMessage>(),
    );

    final signOut = await first.command(const DwSignOut());
    expect(signOut.status, DwResultStatus.ok);

    // The author: its subscriptions are closed, no rejection notice.
    final closed = [
      (await first.expect<DwChannelClosedMessage>()).channel,
      (await first.expect<DwChannelClosedMessage>()).channel,
    ];
    expect(closed, unorderedEquals(['notes', 'account:${session.id}']));
    expect(
      (await first.request(const MyNotes())).status,
      DwResultStatus.unauthenticated,
    );
    expect(first.buffered.whereType<DwAuthenticatedMessage>(), isEmpty);

    // Another connection on the same key.
    expect((await second.expect<DwChannelClosedMessage>()).channel, 'notes');
    expect((await second.expect<DwAuthenticatedMessage>()).rejected, isTrue);
    expect(
      (await second.request(const MyNotes())).status,
      DwResultStatus.unauthenticated,
    );

    // The same account on another key keeps its session.
    await otherDevice.expectSilence();
    expect(
      (await otherDevice.request(const MyNotes())).status,
      DwResultStatus.ok,
    );

    // The revoked token does not come back.
    final third = await harness().connect();
    expect((await third.authenticate(session.token)).rejected, isTrue);

    final revoked = await harness().db.query(
      'SELECT revoked_at FROM dw_auth_key WHERE account_id = @id '
      'ORDER BY id',
      params: {'id': session.id},
    );
    expect(revoked.map((r) => r['revoked_at'] != null), [true, false]);
    for (final c in [first, second, otherDevice, third]) {
      await c.close();
    }
  });

  test('sign-out without a session is unauthenticated', () async {
    final connection = await harness().connect();
    expect(
      (await connection.command(const DwSignOut())).status,
      DwResultStatus.unauthenticated,
    );
    await connection.close();
  });

  test(
    'switching accounts closes the subscriptions of the previous one',
    () async {
      final (connection, session) = await harness().signedIn(
        'switch-a@example.com',
      );
      expect(
        await connection.subscribe('account:${session.id}'),
        isA<DwSubscribedMessage>(),
      );
      final other = await harness().connect();
      final otherSession = await harness().app.signIn(
        other,
        'switch-b@example.com',
      );
      connection.send(DwAuthenticateMessage(otherSession.token));
      expect(
        (await connection.expect<DwChannelClosedMessage>()).channel,
        'account:${session.id}',
      );
      expect(
        (await connection.expect<DwAuthenticatedMessage>()).accountId,
        otherSession.id,
      );
      await connection.close();
      await other.close();
    },
  );
}
