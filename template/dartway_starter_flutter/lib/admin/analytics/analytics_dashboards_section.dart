import 'package:collection/collection.dart';
import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_starter_flutter/admin/analytics/logic/analytics_period_choice.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_dashboard_actions.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_dashboard_grid.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_period_bar.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_title_sheet.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The project's analytics dashboards: one shown at a time, every widget of
/// it over the period chosen on top, and — in edit mode — widgets added,
/// changed, moved and removed.
class AnalyticsDashboardsSection extends HookConsumerWidget
    implements DwFeatureWidget {
  const AnalyticsDashboardsSection({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/analytics',
    title: 'Analytics dashboards',
    purpose:
        'What people do in the app, as the numbers the team watches — built '
        'here, without code.',
    behaviors: [
      'Dashboards are the project\'s, not an admin\'s: every admin sees the '
          'same ones.',
      'One dashboard is shown; a menu switches between them when there are '
          'several.',
      'A period on top — the last 7, 30 or 90 days, or picked dates — '
          'applies to every widget.',
      'Three kinds of widget: a number (with its change against the '
          'previous period of the same length, when asked), bars (by day, '
          'week, month or by the values of a property) and a pie.',
      'In edit mode a widget is added, edited, moved back or forward and '
          'removed; each change is saved at once.',
      'Events and property keys are offered from what was recorded in the '
          'period; a filter value is typed.',
    ],
    implementationNotes: [
      'Reads are DwGetAnalyticsReport per widget, cached and shared by '
          'equal requests; the period is fixed when chosen, so a rebuild does '
          'not make new requests.',
      'Changes go through dw.plugins.analytics.saveDashboard / '
          'deleteDashboard, which read the dashboard list again — the module '
          'has no channel to announce them.',
      'Charts are the UI kit\'s (AppBarChart, AppPieChart, AppStatValue): '
          'plain widgets, and a painter for the pie ring.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selectedId = useState<int?>(null);
    final editing = useState(false);
    // A dashboard change under way. Every change sends a whole dashboard, so
    // the next one — a widget, a rename, a delete — waits for it.
    final saving = useState(false);
    final choice = useState(
      AnalyticsPeriodChoice.lastDays(AnalyticsPeriodChoice.defaultDays),
    );

    Future<void> createDashboard() async {
      final title = await context.showAppBottomSheet<String>(
        child: const AnalyticsTitleSheet(),
      );
      if (title == null || !context.mounted) return;
      final result = await dw.action(
        (_) =>
            dw.plugins.analytics.saveDashboard(title: title, widgets: const []),
      )(context);
      if (result case DwCallOk(:final value)) {
        selectedId.value = value.id;
        editing.value = true;
      }
    }

    const request = DwListAnalyticsDashboards();
    return ref
        .watch(dw.request(request))
        .section(
          loadingValue: const <DwAnalyticsDashboard>[],
          onRetry: () => ref.read(dw.request(request).notifier).refetch(),
          builder: (dashboards) {
            final dashboard =
                dashboards.firstWhereOrNull((d) => d.id == selectedId.value) ??
                dashboards.firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: AppText.title(l10n.analyticsTitle)),
                    if (dashboards.length > 1 && dashboard != null)
                      DropdownButton<int>(
                        value: dashboard.id,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final d in dashboards)
                            DropdownMenuItem(value: d.id, child: Text(d.title)),
                        ],
                        onChanged: (id) => selectedId.value = id,
                      ),
                    if (dashboard != null)
                      IconButton(
                        tooltip: editing.value
                            ? l10n.analyticsDoneEditing
                            : l10n.analyticsEditDashboard,
                        icon: Icon(editing.value ? Icons.check : Icons.edit),
                        onPressed: () => editing.value = !editing.value,
                      ),
                    IconButton(
                      tooltip: l10n.analyticsNewDashboard,
                      icon: const Icon(Icons.add),
                      onPressed: createDashboard,
                    ),
                  ],
                ),
                const Gap(8),
                if (dashboard == null)
                  AppText.body(l10n.analyticsNoDashboards)
                else ...[
                  if (dashboards.length == 1 || editing.value)
                    AppText.body(dashboard.title),
                  const Gap(8),
                  AnalyticsPeriodBar(
                    choice: choice.value,
                    onChanged: (next) => choice.value = next,
                  ),
                  const Gap(16),
                  // Keyed by the dashboard: what the grid keeps of a save
                  // belongs to that dashboard, and a switch — even with a save
                  // under way — starts the next one's grid afresh.
                  AnalyticsDashboardGrid(
                    key: ValueKey(dashboard.id),
                    dashboard: dashboard,
                    period: choice.value.period,
                    editing: editing.value,
                    saving: saving.value,
                    onSaving: (value) => saving.value = value,
                  ),
                  if (editing.value) ...[
                    const Gap(16),
                    AnalyticsDashboardActions(
                      dashboard: dashboard,
                      enabled: !saving.value,
                      onDeleted: () {
                        selectedId.value = null;
                        editing.value = false;
                      },
                    ),
                  ],
                ],
              ],
            );
          },
        );
  }
}
