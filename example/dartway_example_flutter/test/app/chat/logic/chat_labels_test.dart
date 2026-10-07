import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat grouping uses local calendar components across a UTC boundary',
    () {
      // With TZ=Pacific/Kiritimati both instants fall on local 2026-01-01,
      // although their UTC dates differ.
      final beforeUtcMidnight = DateTime.utc(2025, 12, 31, 12);
      final afterUtcMidnight = DateTime.utc(2025, 12, 31, 23);
      expect(beforeUtcMidnight.isSameLocalDay(afterUtcMidnight), isTrue);
      final local = beforeUtcMidnight.toLocal();
      expect(
        DwCalendarDay(local.year, local.month, local.day),
        DwCalendarDay(2026, 1, 1),
      );
    },
  );
}
