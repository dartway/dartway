/// Analytics for a DartWay server: the app's events stored in batches in the
/// project's own Postgres (`DwTrackEvents`), sessions by inactivity, events
/// the server records itself (`ctx.analytics.track`), and retention.
library;

export 'package:dartway_analytics_shared/dartway_analytics_shared.dart';

export 'src/dw_analytics_migrations.dart'
    show dwAnalyticsMigrations, dwAnalyticsNamespace;
export 'src/dw_analytics_module.dart';
export 'src/dw_analytics_service.dart';
export 'src/dw_analytics_settings.dart';
