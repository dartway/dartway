import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/analytics_harness.dart';

void main() {
  final harness = useAnalyticsHarness();

  Future<List<DwResultRow>> eventsOf(String installId) => harness().db.query(
    'SELECT * FROM dw_analytics_event WHERE install_id = @i ORDER BY sequence',
    params: {'i': installId},
  );

  final t0 = DateTime.utc(2026, 9, 17, 10);

  test(
    'a signed-out batch is stored with its install, platform and version',
    () async {
      final install = newInstallId();
      final answer = await harness().send(
        batch(install, [
          event('catalogOpened', 1, t0, {
            'from': 'push',
            'items': 12,
            'new': true,
          }),
          event('dw.appBackgrounded', 2, t0.add(const Duration(seconds: 40))),
        ]),
      );
      expect(answer.status, 200, reason: answer.text);

      final rows = await eventsOf(install);
      expect(rows.map((r) => r['name']), [
        'catalogOpened',
        'dw.appBackgrounded',
      ]);
      expect(rows.first['source'], 'app');
      expect(rows.first['account_id'], isNull);
      expect(rows.first['platform'], 'android');
      expect(rows.first['app_version'], '1.2.0+7');
      expect(rows.first['properties'], {
        'from': 'push',
        'items': 12,
        'new': true,
      });
      expect(
        (rows.first['occurred_at']! as DateTime).isAtSameMomentAs(t0),
        isTrue,
      );
    },
  );

  test(
    'a batch sent again is stored once, and leaves no outcome row',
    () async {
      final install = newInstallId();
      final events = batch(install, [event('catalogOpened', 1, t0)]);
      await harness().send(events, key: 'first-send');
      // A restart re-sends the unconfirmed batch under a new idempotency key.
      final again = await harness().send(events, key: 'second-send');
      expect(again.status, 200, reason: again.text);

      expect(await eventsOf(install), hasLength(1));
      final outcomes = await harness().db.query(
        "SELECT 1 FROM dw_command_outcome WHERE type = 'DwTrackEvents'",
      );
      expect(outcomes, isEmpty);
    },
  );

  test(
    'a pause longer than the session gap starts a session, across batches',
    () async {
      final install = newInstallId();
      await harness().send(
        batch(install, [
          event('catalogOpened', 1, t0),
          event('catalogOpened', 2, t0.add(const Duration(minutes: 29))),
          event('catalogOpened', 3, t0.add(const Duration(minutes: 70))),
        ]),
      );
      await harness().send(
        batch(install, [
          event('catalogOpened', 4, t0.add(const Duration(minutes: 75))),
          event('catalogOpened', 5, t0.add(const Duration(hours: 5))),
        ]),
      );
      expect((await eventsOf(install)).map((r) => r['session_number']), [
        1,
        1,
        2,
        2,
        3,
      ]);
    },
  );

  test('a signed-in batch is attributed to the caller, and the install keeps '
      'the account through a later signed-out batch', () async {
    final member = await harness().account();
    final install = newInstallId();
    await harness().send(batch(install, [event('catalogOpened', 1, t0)]));
    await harness().send(
      batch(install, [
        event('orderPlaced', 2, t0.add(const Duration(minutes: 1))),
      ]),
      as: member,
    );
    await harness().send(
      batch(install, [
        event('catalogOpened', 3, t0.add(const Duration(minutes: 2))),
      ]),
    );

    expect((await eventsOf(install)).map((r) => r['account_id']), [
      null,
      member.id,
      null,
    ]);
    final row = (await harness().db.query(
      'SELECT account_id FROM dw_analytics_install WHERE install_id = @i',
      params: {'i': install},
    )).single;
    expect(row['account_id'], member.id);
  });

  test(
    'a batch the store does not take is refused and stores nothing',
    () async {
      final install = newInstallId();
      for (final bad in [
        batch(install, [event('has space', 1, t0)]),
        batch(install, [
          event('catalogOpened', 1, t0, {
            'nested': const {'a': 1},
          }),
        ]),
        batch(install, []),
        batch('short', [event('catalogOpened', 1, t0)]),
        batch(install, [
          for (var i = 0; i <= DwTrackEvents.maxEvents; i++)
            event('catalogOpened', i, t0),
        ]),
      ]) {
        final answer = await harness().send(bad);
        expect(answer.status, 422, reason: '$bad: ${answer.text}');
        expect(answer.refusal.isCode(DwAnalyticsRefusal.batchInvalid), isTrue);
      }
      expect(await eventsOf(install), isEmpty);
    },
  );

  test(
    'the server records its own events in the command transaction',
    () async {
      final member = await harness().account();
      expect(
        (await harness().send(
          const PlaceOrder(total: 1290),
          as: member,
        )).status,
        200,
      );
      expect(
        (await harness().send(
          const PlaceOrder(total: 7, refuse: true),
          as: member,
        )).status,
        409,
      );
      final rows = await harness().db.query(
        "SELECT * FROM dw_analytics_event WHERE source = 'server' "
        'AND account_id = @a',
        params: {'a': member.id},
      );
      expect(rows.map((r) => r['properties']), [
        {'total': 1290},
      ]);
      expect(rows.single['name'], 'orderPlaced');
      expect(rows.single['install_id'], isNull);
    },
  );

  test('retention removes events and installs past it', () async {
    final db = harness().db;
    final old = newInstallId();
    final fresh = newInstallId();
    await harness().send(batch(old, [event('catalogOpened', 1, t0)]));
    await harness().send(batch(fresh, [event('catalogOpened', 1, t0)]));
    await db.execute(
      "UPDATE dw_analytics_event SET received_at = now() - interval '200 days' "
      'WHERE install_id = @i',
      params: {'i': old},
    );
    await db.execute(
      "UPDATE dw_analytics_install SET last_seen_at = now() - interval '200 days' "
      'WHERE install_id = @i',
      params: {'i': old},
    );
    await db.execute(
      "UPDATE dw_recurring_job SET next_run_at = now() WHERE name = @n",
      params: {'n': DwAnalyticsModule.cleanupJob},
    );
    harness().server.wakeJobs();

    Future<int> count(String table, String install) async => (await db.query(
      'SELECT count(*)::int AS n FROM $table WHERE install_id = @i',
      params: {'i': install},
    )).single.get<int>('n');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (await count('dw_analytics_install', old) > 0) {
      if (DateTime.now().isAfter(deadline)) fail('retention did not run');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(await count('dw_analytics_event', old), 0);
    expect(await count('dw_analytics_event', fresh), 1);
    expect(await count('dw_analytics_install', fresh), 1);
  });

  test('a protocol without the analytics calls is named at start', () {
    expect(DwAnalyticsModule().problems(DwWireProtocol.core), [
      contains('DwTrackEvents'),
    ]);
  });
}
