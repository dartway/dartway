part of '../ui_kit.dart';

/// Locale-aware date labels. Formatting follows `Intl.defaultLocale`, which
/// the app locale controller keeps in sync with the active UI language.
extension DateTimeLabels on DateTime {
  String get timeLabel => DateFormat.Hm().format(this);

  String get dayLabel => DateFormat('EEE, dd.MM').format(this);

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
