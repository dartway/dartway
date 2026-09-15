import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'support/push_harness.dart';

void main() {
  final harness = usePushHarness(
    settings: const DwPushSettings(maxDevicesPerAccount: 3),
  );

  Future<List<DwResultRow>> devicesOf(int accountId) => harness().db.query(
    'SELECT * FROM dw_push_device WHERE account_id = @a ORDER BY id',
    params: {'a': accountId},
  );

  test(
    'a registration is bound to the caller and the key it signed in with',
    () async {
      final h = harness();
      final member = await h.account();
      final answer = await h.register(
        member,
        'token-bound',
        platform: DwPushPlatform.ios,
      );
      expect(answer.status, 200, reason: answer.text);
      final device = (await devicesOf(member.id)).single;
      expect(device['token'], 'token-bound');
      expect(device['transport'], 'fcm');
      expect(device['platform'], 'ios');
      expect(device['key_id'], member.keyId);
    },
  );

  test('registering again refreshes the row instead of adding one', () async {
    final h = harness();
    final member = await h.account();
    await h.register(member, 'token-again');
    final first = (await devicesOf(member.id)).single;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await h.register(member, 'token-again');
    final second = (await devicesOf(member.id)).single;
    expect(second['id'], first['id']);
    expect(
      (second['updated_at']! as DateTime).isAfter(
        first['updated_at']! as DateTime,
      ),
      isTrue,
    );
  });

  test('a token registered by another account moves to it', () async {
    final h = harness();
    final previous = await h.account();
    final next = await h.account();
    await h.register(previous, 'token-handed-over');
    await h.register(next, 'token-handed-over');
    expect(await devicesOf(previous.id), isEmpty);
    expect((await devicesOf(next.id)).single['key_id'], next.keyId);
  });

  test(
    'the same token string of two transports is two registrations',
    () async {
      final h = harness();
      final member = await h.account();
      await h.register(member, 'token-two-transports');
      await h.register(
        member,
        'token-two-transports',
        transport: DwPushTransport.rustore,
      );
      expect(
        [for (final d in await devicesOf(member.id)) d['transport']],
        ['fcm', 'rustore'],
      );
    },
  );

  test('an account keeps its most recently registered devices', () async {
    final h = harness();
    final member = await h.account();
    for (final token in ['cap-1', 'cap-2', 'cap-3', 'cap-4']) {
      await h.register(member, token);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      [for (final d in await devicesOf(member.id)) d['token']],
      ['cap-2', 'cap-3', 'cap-4'],
    );
    // Refreshing a kept one does not evict another.
    await h.register(member, 'cap-2');
    expect(await devicesOf(member.id), hasLength(3));
  });

  test('unregistering removes only the caller\'s registration', () async {
    final h = harness();
    final owner = await h.account();
    final stranger = await h.account();
    await h.register(owner, 'token-owned');
    final strangerCaller = h.server.caller(token: stranger.token);
    addTearDown(strangerCaller.close);
    final answer = await strangerCaller.call(
      const DwUnregisterPushToken(token: 'token-owned'),
    );
    expect(answer.status, 200, reason: 'the same answer as for a missing one');
    expect(await devicesOf(owner.id), hasLength(1));

    final ownerCaller = h.server.caller(token: owner.token);
    addTearDown(ownerCaller.close);
    await ownerCaller.call(const DwUnregisterPushToken(token: 'token-owned'));
    expect(await devicesOf(owner.id), isEmpty);
  });

  test(
    'an anonymous caller cannot register, and a malformed token is refused',
    () async {
      final h = harness();
      final anonymous = await h.caller.call(
        const DwRegisterPushToken(
          transport: DwPushTransport.fcm,
          token: 'token-anonymous',
          platform: DwPushPlatform.web,
        ),
      );
      expect(anonymous.status, 401);
      final member = await h.account();
      final refused = await h.register(member, 'has space');
      expect(refused.status, 422);
      expect(refused.refusal.code, 'dw.pushTokenInvalid');
      expect(refused.refusal.field, 'token');
      expect(await devicesOf(member.id), isEmpty);
    },
  );

  test('deleting an account removes its devices', () async {
    final h = harness();
    final member = await h.account();
    await h.register(member, 'token-deleted-account');
    await h.db.execute(
      'DELETE FROM dw_account WHERE id = @a',
      params: {'a': member.id},
    );
    expect(await devicesOf(member.id), isEmpty);
  });
}
