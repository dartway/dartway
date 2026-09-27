import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dw_analytics_dashboards.dart';
import 'dw_analytics_reports.dart';
import 'dw_track_events.dart';

/// The analytics calls, for the project's protocol:
///
/// ```dart
/// final appProtocol = DwWireProtocol(
///   dwAnalyticsProtocolEntries,
///   include: shopProtocol,
/// );
/// ```
const List<DwProtocolEntry> dwAnalyticsProtocolEntries = [
  DwProtocolEntry<DwTrackEvents>('DwTrackEvents', DwTrackEvents.fromJson),
  DwProtocolEntry<DwGetAnalyticsReport>(
    'DwGetAnalyticsReport',
    DwGetAnalyticsReport.fromJson,
  ),
  DwProtocolEntry<DwAnalyticsReport>(
    'DwAnalyticsReport',
    DwAnalyticsReport.fromJson,
  ),
  DwProtocolEntry<DwGetAnalyticsCatalog>(
    'DwGetAnalyticsCatalog',
    DwGetAnalyticsCatalog.fromJson,
  ),
  DwProtocolEntry<DwAnalyticsCatalog>(
    'DwAnalyticsCatalog',
    DwAnalyticsCatalog.fromJson,
  ),
  DwProtocolEntry<DwListAnalyticsDashboards>(
    'DwListAnalyticsDashboards',
    DwListAnalyticsDashboards.fromJson,
  ),
  DwProtocolEntry<DwAnalyticsDashboard>(
    'DwAnalyticsDashboard',
    DwAnalyticsDashboard.fromJson,
  ),
  DwProtocolEntry<DwSaveAnalyticsDashboard>(
    'DwSaveAnalyticsDashboard',
    DwSaveAnalyticsDashboard.fromJson,
  ),
  DwProtocolEntry<DwDeleteAnalyticsDashboard>(
    'DwDeleteAnalyticsDashboard',
    DwDeleteAnalyticsDashboard.fromJson,
  ),
];
