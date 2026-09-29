import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// `ctx.now` from the server's clock, and the caller's UTC offset carried by
/// the framework (D-109).
void main() {
  final start = DateTime.utc(2026, 9, 29, 21, 30);
  final clock = DwTestClock(start);
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      clock: clock,
      // A poll far longer than any test: a job that runs promptly was woken
      // by the clock moving.
      settings: const DwServerSettings(jobPollInterval: Duration(minutes: 5)),
    ),
  );

  late DwTestCaller caller;
  setUpAll(() => caller = harness().caller());
  setUp(() => clock.moveTo(start));

  Future<List<String>> clockLog() async => [
    for (final row in await harness().db.query(
      "SELECT tag FROM job_log WHERE name = 'clock' ORDER BY id",
    ))
      row['tag']! as String,
  ];

  group('ctx.now', () {
    test('a handler reads the time the clock was set to, and a move of the '
        'clock', () async {
      expect(
        (await caller.call(const ReadClock())).value(const ReadClock()),
        startsWith('${start.toIso8601String()}|'),
      );
      clock.advance(const Duration(days: 3));
      expect(
        (await caller.call(const ReadClock())).value(const ReadClock()),
        startsWith('${start.add(const Duration(days: 3)).toIso8601String()}|'),
      );
    });

    test('a request reads it too, and so does server-level work', () async {
      final note = (await caller.call(
        const GetClockNote(),
      )).value(const GetClockNote());
      expect(note.text, startsWith('${start.toIso8601String()}|'));
      expect(
        await harness().server.runInContext((ctx) async => ctx.now),
        start,
      );
    });

    test('a job reads it, and a delayed job is due when the clock says so, '
        'not the database', () async {
      await caller.call(const EnqueueJob('clock', 'now'));
      await eventually(() async => (await clockLog()).isNotEmpty);
      expect(
        (await clockLog()).single,
        'now ${start.toIso8601String()}|-|-',
        reason: 'a job has no caller, so no caller offset',
      );

      // Due in an hour by the clock: an hour of real time would never pass
      // within the test, and the poll is five minutes away.
      await caller.call(
        const EnqueueJob('clock', 'later', delayMillis: 3600 * 1000),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await clockLog(), hasLength(1), reason: 'not due yet');
      final due = start.add(const Duration(hours: 1, minutes: 1));
      clock.moveTo(due);
      await eventually(() async => (await clockLog()).length == 2);
      expect((await clockLog()).last, 'later ${due.toIso8601String()}|-|-');
    });
  });

  group("the caller's UTC offset", () {
    test('travels from the header to ctx.callerUtcOffset and '
        'ctx.callerLocalNow, on commands and requests', () async {
      final answer = await caller.call(
        const ReadClock(),
        headers: {DwHttpContract.utcOffsetHeader: '180'},
      );
      expect(
        answer.value(const ReadClock()),
        '${start.toIso8601String()}|180|2026-09-30T00:30:00.000Z',
        reason: 'past midnight in Moscow while it is 21:30 in London',
      );
      final note = (await caller.call(
        const GetClockNote(),
        headers: {DwHttpContract.utcOffsetHeader: '-300'},
      )).value(const GetClockNote());
      expect(
        note.text,
        '${start.toIso8601String()}|-300|2026-09-29T16:30:00.000Z',
      );
    });

    test('is null when the call carries no header', () async {
      final answer = await caller.call(
        const ReadClock(),
        headers: {DwHttpContract.utcOffsetHeader: null},
      );
      expect(answer.value(const ReadClock()), '${start.toIso8601String()}|-|-');
    });

    test('a malformed header is a malformed call', () async {
      for (final sent in ['+180', '3h', '1081']) {
        final answer = await caller.call(
          const ReadClock(),
          headers: {DwHttpContract.utcOffsetHeader: sent},
        );
        expect(answer.status, 400, reason: sent);
      }
    });

    test('the real client sends the device offset on every call', () async {
      final client = await harness().server.connectClient();
      final text = (await client.command(const ReadClock())).valueOrThrow;
      expect(text.split('|')[1], '${DateTime.now().timeZoneOffset.inMinutes}');
    });
  });
}
