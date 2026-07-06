part of '../ui_kit.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

extension DateTimeLabels on DateTime {
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get dayLabel => '${_weekdayLabels[weekday - 1]}, '
      '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}';

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
