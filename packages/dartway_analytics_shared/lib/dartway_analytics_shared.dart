/// The analytics contract shared by a DartWay server and its app: the events
/// a project declares ([DwAnalyticsEvent]), [DwTrackEvents] — the batch the
/// app sends them in — and the reads of what was recorded: reports
/// ([DwGetAnalyticsReport]), the catalog of names and keys
/// ([DwGetAnalyticsCatalog]) and saved dashboards ([DwAnalyticsDashboard]).
library;

export 'src/dw_analytics_dashboards.dart';
export 'src/dw_analytics_event.dart';
export 'src/dw_analytics_protocol.dart';
export 'src/dw_analytics_reports.dart';
export 'src/dw_track_events.dart';
