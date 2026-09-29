import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_starter_flutter/admin/analytics/logic/analytics_dashboard_commands.dart';
import 'package:dartway_starter_flutter/admin/analytics/widgets/analytics_title_sheet.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';

/// Renaming and deleting the dashboard, in edit mode.
class AnalyticsDashboardActions extends StatelessWidget {
  const AnalyticsDashboardActions({
    super.key,
    required this.dashboard,
    required this.onDeleted,
    this.enabled = true,
  });

  final DwAnalyticsDashboard dashboard;
  final VoidCallback onDeleted;

  /// Off while a change of the dashboard is under way: a rename sends its
  /// widgets, and would send them as they were before that change.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      children: [
        AppButton.text(
          l10n.analyticsRenameDashboard,
          onTap: !enabled
              ? null
              : dw.action((context) async {
                  final title = await context.showAppBottomSheet<String>(
                    child: AnalyticsTitleSheet(initial: dashboard.title),
                  );
                  if (title == null) return null;
                  return AnalyticsDashboardCommands.save(
                    dashboard: dashboard,
                    title: title,
                    widgets: dashboard.widgets,
                  );
                }),
        ),
        AppButton.text(
          l10n.analyticsDeleteDashboard,
          onTap: !enabled
              ? null
              : dw.action(
                  (_) => AnalyticsDashboardCommands.delete(dashboard),
                  confirmation: DwUiConfirmation(
                    l10n.analyticsDeleteDashboardConfirmation(dashboard.title),
                  ),
                  // Run on success only: a refusal is shown instead.
                  followUpIfMountedAction: (_, _) => onDeleted(),
                ),
        ),
      ],
    );
  }
}
