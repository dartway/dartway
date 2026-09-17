import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'dw_analytics_batches.dart';
import 'dw_analytics_migrations.dart';
import 'dw_analytics_settings.dart';

/// Analytics on a DartWay server.
///
/// ```dart
/// DwAppServer(
///   protocol: DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol),
///   modules: [DwAnalyticsModule()],
///   ...
/// );
///
/// // in a command, in its transaction:
/// await ctx.analytics.track(ShopEvent.orderPlaced, properties: {'total': 1290});
/// ```
///
/// It brings the `analytics` tables, the `DwTrackEvents` handler the app's
/// `DwAnalytics` plugin sends batches to, and the retention job
/// (`dw.analytics.cleanup`). Everything stays in the project's database:
/// nothing is sent to a third party.
final class DwAnalyticsModule extends DwServerModule {
  DwAnalyticsModule({this.settings = const DwAnalyticsSettings()});

  /// The recurring retention job.
  static const String cleanupJob = 'dw.analytics.cleanup';

  /// Rows removed per statement; a larger backlog goes over several runs.
  static const int cleanupBatch = 10000;

  final DwAnalyticsSettings settings;

  @override
  String get namespace => dwAnalyticsNamespace;

  @override
  List<DwDatabaseMigration> get migrations => dwAnalyticsMigrations;

  @override
  late final List<DwCallHandler> handlers = [
    DwAnalyticsBatches(settings).handler(),
  ];

  @override
  late final List<DwJobDefinition> jobs = [
    DwRecurringJob(
      cleanupJob,
      every: settings.cleanupInterval,
      handle: _cleanup,
    ),
  ];

  Future<void> _cleanup(DwCallContext ctx) async {
    final micros = settings.retention.inMicroseconds;
    await ctx.db.execute(
      'DELETE FROM dw_analytics_event WHERE id IN (SELECT id FROM '
      "dw_analytics_event WHERE received_at < now() - @micros::int8 * interval "
      "'1 microsecond' LIMIT @batch)",
      params: {'micros': micros, 'batch': cleanupBatch},
    );
    // An install not seen for the whole retention has no events left to
    // link; its row goes too.
    await ctx.db.execute(
      'DELETE FROM dw_analytics_install WHERE install_id IN (SELECT install_id '
      "FROM dw_analytics_install WHERE last_seen_at < now() - @micros::int8 "
      "* interval '1 microsecond' LIMIT @batch)",
      params: {'micros': micros, 'batch': cleanupBatch},
    );
  }

  @override
  List<String> problems(DwWireProtocol protocol) => [
    ...settings.problems,
    if (!protocol.knows(DwTrackEvents))
      'analytics: the protocol does not register DwTrackEvents — build it as '
          'DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol)',
  ];
}
