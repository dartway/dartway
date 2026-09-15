import 'dart:convert';

import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'support/push_harness.dart';

void main() {
  final harness = usePushHarness(
    settings: const DwPushSettings(
      retention: Duration(seconds: 1),
      cleanupInterval: Duration(milliseconds: 300),
      sendTimeout: Duration(seconds: 5),
    ),
  );

  Future<int> count(String table, [String where = 'true']) async =>
      (await harness().db.query(
            'SELECT count(*) AS n FROM $table WHERE $where',
          )).single['n']!
          as int;

  test(
    'finished deliveries past retention go, and their dedup key is free',
    () async {
      final h = harness();
      final member = await h.member('cleanup-token');
      final alert = QueueAlert(recipients: [member.id], dedupKey: 'cleanup:1');
      expect((await h.queue(alert)).value(alert), 1);
      await eventually(
        () async => await count('dw_push_delivery', "outcome = 'sent'") == 1,
      );
      expect(
        (await h.queue(alert)).value(alert),
        0,
        reason: 'within retention',
      );
      await eventually(
        () async =>
            await count('dw_push_delivery') == 0 &&
            await count('dw_push_message') == 0,
        reason:
            'the delivery and its message are removed, the duplicate '
            'send\'s empty message too',
      );
      expect((await h.queue(alert)).value(alert), 1, reason: 'after retention');
      await eventually(
        () => h.fcm.sends.where((s) => s.token == 'cleanup-token').length == 2,
      );
    },
  );

  test('pending work that no job covers is recovered', () async {
    final h = harness();
    final member = await h.member('orphaned-token');
    // A delivery overdue by an hour with no job: what a delivery job that
    // ran out of attempts on database failures leaves behind.
    await h.db.execute(
      'WITH m AS (INSERT INTO dw_push_message '
      '(category, title, data, expires_at) VALUES '
      "('news', 'Recovered', @data::jsonb, now() + interval '1 day') "
      'RETURNING id) '
      'INSERT INTO dw_push_delivery (message_id, account_id, run_at) '
      "SELECT m.id, @a, now() - interval '1 hour' FROM m",
      params: {
        'a': member.id,
        'data': jsonEncode(const DwPushData(link: '/recovered').toWire()),
      },
    );
    await eventually(() => h.fcm.sends.any((s) => s.token == 'orphaned-token'));
    expect(
      h.logs.any((l) => l.contains('overdue by more than')),
      isTrue,
      reason: 'recovery is logged',
    );
    final send = h.fcm.sends.singleWhere((s) => s.token == 'orphaned-token');
    expect((send.message['notification']! as Map)['title'], 'Recovered');
  });
}
