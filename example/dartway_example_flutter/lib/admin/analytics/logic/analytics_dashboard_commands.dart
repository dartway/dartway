import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';

/// The changes a dashboard is saved and removed by, run inside `dw.action`
/// by the widget that owns the button.
///
/// A save answers the dashboard as stored — the one value a screen needs
/// back — so it is unwrapped here: a refusal is thrown, and `dw.action` shows
/// it through the refusal texts.
abstract final class AnalyticsDashboardCommands {
  /// Saves [widgets] as [dashboard]'s, or a new dashboard when [dashboard] is
  /// `null`, under [title].
  static Future<DwAnalyticsDashboard> save({
    DwAnalyticsDashboard? dashboard,
    required String title,
    required List<DwAnalyticsWidgetSpec> widgets,
  }) async => (await dw.plugins.analytics.saveDashboard(
    id: dashboard?.id,
    title: title,
    widgets: widgets,
  )).valueOrThrow;

  /// Deletes [dashboard].
  static Future<DwCallResult<void>> delete(DwAnalyticsDashboard dashboard) =>
      dw.plugins.analytics.deleteDashboard(dashboard.id);
}
