import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'dw_analytics_batches.dart';
import 'dw_analytics_dashboards.dart';
import 'dw_analytics_migrations.dart';
import 'dw_analytics_reports.dart';
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
/// `DwAnalytics` plugin sends batches to, the retention job
/// (`dw.analytics.cleanup`), and the reads of what was recorded: reports
/// (`DwGetAnalyticsReport`), the catalog of names and keys
/// (`DwGetAnalyticsCatalog`) and saved dashboards. Everything stays in the
/// project's database: nothing is sent to a third party.
///
/// Who reads is the project's to say — the framework knows no roles:
///
/// ```dart
/// DwAnalyticsModule(readAccess: AppAccess.admin)
/// ```
///
/// Without [readAccess] every read is refused `dw.forbidden`.
final class DwAnalyticsModule extends DwServerModule {
  DwAnalyticsModule({
    this.settings = const DwAnalyticsSettings(),
    DwAccessRule? readAccess,
    DwAccessRule? editAccess,
  }) : readAccess = readAccess ?? _closed,
       editAccess = editAccess ?? readAccess ?? _closed;

  /// The recurring retention job.
  static const String cleanupJob = 'dw.analytics.cleanup';

  /// Rows removed per statement; a larger backlog goes over several runs.
  static const int cleanupBatch = 10000;

  final DwAnalyticsSettings settings;

  /// Who reads reports, the catalog and the dashboards. By default nobody:
  /// a signed-in caller is refused `dw.forbidden`.
  final DwAccessRule readAccess;

  /// Who saves and deletes dashboards; by default whoever has [readAccess].
  final DwAccessRule editAccess;

  /// The rule of a module given none: every call refused `dw.forbidden`.
  static final DwAccessRule _closed = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, call) async => false,
  );

  @override
  String get namespace => dwAnalyticsNamespace;

  @override
  List<DwDatabaseMigration> get migrations => dwAnalyticsMigrations;

  @override
  late final List<DwCallHandler> handlers = [
    DwAnalyticsBatches(settings).handler(),
    ...DwAnalyticsReports.handlers(readAccess),
    ...DwAnalyticsDashboards.handlers(read: readAccess, edit: editAccess),
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
  List<String> problems(DwWireProtocol protocol) {
    final missing = [
      for (final type in _calls)
        if (!protocol.knows(type)) type,
    ];
    return [
      ...settings.problems,
      for (final (name, rule) in [
        ('readAccess', readAccess),
        ('editAccess', editAccess),
      ])
        if (rule == DwAccessRule.anonymous)
          'analytics: $name is DwAccessRule.anonymous — anyone, signed in or '
              'not, would read what the app records',
      if (missing.isNotEmpty)
        'analytics: the protocol does not register ${missing.join(', ')} — '
            'build it as '
            'DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol)',
    ];
  }

  static const List<Type> _calls = [
    DwTrackEvents,
    DwGetAnalyticsReport,
    DwGetAnalyticsCatalog,
    DwListAnalyticsDashboards,
    DwSaveAnalyticsDashboard,
    DwDeleteAnalyticsDashboard,
  ];
}
