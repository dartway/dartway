import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_widget_card.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_widget_editor.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// The widgets of [dashboard] in a grid of as many columns as fit.
///
/// Every change sends the whole list, so changes go one at a time and each
/// is built on the list the previous one saved: while a save is under way
/// the controls are off, and a second tap cannot send a list that still has
/// the widget the first one removed.
class AnalyticsDashboardGrid extends HookWidget {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = useState(false);
    // What the last save here answered, until the list read after it arrives
    // as [dashboard] — then the dashboard is the truth again.
    final saved = useState<List<DwAnalyticsWidgetSpec>?>(null);
    useEffect(() {
      saved.value = null;
      return null;
    }, [dashboard.updatedAt]);
    final latest = useRef(dashboard.widgets);
    latest.value = saved.value ?? dashboard.widgets;
    final widgets = latest.value;

    Future<void> save(
      BuildContext context,
      List<DwAnalyticsWidgetSpec> Function(List<DwAnalyticsWidgetSpec>) change,
    ) async {
      if (saving.value) return;
      saving.value = true;
      try {
        final result = await dw.action(
          (_) => dw.plugins.analytics.saveDashboard(
            id: dashboard.id,
            title: dashboard.title,
            widgets: change(latest.value),
          ),
        )(context);
        if (result case DwCallOk(:final value) when context.mounted) {
          saved.value = value.widgets;
        }
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    Future<void> edit(BuildContext context, int? index) async {
      final spec = await context.showAppBottomSheet<DwAnalyticsWidgetSpec>(
        child: AnalyticsWidgetEditor(
          initial: index == null ? null : latest.value[index],
          period: period,
        ),
      );
      if (spec == null || !context.mounted) return;
      await save(
        context,
        (current) => [
          for (final (i, w) in current.indexed) i == index ? spec : w,
          if (index == null) spec,
        ],
      );
    }

    List<Widget> actions(int index) => [
      IconButton(
        tooltip: l10n.analyticsMoveWidgetBack,
        icon: const Icon(Icons.arrow_back),
        onPressed: saving.value || index == 0
            ? null
            : () => save(
                context,
                (current) => [...current]
                  ..insert(index - 1, current[index])
                  ..removeAt(index + 1),
              ),
      ),
      IconButton(
        tooltip: l10n.analyticsMoveWidgetForward,
        icon: const Icon(Icons.arrow_forward),
        onPressed: saving.value || index == widgets.length - 1
            ? null
            : () => save(
                context,
                (current) => [...current]
                  ..insert(index + 2, current[index])
                  ..removeAt(index),
              ),
      ),
      IconButton(
        tooltip: l10n.analyticsEditWidget,
        icon: const Icon(Icons.tune),
        onPressed: saving.value ? null : () => edit(context, index),
      ),
      IconButton(
        tooltip: l10n.analyticsRemoveWidget,
        icon: const Icon(Icons.delete_outline),
        onPressed: saving.value
            ? null
            : () => save(
                context,
                (current) => [
                  for (final (i, w) in current.indexed)
                    if (i != index) w,
                ],
              ),
      ),
    ];

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
                      actions: editing ? actions(index) : const [],
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
                  onTap: saving.value
                      ? null
                      : dw.action((context) => edit(context, null)),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
