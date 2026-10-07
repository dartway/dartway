import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat grouping compares known local calendar components', () {
    final morning = DateTime(2026, 1, 1, 8);
    final evening = DateTime(2026, 1, 1, 23);
    expect(morning.isSameLocalDay(evening), isTrue);
    final local = morning.toLocal();
    expect(
      DwCalendarDay(local.year, local.month, local.day),
      DwCalendarDay(2026, 1, 1),
    );
  });
}
