part of '../ui_kit.dart';

/// Locale-aware date labels, in the device's time zone. Formatting follows
/// `Intl.defaultLocale`, which the app locale controller keeps in sync with
/// the active UI language.
///
/// Times arrive from the server in UTC; a label is the viewer's, so it is taken
/// in local time.
extension DateLabel on DateTime {
  /// A calendar date for people — `Sep 14, 2026` — in the active UI language.
  String get dateLabel => DateFormat.yMMMd().format(toLocal());
}
