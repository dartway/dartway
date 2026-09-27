import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';

/// The period on top of a dashboard: the last [days] days, today included,
/// or dates picked by hand ([days] `null`).
///
/// Computed once, when chosen: a period is part of every report request, and
/// a request whose period moved with the clock would be a new request on
/// every rebuild.
class AnalyticsPeriodChoice {
  const AnalyticsPeriodChoice._(this.days, this.period);

  factory AnalyticsPeriodChoice.lastDays(int days, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return AnalyticsPeriodChoice._(
      days,
      DwAnalyticsPeriod.localDays(
        today.subtract(Duration(days: days - 1)),
        today,
      ),
    );
  }

  factory AnalyticsPeriodChoice.dates(DateTime first, DateTime last) =>
      AnalyticsPeriodChoice._(null, DwAnalyticsPeriod.localDays(first, last));

  /// The presets offered beside the date picker.
  static const List<int> presets = [7, 30, 90];

  static const int defaultDays = 30;

  final int? days;
  final DwAnalyticsPeriod period;
}
