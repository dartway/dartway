import 'dart:async';
import 'dart:io';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_alert_sink.dart';
import '../alerts/dw_server_logger.dart';
import '../auth/dw_account_service.dart';
import '../auth/dw_auth_config.dart';
import '../auth/dw_auth_service.dart';
import '../auth/dw_session_cache.dart';
import '../calls/dw_call_endpoint.dart';
import '../channels/dw_channel_rule.dart';
import '../files/dw_file_service.dart';
import '../files/dw_file_storage.dart';
import '../handlers/dw_call_handler.dart';
import '../http/dw_http_front.dart';
import '../jobs/dw_job_queue.dart';
import '../jobs/dw_job_runner.dart';
import '../live/dw_live_endpoint.dart';
import '../live/dw_live_hub.dart';
import '../live/dw_web_origin.dart';
import '../migrations/dw_framework_migrations.dart';
import '../routes/dw_route.dart';
import 'dw_runtime.dart';
import 'dw_server_settings.dart';

/// The server refused to start: its declaration is inconsistent. Every
/// problem is listed at once.
final class DwStartupException implements Exception {
  DwStartupException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      'DwStartupException: the server cannot start:\n'
      '${problems.map((p) => '  - $p').join('\n')}';
}

/// A DartWay application server, directly on `dart:io` (D-028).
///
/// `start()` validates the declaration, opens the database, applies the
/// framework's and the project's migrations, starts the job executor and
/// serves one port:
///
/// ```
/// POST /dw/<WireName>   requests and commands
/// GET  /dw/live         the live update socket
/// GET  /health          liveness and database reachability
/// *                     the project's routes
/// ```
///
/// Any failure throws, and the process exits non-zero.
final class DwAppServer {
  DwAppServer({
    required this.protocol,
    this.schema,
    required this.migrations,
    required this.database,
    required this.auth,
    required this.handlers,
    this.channels = const [],
    this.jobs = const [],
    this.routes = const [],
    this.files,
    this.port = 8080,
    InternetAddress? address,
    DwAlertSink? alerts,
    this.logger = const DwConsoleLogger(),
    this.settings = const DwServerSettings(),
  }) : address = address ?? InternetAddress.anyIPv4,
       alerts = alerts ?? DwLogAlertSink(logger);

  /// The framework's migrations, namespace `dw`. Applied by [start]; listed
  /// here for a project's migration CLI and schema checks.
  static List<DwDatabaseMigration> get frameworkMigrations =>
      dwFrameworkMigrations;

  final DwWireProtocol protocol;

  /// The project's target schema (the generated `appSchema`).
  ///
  /// When given, [start] checks after migrating that every table and column
  /// it declares exists, and refuses to start otherwise: a migration missing
  /// from the list would make handlers fail on their first query instead.
  /// Only absences fail — extra tables, extra columns and differences in
  /// types, defaults or constraints are the migrations' business, checked by
  /// `migrate check` in CI, and a server must not refuse to start over an
  /// index an operator added by hand.
  final DwDatabaseSchema? schema;
  final List<DwDatabaseMigration> migrations;
  final DwDatabaseConfig database;
  final DwAuthConfig auth;
  final List<DwCallHandler> handlers;
  final List<DwChannelRule> channels;
  final List<DwJobDefinition> jobs;
  final List<DwRoute> routes;

  /// File uploads: storage, a rule per purpose, who reads private files.
  /// Without it the framework's file calls fail as incidents and `ctx.files`
  /// throws — the `dw_stored_file` table exists either way.
  final DwFileStorage? files;

  final int port;
  final InternetAddress address;
  final DwAlertSink alerts;
  final DwServerLogger logger;
  final DwServerSettings settings;

  _DwRunning? _running;
  bool _stopping = false;

  /// The port actually bound (differs from [port] when it was 0).
  int get boundPort => _require.front.port;

  /// The database, once started.
  DwDatabaseHandle get db => _require.database.db;

  /// Accounts by identifier, once started — for a bootstrap that creates or
  /// promotes an admin after [start]. Sessions it revokes end on this server
  /// at once.
  DwAccountService get accounts => DwAccountService.ofRuntime(_require.runtime);

  _DwRunning get _require =>
      _running ?? (throw StateError('The server is not running'));

  /// Starts the server; on SIGINT or SIGTERM it stops gracefully.
  Future<void> start() =>
      startOn(port: port, address: address, handleSignals: true);

  @internal
  Future<void> startOn({
    required int port,
    required InternetAddress address,
    required bool handleSignals,
  }) async {
    if (_running != null || _stopping) {
      throw StateError('The server is already running');
    }
    final problems = validate();
    if (problems.isNotEmpty) throw DwStartupException(problems);

    DwPostgresDatabase? openedDatabase;
    DwJobRunner? jobRunner;
    DwHttpFront? front;
    final fileStore = switch (files) {
      final storage? => DwFileStore(storage),
      null => null,
    };
    try {
      // Before anything opens: a bucket that is missing, or more public or
      // less public than declared, is a configuration the server must not
      // serve on — a private file behind a public bucket is already leaked.
      if (fileStore != null && fileStore.storage.config.verifyBuckets) {
        final bucketProblems = await fileStore.verifyBuckets();
        if (bucketProblems.isNotEmpty) {
          throw DwStartupException(bucketProblems);
        }
        logger.info(
          'file storage buckets verified: ${[if (fileStore.storage.config.publicBucket case final bucket?) 'public "$bucket" reads anonymously', if (fileStore.storage.config.privateBucket case final bucket?) 'private "$bucket" does not'].join(', ')}',
        );
      }
      openedDatabase = await DwPostgresDatabase.open(database);
      fileStore?.attach(openedDatabase.db);
      await DwMigrationRunner(
        openedDatabase.db,
        migrations: {
          dwFrameworkNamespace: dwFrameworkMigrations,
          'app': migrations,
        },
      ).apply();
      if (schema case final declared?) {
        final missing = await _missingFromDatabase(declared, openedDatabase.db);
        if (missing.isNotEmpty) throw DwStartupException(missing);
      }

      late final DwJobRunner runner;
      final runtime = DwRuntime(
        protocol: protocol,
        auth: auth,
        db: openedDatabase.db,
        hub: DwLiveHub(),
        sessions: DwSessionCache(
          capacity: settings.tokenCacheSize,
          ttl: settings.tokenCacheTtl,
        ),
        alerts: DwAlertGate(
          sink: alerts,
          logger: logger,
          maxPerWindow: settings.alertsPerSignature,
          window: settings.alertWindow,
        ),
        log: logger,
        jobsFor: (ctx) => runner.jobsFor(ctx),
        files: fileStore,
      );
      final authService = DwAuthService(runtime);
      runner = jobRunner = DwJobRunner(
        runtime: runtime,
        definitions: [...jobs, _cleanupJob(), ...?fileStore?.jobs()],
        listen: openedDatabase.listen,
        workers: settings.jobWorkers,
        pollInterval: settings.jobPollInterval,
      );
      await runner.start();

      front = DwHttpFront(
        runtime: runtime,
        settings: settings,
        calls: DwCallEndpoint(
          runtime: runtime,
          authService: authService,
          settings: settings,
          handlers: {
            for (final handler in [
              ...handlers,
              ...authService.handlers(),
              ...fileStore?.handlers() ?? DwFileStore.unconfiguredHandlers(),
            ])
              handler.callType: handler,
          },
        ),
        live: DwLiveEndpoint(
          runtime: runtime,
          authService: authService,
          settings: settings,
          channelRules: {
            for (final rule in channels) rule.kind.channelName: rule,
          },
        ),
        routes: routes,
      );
      await front.bind(address, port);
      final running = _DwRunning(
        database: openedDatabase,
        runtime: runtime,
        jobRunner: runner,
        front: front,
        files: fileStore,
      );
      _running = running;
      if (handleSignals) {
        running.signals = [
          for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm])
            signal.watch().listen((_) {
              logger.info('received $signal; stopping');
              unawaited(stop());
            }),
        ];
      }
      logger.info('DartWay server listening on port ${front.port}');
    } catch (_) {
      await front?.close();
      await jobRunner?.stop();
      await openedDatabase?.close();
      fileStore?.close();
      rethrow;
    }
  }

  /// Stops gracefully: no new connections are accepted, calls in flight
  /// finish and are answered (their updates delivered), live sockets close
  /// with 1001 (`DwCloseCode.serverStopping`), running jobs finish, then the
  /// database closes. Each wait is bounded by `DwServerSettings.stopTimeout`.
  Future<void> stop() async {
    final running = _running;
    if (running == null || _stopping) return;
    _stopping = true;
    try {
      for (final subscription in running.signals) {
        await subscription.cancel();
      }
      await running.front.drain(settings.stopTimeout);
      final connections = List.of(running.runtime.hub.connections);
      await Future.wait([
        for (final connection in connections)
          connection.close(DwCloseCode.serverStopping, 'dw.serverStopping'),
      ]);
      await running.jobRunner.stop().timeout(
        settings.stopTimeout,
        onTimeout: () => logger.warning('jobs still running at stop timeout'),
      );
      await running.front.close();
      await running.database.close();
      running.files?.close();
      logger.info('DartWay server stopped');
    } finally {
      _running = null;
      _stopping = false;
    }
  }

  /// Wakes the job executor at once instead of at its next notification or
  /// poll.
  @internal
  void wakeJobs() => _require.jobRunner.wake();

  /// Problems with the declaration, empty when it is consistent.
  @internal
  List<String> validate() {
    final problems = <String>[];
    // Each handler factory bounds its call class by kind (`single` takes a
    // `DwSingleRequest`, `command` a `DwActionCommand`), so a handler of the
    // wrong kind does not compile; what is left to check is the registry.
    final handled = <Type>{};
    for (final handler in handlers) {
      final type = handler.callType;
      if (DwAuthService.builtInTypes.contains(type) ||
          DwFileStore.builtInTypes.contains(type)) {
        problems.add('$type has a built-in handler and cannot have another');
      } else if (!protocol.knows(type)) {
        problems.add(
          'the $handler handler answers $type, which the protocol does not '
          'register',
        );
      } else if (!handled.add(type)) {
        problems.add('$type has more than one handler');
      }
      if (handler.accessProblem case final problem?) problems.add(problem);
    }
    // The other direction: a registered call nobody answers would fail at
    // runtime, found by the first user to press the button.
    for (final entry in protocol.entries) {
      final kind = entry.kind;
      if (kind != DwWireObjectKind.request &&
          kind != DwWireObjectKind.command) {
        continue;
      }
      if (DwAuthService.builtInTypes.contains(entry.type) ||
          DwFileStore.builtInTypes.contains(entry.type)) {
        continue;
      }
      if (!handled.contains(entry.type)) {
        problems.add(
          '${entry.type} is a registered ${kind.name} without a handler',
        );
      }
    }
    final kinds = <String>{};
    for (final rule in channels) {
      final name = rule.kind.channelName;
      if (name.isEmpty || name.contains(':')) {
        problems.add('channel kind "$name" must be non-empty and without ":"');
      }
      if (!kinds.add(name)) {
        problems.add('channel kind "$name" has more than one rule');
      }
    }
    final jobNames = <String>{};
    for (final job in jobs) {
      if (job.name.startsWith('dw.')) {
        problems.add(
          'job "${job.name}": names starting with "dw." are the '
          "framework's",
        );
      }
      if (!jobNames.add(job.name)) {
        problems.add('job "${job.name}" is declared more than once');
      }
      if (job case DwRecurringJob(:final every) when every <= Duration.zero) {
        problems.add('recurring job "${job.name}" needs a positive interval');
      }
      if (job case DwQueuedJob(:final maxAttempts) when maxAttempts < 1) {
        problems.add('job "${job.name}" needs at least one attempt');
      }
    }
    for (final origin in settings.allowedOrigins) {
      if (DwWebOrigin.parse(origin) == null) {
        problems.add(
          'allowed origin "$origin" is not a full origin: scheme, host and '
          'an optional port, as a browser sends it (https://app.example.com, '
          'http://localhost:5000)',
        );
      }
    }
    if (files case final storage?) problems.addAll(storage.problems);
    final routeKeys = <String>{};
    for (final route in routes) {
      final path = route.path;
      if (path == '/dw' ||
          path.startsWith(DwHttpContract.pathPrefix) ||
          path == DwHttpContract.healthPath) {
        problems.add('route $route is reserved by the framework');
      } else if (!path.startsWith('/')) {
        problems.add('route $route: a path starts with "/"');
      }
      if (!routeKeys.add('$route')) {
        problems.add('route $route is declared twice');
      }
    }
    return problems;
  }

  /// Tables and columns of [declared] that the database does not have.
  ///
  /// The introspection covers the whole database schema, but the diff is
  /// taken against the declared tables only, so nothing else can make the
  /// check fail.
  static Future<List<String>> _missingFromDatabase(
    DwDatabaseSchema declared,
    DwDatabaseHandle db,
  ) async {
    if (declared.tables.isEmpty) return const [];
    final names = {for (final table in declared.tables) table.name};
    final introspected = await DwSchemaIntrospector.read(db);
    final present = DwDatabaseSchema.fromTables(
      introspected.schema.tables.where((table) => names.contains(table.name)),
    );
    return [
      for (final change in DwSchemaDiff.compare(from: present, to: declared))
        if (change case DwCreateTable(:final table))
          'table "$table" is declared in the schema and missing from the '
              'database: is its migration registered?'
        else if (change case DwAddColumn(:final table, :final column))
          'column "$table.${column.name}" is declared in the schema and '
              'missing from the database: is its migration registered?',
    ];
  }

  DwRecurringJob _cleanupJob() {
    final ticketRetention = [
      auth.requestWindow,
      auth.codeLifetime,
      auth.resendDelay,
    ].reduce((a, b) => a > b ? a : b);
    return DwRecurringJob(
      'dw.cleanup',
      every: const Duration(hours: 1),
      handle: (ctx) async {
        await ctx.db.execute(
          'DELETE FROM dw_command_outcome '
          'WHERE created_at < now() - @age::int8 * interval \'1 microsecond\'',
          params: {'age': settings.commandOutcomeRetention.inMicroseconds},
        );
        await ctx.db.execute(
          'DELETE FROM dw_code_ticket '
          'WHERE created_at < now() - @age::int8 * interval \'1 microsecond\'',
          params: {'age': ticketRetention.inMicroseconds},
        );
        // A revoked key has no use once its revocation has been delivered and
        // every cache has forgotten it.
        await ctx.db.execute(
          "DELETE FROM dw_auth_key WHERE revoked_at < now() - interval '1 day'",
        );
      },
    );
  }
}

/// The parts that exist while a server runs.
final class _DwRunning {
  _DwRunning({
    required this.database,
    required this.runtime,
    required this.jobRunner,
    required this.front,
    required this.files,
  });

  final DwPostgresDatabase database;
  final DwRuntime runtime;
  final DwJobRunner jobRunner;
  final DwHttpFront front;
  final DwFileStore? files;
  List<StreamSubscription<ProcessSignal>> signals = const [];
}
