part of '../ui_kit.dart';

/// Locale-aware date labels, in the device's time zone. Formatting follows
/// `Intl.defaultLocale`, which the app locale controller keeps in sync with
/// the active UI language.
///
/// Times arrive from the server in UTC; a label and a calendar day are the
/// viewer's, so both are taken in local time.
extension DateTimeLabels on DateTime {
  String get timeLabel => DateFormat.Hm().format(toLocal());

  String get dayLabel => DateFormat('EEE, dd.MM').format(toLocal());

  bool isSameDayAs(DateTime other) {
    final a = toLocal();
    final b = other.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
