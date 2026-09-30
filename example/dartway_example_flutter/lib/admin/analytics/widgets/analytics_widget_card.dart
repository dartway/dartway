import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_example_flutter/admin/analytics/logic/analytics_report_labels.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dartway_example_flutter/core/async_section.dart';

/// One widget of a dashboard: its title and its report over [period], drawn
/// as its type says. [actions], while the dashboard is edited, sit under it.
class AnalyticsWidgetCard extends ConsumerWidget {
  const AnalyticsWidgetCard({
    super.key,
    required this.spec,
    required this.period,
    this.actions = const [],
  });

  final DwAnalyticsWidgetSpec spec;
  final DwAnalyticsPeriod period;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = DwGetAnalyticsReport(spec: spec.report, period: period);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.body(
            spec.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppSpace.m),
          ref
              .watch(dw.request(request))
              .section(
                loadingValue: const DwAnalyticsReport(total: 0),
                onRetry: () => ref.read(dw.request(request).notifier).refetch(),
                builder: (report) => _AnalyticsReportView(
                  spec: spec,
                  period: period,
                  report: report,
                ),
              ),
          if (actions.isNotEmpty) ...[
            const Gap(AppSpace.s),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsReportView extends ConsumerWidget {
  const _AnalyticsReportView({
    required this.spec,
    required this.period,
    required this.report,
  });

  final DwAnalyticsWidgetSpec spec;
  final DwAnalyticsPeriod period;
  final DwAnalyticsReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final number = NumberFormat.decimalPattern();
    if (spec.type == DwAnalyticsWidgetType.indicator) {
      // The previous period is its own request: it is shown when it has
      // answered, and the number does not wait for it.
      final previous = spec.comparePrevious
          ? ref
                .watch(
                  dw.request(
                    DwGetAnalyticsReport(
                      spec: spec.report,
                      period: period.previous,
                    ),
                  ),
                )
                .value
          : null;
      final change = previous == null
          ? null
          : analyticsChange(report.total, previous.total);
      return AppStatValue(
        value: number.format(report.total),
        change: change?.text,
        trend: change?.trend ?? AppTrend.flat,
        caption: change == null ? null : l10n.analyticsVsPrevious,
      );
    }
    if (report.total == 0) return AppText.caption(l10n.analyticsNoData);
    final values = report.chartValues(l10n, spec.report);
    final rest = report.restValue(l10n);
    return switch (spec.type) {
      DwAnalyticsWidgetType.pie => AppPieChart(values: values, rest: rest),
      _ when spec.report.breakdown.bucket != null => AppBarChart.columns(
        values: values,
      ),
      _ => AppBarChart.rows(values: values, rest: rest),
    };
  }
}
