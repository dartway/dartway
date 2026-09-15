import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'support/push_harness.dart';

/// Accounts with one FCM device each, written directly: this suite is about
/// delivery, and registration has its own.
Future<List<int>> members(PushHarness h, String prefix, int count) async {
  final ids = <int>[];
  for (var i = 0; i < count; i++) {
    final account = await h.account();
    await h.db.execute(
      'INSERT INTO dw_push_device (account_id, key_id, transport, token, platform) '
      "VALUES (@a, @k, 'fcm', @t, 'android')",
      params: {'a': account.id, 'k': account.keyId, 't': '$prefix-$i'},
    );
    ids.add(account.id);
  }
  return ids;
}

Future<Map<String, int>> outcomes(PushHarness h) async => {
  for (final row in await h.db.query(
    'SELECT coalesce(outcome, \'pending\') AS outcome, count(*) AS n '
    'FROM dw_push_delivery GROUP BY 1',
  ))
    row['outcome']! as String: row['n']! as int,
};

void main() {
  group('four job workers draining at once', () {
    final harness = usePushHarness(
      settings: const DwPushSettings(
        batchSize: 10,
        concurrentSends: 4,
        backoff: _fast,
      ),
      serverSettings: const DwServerSettings(
        jobWorkers: 4,
        jobPollInterval: Duration(seconds: 30),
      ),
    );

    test('never deliver one device twice', () async {
      final h = harness();
      h.fcm.delay = const Duration(milliseconds: 15);
      final ids = await members(h, 'crowd', 200);
      // Four sends, four jobs due at once: four runs claim side by side.
      for (var i = 0; i < 4; i++) {
        await h.queue(QueueAlert(recipients: ids.sublist(i * 50, i * 50 + 50)));
      }
      await eventually(
        () async => (await outcomes(h))['sent'] == 200,
        timeout: const Duration(seconds: 30),
      );
      final perToken = <String, int>{};
      for (final send in h.fcm.sends) {
        perToken.update(send.token, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(perToken, hasLength(200));
      expect(perToken.values.where((n) => n != 1), isEmpty);
      expect(
        h.fcm.maxInFlight,
        greaterThan(4),
        reason: 'more than one run was sending at the same time',
      );
      expect(
        await h.db.query(
          'SELECT 1 FROM dw_push_delivery WHERE lease_id IS NOT NULL '
          'OR attempts > 0',
        ),
        isEmpty,
      );
    });
  });

  group('a run budget', () {
    final harness = usePushHarness(
      settings: const DwPushSettings(
        batchSize: 10,
        concurrentSends: 2,
        runBudget: Duration(milliseconds: 300),
      ),
      serverSettings: const DwServerSettings(
        jobWorkers: 1,
        jobPollInterval: Duration(seconds: 30),
      ),
    );

    test('ends a run and continues in the next one', () async {
      final h = harness();
      h.fcm.delay = const Duration(milliseconds: 100);
      final ids = await members(h, 'budget', 30);
      await h.queue(QueueAlert(recipients: ids));
      await eventually(
        () async => (await outcomes(h))['sent'] == 30,
        timeout: const Duration(seconds: 30),
      );
      final runs = [
        for (final line in h.logs)
          if (RegExp(
                r'push run: (\d+) deliveries claimed, (\d+) sends, (\d+) ms(.*)',
              ).firstMatch(line)
              case final match?)
            (
              sends: int.parse(match.group(2)!),
              millis: int.parse(match.group(3)!),
              continued: match.group(4)!.contains('continuation'),
            ),
      ];
      expect(runs.length, greaterThan(1));
      expect(runs.first.continued, isTrue);
      for (final run in runs) {
        // The budget, plus the sends already in flight (100 ms), plus the
        // record transaction.
        expect(run.millis, lessThan(300 + 100 + 250), reason: '$run');
        // Two lanes, 100 ms a send: about six sends fit 300 ms.
        expect(run.sends, lessThanOrEqualTo(10), reason: '$run');
      }
      expect(h.fcm.sends, hasLength(30), reason: 'each device once');
    });
  });

  group('a pool of one connection', () {
    final harness = usePushHarness(
      maxConnections: 1,
      serverSettings: const DwServerSettings(
        jobWorkers: 1,
        jobPollInterval: Duration(seconds: 30),
      ),
    );

    test('is free while a provider request is in flight', () async {
      final h = harness();
      final member = await h.member('slow-provider-token');
      final gate = h.fcm.gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
        h.fcm.gate = null;
      });
      await h.queue(QueueAlert(recipients: [member.id]));
      await eventually(() => h.fcm.inFlight == 1);

      // The only connection answers a query and a whole call while FCM holds
      // its response.
      await h.db.query('SELECT 1').timeout(const Duration(seconds: 2));
      final other = await h.account().timeout(const Duration(seconds: 2));
      final answer = await h
          .register(other, 'registered-meanwhile')
          .timeout(const Duration(seconds: 2));
      expect(answer.status, 200);
      expect(h.fcm.inFlight, 1, reason: 'the send is still waiting');

      gate.complete();
      await eventually(() async => (await outcomes(h))['sent'] == 1);
    });
  });
}

Duration _fast(int attempt) => const Duration(milliseconds: 100);
