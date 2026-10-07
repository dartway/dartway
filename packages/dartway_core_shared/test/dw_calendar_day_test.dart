import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  group('DwCalendarDay', () {
    test('uses strict canonical Gregorian dates and value equality', () {
      final leapDay = DwCalendarDay(2000, 2, 29);
      expect(DwCalendarDay.parse('2000-02-29'), leapDay);
      expect(leapDay.hashCode, DwCalendarDay(2000, 2, 29).hashCode);
      expect(leapDay.toString(), '2000-02-29');
      expect(leapDay.compareTo(DwCalendarDay(2000, 3, 1)), isNegative);
      expect(
        DwCalendarDay(1900, 3, 1).compareTo(DwCalendarDay(1900, 2, 28)),
        1,
      );
    });

    test(
      'rejects malformed, noncanonical, impossible and out-of-range dates',
      () {
        for (final value in [
          '2026-2-03',
          '2026-02-3',
          '2026-02-30',
          '1900-02-29',
          '0000-01-01',
          '10000-01-01',
          '2026/02/03',
        ]) {
          expect(
            () => DwCalendarDay.parse(value),
            throwsFormatException,
            reason: value,
          );
        }
        expect(() => DwCalendarDay(2024, 2, 30), throwsArgumentError);
        expect(() => DwCalendarDay(10000, 1, 1), throwsArgumentError);
        expect(() => DwCalendarDay(2026, 13, 1), throwsArgumentError);
        expect(() => DwCalendarDay(2026, 1, 0), throwsArgumentError);
      },
    );

    test('adds and subtracts civil days over month, leap and year edges', () {
      final february = DwCalendarDay(2024, 2, 28);
      expect(february.addDays(1), DwCalendarDay(2024, 2, 29));
      expect(february.addDays(2), DwCalendarDay(2024, 3, 1));
      expect(
        DwCalendarDay(2025, 1, 1).addDays(-1),
        DwCalendarDay(2024, 12, 31),
      );
      expect(DwCalendarDay(2024, 3, 1).differenceInDays(february), 2);
      expect(february.differenceInDays(DwCalendarDay(2024, 3, 1)), -2);
      expect(() => DwCalendarDay(1, 1, 1).addDays(-1), throwsRangeError);
      expect(() => DwCalendarDay(9999, 12, 31).addDays(1), throwsRangeError);
    });

    test(
      'the caller chooses the intended timezone before extracting Y/M/D',
      () {
        // Run with TZ=Pacific/Kiritimati: this instant is Jan 1 locally but Dec
        // 31 in UTC. The value stores whichever components its caller selects.
        final instant = DateTime.utc(2025, 12, 31, 12);
        final local = instant.toLocal();
        expect(
          DwCalendarDay(local.year, local.month, local.day),
          DwCalendarDay(2026, 1, 1),
        );
        expect(
          DwCalendarDay(instant.year, instant.month, instant.day),
          DwCalendarDay(2025, 12, 31),
        );
      },
    );

    test('JSON codec is the canonical string and rejects invalid input', () {
      final day = DwCalendarDay(2026, 10, 7);
      expect(DwJsonCodec.encodeCalendarDay(day), '2026-10-07');
      expect(DwJsonCodec.decodeCalendarDay('2026-10-07'), day);
      expect(
        () => DwJsonCodec.decodeCalendarDay('2026-02-29'),
        throwsFormatException,
      );
      expect(
        () => DwJsonCodec.decodeCalendarDay(20261007),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
