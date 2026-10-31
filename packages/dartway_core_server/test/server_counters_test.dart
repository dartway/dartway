import 'package:dartway_core_server/src/metrics/dw_server_counters.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

void main() {
  test('read token rejects wrong, missing and revoked values', () {
    expect(DwServerCounters.acceptsToken('new-secret', 'new-secret'), isTrue);
    expect(DwServerCounters.acceptsToken('new-secret', 'old-secret'), isFalse);
    expect(DwServerCounters.acceptsToken('new-secret', null), isFalse);
    expect(DwServerCounters.acceptsToken(null, 'old-secret'), isFalse);
  });

  test('keeps closed endpoint minutes, errors and response percentiles', () {
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12));
    final counters = DwServerCounters(clock: clock);

    for (var i = 1; i <= 100; i++) {
      counters.record(
        'CreateOrder',
        i <= 3 ? 500 : 200,
        Duration(milliseconds: i),
        keyAction: true,
      );
    }
    expect(counters.read(null), isEmpty, reason: 'the current minute is open');

    clock.advance(const Duration(minutes: 1));
    expect(counters.read(null), [
      {
        'minute': '2026-10-31T12:00:00.000Z',
        'endpoints': {
          'CreateOrder': {
            'calls': 100,
            'errors': 3,
            'keyAction': true,
            'responseTimeMs': {'p50': 50.0, 'p95': 95.0, 'max': 100.0},
          },
        },
      },
    ]);
  });

  test('returns every retained closed minute after a cursor', () {
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12));
    final counters = DwServerCounters(clock: clock);
    for (var i = 0; i < 11; i++) {
      counters.record(
        'Heartbeat',
        200,
        const Duration(milliseconds: 1),
        keyAction: false,
      );
      clock.advance(const Duration(minutes: 1));
    }

    final minutes = counters.read(DateTime.utc(2026, 10, 31, 12));
    expect(minutes, hasLength(10));
    expect(minutes.first['minute'], '2026-10-31T12:01:00.000Z');
    expect(minutes.last['minute'], '2026-10-31T12:10:00.000Z');
  });
}
