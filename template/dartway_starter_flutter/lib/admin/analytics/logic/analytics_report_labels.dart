import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:intl/intl.dart';

/// How a report reads to people: its points as chart values, labelled in
/// this language.
extension AnalyticsReportLabels on DwAnalyticsReport {
  /// The points of the breakdown in [spec], labelled: a day or a month by the
  /// calendar, a property value as sent — `null` as "not set".
  List<AppChartValue> chartValues(
    AppLocalizations l10n,
    DwAnalyticsReportSpec spec,
  ) {
    if (spec.breakdown.isNone) {
      return [AppChartValue(l10n.analyticsMetric(spec.metric.name), total)];
    }
    final bucket = spec.breakdown.bucket;
    return [
      for (final point in points)
        AppChartValue(switch ((bucket, point.label)) {
          (_, null) => l10n.analyticsNotSet,
          (DwAnalyticsTimeBucket.month, final label?) =>
            DateFormat.yMMM().format(DateTime.parse(label)),
          (DwAnalyticsTimeBucket(), final label?) => DateFormat.MMMd().format(
            DateTime.parse(label),
          ),
          (null, final label?) => label,
        }, point.value),
    ];
  }

  /// "Other" of a breakdown by property, when the report has one.
  AppChartValue? restValue(AppLocalizations l10n) => switch (other) {
    final other? => AppChartValue(l10n.analyticsOther, other),
    null => null,
  };
}

/// The change of [current] against [previous] as the indicator shows it: a
/// percentage, or the difference when there was nothing before.
({String text, AppTrend trend}) analyticsChange(int current, int previous) {
  final trend = current > previous
      ? AppTrend.up
      : current < previous
      ? AppTrend.down
      : AppTrend.flat;
  if (previous == 0) {
    final difference = current - previous;
    return (
      text: difference > 0 ? '+$difference' : '$difference',
      trend: trend,
    );
  }
  final ratio = (current - previous) / previous;
  final text = NumberFormat.percentPattern().format(ratio.abs());
  return (
    text: switch (trend) {
      AppTrend.up => '+$text',
      AppTrend.down => '−$text',
      AppTrend.flat => text,
    },
    trend: trend,
  );
}
