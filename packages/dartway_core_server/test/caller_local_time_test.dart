import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

/// `ctx.callerLocalTime`: a wall-clock reading, never an instant.
void main() {
  final instant = DateTime.utc(2026, 9, 29, 21, 30);

  test('reads the caller\'s clock, across midnight both ways', () {
    final moscow = DwCallerLocalTime(instant, const Duration(hours: 3));
    expect(
      [moscow.year, moscow.month, moscow.day, moscow.hour, moscow.minute],
      [2026, 9, 30, 0, 30],
    );
    expect(moscow.weekday, DateTime.wednesday);
    final newYork = DwCallerLocalTime(
      DateTime.utc(2026, 9, 30, 2),
      const Duration(hours: -5),
    );
    expect([newYork.day, newYork.hour, newYork.weekday], [29, 21, 2]);
  });

  test('startOfDayUtc is the instant the caller\'s day began', () {
    final moscow = DwCallerLocalTime(instant, const Duration(hours: 3));
    expect(moscow.startOfDayUtc, DateTime.utc(2026, 9, 29, 21));
    expect(moscow.startOfDayUtc.isUtc, isTrue);
    final kathmandu = DwCallerLocalTime(
      DateTime.utc(2026, 9, 29, 18, 14),
      const Duration(hours: 5, minutes: 45),
    );
    expect(kathmandu.day, 29);
    expect(kathmandu.startOfDayUtc, DateTime.utc(2026, 9, 28, 18, 15));
  });

  test('prints as a reading with its offset, nothing that parses as an '
      'instant', () {
    final reading = DwCallerLocalTime(instant, const Duration(hours: -5));
    expect('$reading', '2026-09-29 16:30 (UTC-05:00)');
    expect(DateTime.tryParse('$reading'), isNull);
  });

  test('equal readings are equal', () {
    expect(
      DwCallerLocalTime(instant, const Duration(hours: 3)),
      DwCallerLocalTime(
        DateTime.utc(2026, 9, 29, 21, 30).toLocal(),
        const Duration(hours: 3),
      ),
    );
  });
}
