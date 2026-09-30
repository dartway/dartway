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
/// ([saving], held by the section for every change of the dashboard) the
/// controls are off, and a second tap cannot send a list that still has the
/// widget the first one removed. The section keys the grid by the dashboard,
/// so what it keeps of a save never outlives a switch to another one.
class AnalyticsDashboardGrid extends HookWidget {
  const AnalyticsDashboardGrid({
    super.key,
    required this.dashboard,
    required this.period,
    required this.editing,
    required this.saving,
    required this.onSaving,
  });

  final DwAnalyticsDashboard dashboard;
  final DwAnalyticsPeriod period;
  final bool editing;
  final bool saving;
  final ValueChanged<bool> onSaving;

  static const double _cardMinWidth = 300;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // What the last save here answered, until the list read after it arrives
    // as [dashboard] — then the dashboard is the truth again.
    final saved = useState<List<DwAnalyticsWidgetSpec>?>(null);
    useEffect(() {
      saved.value = null;
      return null;
    }, [dashboard.updatedAt]);
    final latest = useRef(dashboard.widgets);
    // Read when tapped, not when built: two taps in one frame see it set.
    final busy = useRef(false);
    latest.value = saved.value ?? dashboard.widgets;
    final widgets = latest.value;

    Future<void> save(
      BuildContext context,
      List<DwAnalyticsWidgetSpec> Function(List<DwAnalyticsWidgetSpec>) change,
    ) async {
      if (saving || busy.value) return;
      busy.value = true;
      onSaving(true);
      try {
        final result = await dw.action(
          (_) => dw.plugins.analytics.saveDashboard(
            id: dashboard.id,
            title: dashboard.title,
            widgets: change(latest.value),
          ),
        )(context);
        // Unmounted: the viewer switched to another dashboard, whose grid
        // is a new one; this answer is this dashboard's and is dropped.
        if (result case DwCallOk(
          :final value,
        ) when context.mounted && value.id == dashboard.id) {
          saved.value = value.widgets;
        }
      } finally {
        busy.value = false;
        onSaving(false);
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
        onPressed: saving || index == 0
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
        onPressed: saving || index == widgets.length - 1
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
        onPressed: saving ? null : () => edit(context, index),
      ),
      IconButton(
        tooltip: l10n.analyticsRemoveWidget,
        icon: const Icon(Icons.delete_outline),
        onPressed: saving
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
              const Gap(AppSpace.m),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton.secondary(
                  l10n.analyticsAddWidget,
                  onTap: saving
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
