import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_example_flutter/admin/analytics/widgets/analytics_widget_card.dart';
import 'package:dartway_example_flutter/admin/analytics/widgets/analytics_widget_editor.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// The widgets of [dashboard] in a grid of as many columns as fit.
class AnalyticsDashboardGrid extends StatelessWidget {
  const AnalyticsDashboardGrid({
    super.key,
    required this.dashboard,
    required this.period,
    required this.editing,
  });

  final DwAnalyticsDashboard dashboard;
  final DwAnalyticsPeriod period;
  final bool editing;

  static const double _cardMinWidth = 300;
  static const double _gap = 12;

  /// Saves [widgets] as the dashboard's, in this order.
  Future<void> _save(
    BuildContext context,
    List<DwAnalyticsWidgetSpec> widgets,
  ) async => dw.action(
    (_) => dw.plugins.analytics.saveDashboard(
      id: dashboard.id,
      title: dashboard.title,
      widgets: widgets,
    ),
  )(context);

  Future<void> _edit(BuildContext context, int? index) async {
    final widgets = dashboard.widgets;
    final spec = await context.showAppBottomSheet<DwAnalyticsWidgetSpec>(
      child: AnalyticsWidgetEditor(
        initial: index == null ? null : widgets[index],
        period: period,
      ),
    );
    if (spec == null || !context.mounted) return;
    await _save(context, [
      for (final (i, w) in widgets.indexed) i == index ? spec : w,
      if (index == null) spec,
    ]);
  }

  Future<void> _move(BuildContext context, int index, int by) {
    final widgets = [...dashboard.widgets];
    widgets.insert(index + by, widgets.removeAt(index));
    return _save(context, widgets);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final widgets = dashboard.widgets;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (_cardMinWidth + _gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widgets.isEmpty) AppText.body(l10n.analyticsNoWidgets),
            Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final (index, spec) in widgets.indexed)
                  SizedBox(
                    width: width,
                    child: AnalyticsWidgetCard(
                      spec: spec,
                      period: period,
                      actions: editing
                          ? [
                              IconButton(
                                tooltip: l10n.analyticsMoveWidgetBack,
                                icon: const Icon(Icons.arrow_back),
                                onPressed: index == 0
                                    ? null
                                    : () => _move(context, index, -1),
                              ),
                              IconButton(
                                tooltip: l10n.analyticsMoveWidgetForward,
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: index == widgets.length - 1
                                    ? null
                                    : () => _move(context, index, 1),
                              ),
                              IconButton(
                                tooltip: l10n.analyticsEditWidget,
                                icon: const Icon(Icons.tune),
                                onPressed: () => _edit(context, index),
                              ),
                              IconButton(
                                tooltip: l10n.analyticsRemoveWidget,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _save(context, [
                                  for (final (i, w) in widgets.indexed)
                                    if (i != index) w,
                                ]),
                              ),
                            ]
                          : const [],
                    ),
                  ),
              ],
            ),
            if (editing &&
                widgets.length < DwAnalyticsDashboard.maxWidgets) ...[
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.secondary(
                  l10n.analyticsAddWidget,
                  onTap: dw.action((context) => _edit(context, null)),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
