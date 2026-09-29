import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_push_server/testing.dart';
import 'package:test/test.dart';

import 'support/push_harness.dart';

/// A delivery is due by the server's clock — the one the `dw.push.deliver`
/// job covering it runs by (D-110): moving a `DwTestClock` sends a scheduled
/// push and runs a retry, and nothing is sent while it stands.
void main() {
  final clock = DwTestClock(DateTime.utc(2026, 9, 29, 8));
  final harness = usePushHarness(
    clock: clock,
    // A poll far longer than any test: what runs was woken by the clock.
    serverSettings: const DwServerSettings(
      jobPollInterval: Duration(minutes: 5),
    ),
  );

  setUp(() {
    final h = harness();
    h.fcm.answer = (_) => const DwFakePushAnswer.ok();
    h.fcm.delay = Duration.zero;
    h.fcm.gate = null;
    h.eligibility = null;
  });

  Future<DwResultRow> deliveryOf(int accountId) async =>
      (await harness().db.query(
        'SELECT * FROM dw_push_delivery WHERE account_id = @a '
        'ORDER BY id DESC LIMIT 1',
        params: {'a': accountId},
      )).single;

  int sendsTo(String token) =>
      harness().fcm.sends.where((s) => s.token == token).length;

  test('a scheduled push is sent when the clock reaches its time, and not '
      'before', () async {
    final h = harness();
    final member = await h.member('fcm-token-scheduled');
    const hour = 3600 * 1000;
    await h.queue(QueueAlert(recipients: [member.id], delayMillis: hour));
    final queued = await deliveryOf(member.id);
    expect(
      queued['run_at'],
      clock.now().add(const Duration(hours: 1)),
      reason: 'scheduled on the server clock',
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sendsTo('fcm-token-scheduled'), 0, reason: 'an hour away');

    clock.advance(const Duration(hours: 1));
    await eventually(
      () async => (await deliveryOf(member.id))['outcome'] == 'sent',
    );
    expect(sendsTo('fcm-token-scheduled'), 1);
    expect(
      (await deliveryOf(member.id))['finished_at'],
      clock.now(),
      reason: 'finished on the server clock',
    );
  });

  test('a retry waits for the clock to pass its backoff, then runs', () async {
    final h = harness();
    final member = await h.member('fcm-token-retry');
    var calls = 0;
    h.fcm.answer = (send) => calls++ == 0
        ? DwFakePushAnswer.fcmError(
            503,
            'UNAVAILABLE',
            'The server is temporarily unavailable.',
            fcmCode: 'UNAVAILABLE',
          )
        : const DwFakePushAnswer.ok();
    await h.queue(QueueAlert(recipients: [member.id]));
    await eventually(
      () async => (await deliveryOf(member.id))['attempts'] == 1,
    );
    final failed = await deliveryOf(member.id);
    expect(failed['finished_at'], isNull);
    // The test backoff is 200 ms — of the server's clock, which stands.
    expect(
      failed['run_at'],
      clock.now().add(const Duration(milliseconds: 200)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(calls, 1, reason: 'the clock has not moved past the backoff');

    clock.advance(const Duration(seconds: 1));
    await eventually(
      () async => (await deliveryOf(member.id))['outcome'] == 'sent',
    );
    expect(calls, 2);
  });
}
