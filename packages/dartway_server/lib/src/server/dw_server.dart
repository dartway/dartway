import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';
import 'package:relic/relic.dart';

import '../alerts/dw_alerts.dart';
import '../alerts/dw_logger.dart';
import '../auth/dw_accounts.dart';
import '../auth/dw_auth.dart';
import '../auth/dw_auth_service.dart';
import '../channels/dw_channel_rule.dart';
import '../channels/dw_hub.dart';
import '../handlers/dw_handler.dart';
import '../jobs/dw_job_runner.dart';
import '../jobs/dw_jobs.dart';
import '../migrations/dw_framework_migrations.dart';
import '../protocol/dw_connection.dart';
import '../routes/dw_route.dart';
import 'dw_dispatcher.dart';
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

/// A DartWay application server.
///
/// `start()` validates the declaration, opens the database, applies the
/// framework's and the project's migrations, starts the job executor and
/// serves: the app WebSocket at `/dw` (wire version in the query, `?v=1`),
/// `GET /health`, and the project's [routes]. Any failure throws, and the
/// process exits non-zero.
final class DwServer {
  DwServer({
    required this.protocol,
    this.schema,
    required this.migrations,
    required this.database,
    required this.auth,
    required this.handlers,
    this.channels = const [],
    this.jobs = const [],
    this.routes = const [],
    this.port = 8080,
    InternetAddress? address,
    DwAlerts? alerts,
    this.logger = const DwStdLogger(),
    this.settings = const DwServerSettings(),
  }) : address = address ?? InternetAddress.anyIPv4,
       alerts = alerts ?? DwLogAlerts(logger);

  /// The framework's migrations, namespace `dw`. Applied by [start]; listed
  /// here for a project's migration CLI and schema checks.
  static List<DwMigration> get frameworkMigrations => dwFrameworkMigrations;

  final DwProtocol protocol;

  /// The project's target schema (the generated `appSchema`).
  ///
  /// When given, [start] checks after migrating that every table and column
  /// it declares exists, and refuses to start otherwise: a migration missing
  /// from the list would make handlers fail on their first query instead.
  /// Only absences fail — extra tables, extra columns and differences in
  /// types, defaults or constraints are the migrations' business, checked by
  /// `migrate check` in CI, and a server must not refuse to start over an
  /// index an operator added by hand.
  final DwSchema? schema;
  final List<DwMigration> migrations;
  final DwDatabaseConfig database;
  final DwAuth auth;
  final List<DwHandler> handlers;
  final List<DwChannelRule> channels;
  final List<DwJobDefinition> jobs;
  final List<DwRoute> routes;
  final int port;
  final InternetAddress address;
  final DwAlerts alerts;
  final DwLogger logger;
  final DwServerSettings settings;

  _DwRunning? _running;
  bool _stopping = false;

  /// The port actually bound (differs from [port] when it was 0).
  int get boundPort => _require.relic.port;

  /// The database, once started.
  DwDb get db => _require.database.db;

  /// Accounts by identifier, once started — for a bootstrap that creates or
  /// promotes an admin after [start]. Sessions it revokes close on this
  /// server's connections.
  DwAccounts get accounts => DwAccounts.ofRuntime(_require.runtime);

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

    DwDatabase? openedDatabase;
    DwJobRunner? jobRunner;
    RelicApp? app;
    try {
      openedDatabase = await DwDatabase.open(database);
      await DwMigrator(
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

      final hub = DwHub(protocol);
      final gate = DwAlertGate(
        sink: alerts,
        logger: logger,
        maxPerWindow: settings.alertsPerSignature,
        window: settings.alertWindow,
      );
      late final DwJobRunner runner;
      final runtime = DwRuntime(
        protocol: protocol,
        auth: auth,
        db: openedDatabase.db,
        hub: hub,
        alerts: gate,
        log: logger,
        jobsFor: (ctx) => runner.jobsFor(ctx),
      );
      final authService = DwAuthService(auth, runtime);
      runner = jobRunner = DwJobRunner(
        runtime: runtime,
        definitions: [...jobs, _cleanupJob()],
        listen: openedDatabase.listen,
        workers: settings.jobWorkers,
        pollInterval: settings.jobPollInterval,
      );
      await runner.start();

      final dispatcher = DwDispatcher(runtime, {
        for (final handler in [...handlers, ...authService.handlers()])
          handler.type: handler,
      });
      final running = _DwRunning(
        database: openedDatabase,
        runtime: runtime,
        dispatcher: dispatcher,
        authService: authService,
        jobRunner: runner,
        channelRules: {
          for (final rule in channels) rule.kind.channelName: rule,
        },
      );
      app = RelicApp()
        ..get('/dw', (request) => _upgrade(running, request))
        ..get('/health', (request) => _health(running));
      for (final route in routes) {
        app.add(route.method, route.path, _routeHandler(running, route));
      }
      running.app = app;
      running.relic = await app.run(() => IOAdapter.bind(address, port: port));
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
      logger.info('DartWay server listening on port ${running.relic.port}');
    } catch (_) {
      await jobRunner?.stop();
      await app?.close();
      await openedDatabase?.close();
      rethrow;
    }
  }

  /// Stops gracefully: running calls finish and are answered, every
  /// connection is closed with 1001, running jobs finish, then the database
  /// closes.
  Future<void> stop() async {
    final running = _running;
    if (running == null || _stopping) return;
    _stopping = true;
    try {
      for (final subscription in running.signals) {
        await subscription.cancel();
      }
      final connections = List.of(running.runtime.hub.connections);
      await Future.wait([
        for (final connection in connections) connection.whenIdle(),
      ]).timeout(
        settings.stopTimeout,
        onTimeout: () {
          logger.warning('calls still running at stop timeout');
          return const [];
        },
      );
      await Future.wait([
        for (final connection in connections)
          connection.close(DwCloseCode.serverStopping, 'dw.serverStopping'),
      ]);
      await running.jobRunner.stop().timeout(
        settings.stopTimeout,
        onTimeout: () => logger.warning('jobs still running at stop timeout'),
      );
      await running.app.close();
      await running.database.close();
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
    final seen = <Type>{};
    for (final handler in handlers) {
      final type = handler.type;
      if (DwAuthService.builtInTypes.contains(type)) {
        problems.add('$type has a built-in handler and cannot have another');
      } else if (!protocol.knows(type)) {
        problems.add(
          'a handler is registered for $type, which the protocol '
          'does not know',
        );
      } else if (!seen.add(type)) {
        problems.add('$type has more than one handler');
      } else if (handler is DwRequestHandler && handler.isForPagedRequest) {
        problems.add('$type is paginated: register it with DwHandler.page');
      }
    }
    // The other direction: a registered request or command nobody answers
    // would fail every call at runtime, found by the first user to press the
    // button. `seen` holds only handlers of registered types, so a type with
    // two handlers is reported once, above.
    for (final entry in protocol.entries) {
      final kind = entry.kind;
      if (kind != DwDtoKind.request && kind != DwDtoKind.command) continue;
      if (DwAuthService.builtInTypes.contains(entry.type)) continue;
      if (!seen.contains(entry.type)) {
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
    final routeKeys = <String>{};
    for (final route in routes) {
      final key = '${route.method.name.toUpperCase()} ${route.path}';
      if (route.path == '/dw' || route.path == '/health') {
        problems.add('route $key is reserved by the framework');
      }
      if (!routeKeys.add(key)) problems.add('route $key is declared twice');
    }
    return problems;
  }

  /// Tables and columns of [declared] that the database does not have.
  ///
  /// The introspection covers the whole database schema (its catalog queries
  /// have no table filter to narrow them by), but the diff is taken against
  /// the declared tables only, so nothing else can make the check fail.
  static Future<List<String>> _missingFromDatabase(
    DwSchema declared,
    DwDb db,
  ) async {
    if (declared.tables.isEmpty) return const [];
    final names = {for (final table in declared.tables) table.name};
    final introspected = await DwIntrospector.read(db);
    final present = DwSchema.fromTables(
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
        // A revoked key has no use once its revocation has been delivered.
        await ctx.db.execute(
          "DELETE FROM dw_auth_key WHERE revoked_at < now() - interval '1 day'",
        );
      },
    );
  }

  // --- HTTP ------------------------------------------------------------------

  Future<Response> _health(_DwRunning running) async {
    try {
      await running.database.db.query('SELECT 1');
      return Response.ok(body: Body.fromString('ok'));
    } catch (error) {
      logger.warning('health check: database unavailable', error: error);
      return Response(503, body: Body.fromString('database unavailable'));
    }
  }

  Handler _routeHandler(_DwRunning running, DwRoute route) {
    final where = 'route ${route.method.name.toUpperCase()} ${route.path}';
    return (request) async {
      final ctx = running.runtime.context(scope: where);
      try {
        return await route.handle(ctx, request);
      } on DwRefusalException catch (refusal) {
        return DwRoute.json({'refusal': refusal.refusal.toJson()}, status: 400);
      } on DwNotAuthenticatedException {
        return Response.unauthorized();
      } catch (error, stackTrace) {
        final incident = running.runtime.alerts.report(
          where: where,
          error: error,
          stackTrace: stackTrace,
        );
        return DwRoute.json({'incident': incident}, status: 500);
      } finally {
        running.runtime.deliver(ctx);
      }
    };
  }

  static const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  /// Upgrades `/dw` by hijacking the socket and handing it to `dart:io`'s
  /// WebSocket, instead of relic's `WebSocketUpgrade`: only the `dart:io`
  /// object exposes `addStream`, the one signal of how much the peer has not
  /// consumed, which the outbound ceiling is measured by.
  Result _upgrade(_DwRunning running, Request request) {
    if (_stopping) {
      return Response(503, body: Body.fromString('server stopping'));
    }
    String? header(String name) {
      final values = request.headers[name];
      return values == null || values.isEmpty ? null : values.join(',');
    }

    final upgrade = header('upgrade')?.toLowerCase();
    final connectionHeader = header('connection')?.toLowerCase() ?? '';
    final key = header('sec-websocket-key');
    if (upgrade != 'websocket' ||
        !connectionHeader.split(',').any((t) => t.trim() == 'upgrade') ||
        key == null ||
        _decodedLength(key) != 16) {
      return Response.badRequest(
        body: Body.fromString('a WebSocket upgrade is expected'),
      );
    }
    if (header('sec-websocket-version') != '13') {
      return Response(
        426,
        headers: Headers.build((h) => h['sec-websocket-version'] = ['13']),
      );
    }
    final origin = header('origin');
    if (origin != null && !_originAllowed(origin, request.url.host)) {
      return Response.forbidden();
    }
    final version = request.url.queryParameters['v'];
    final accept = base64.encode(
      sha1.convert(utf8.encode('$key$_webSocketGuid')).bytes,
    );
    return Hijack((channel) {
      final socket = channel.sink as Socket;
      socket.add(
        utf8.encode(
          'HTTP/1.1 101 Switching Protocols\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Accept: $accept\r\n\r\n',
        ),
      );
      _accept(running, socket, version);
    });
  }

  static int _decodedLength(String base64Key) {
    try {
      return base64.decode(base64Key).length;
    } on FormatException {
      return -1;
    }
  }

  bool _originAllowed(String origin, String host) {
    final Uri uri;
    try {
      uri = Uri.parse(origin);
    } on FormatException {
      return false;
    }
    final originHost = uri.host.toLowerCase();
    if (originHost.isEmpty) return false;
    return originHost == host.toLowerCase() ||
        settings.allowedOrigins.any((h) => h.toLowerCase() == originHost);
  }

  int _nextConnectionId = 0;

  void _accept(_DwRunning running, Socket socket, String? version) {
    final webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: true);
    final connection = DwConnection(
      id: ++_nextConnectionId,
      socket: socket,
      webSocket: webSocket,
      protocol: protocol,
      log: logger,
      outboundLimitBytes: settings.outboundLimitBytes,
      closeGrace: settings.closeGrace,
    );
    if (version != '$dwWireVersion') {
      webSocket.listen(null, onDone: connection.markClosed, onError: (_) {});
      unawaited(
        connection.close(
          DwCloseCode.unsupportedVersion,
          '${DwCloseCode.wireVersionReason}$dwWireVersion',
        ),
      );
      return;
    }
    webSocket.pingInterval = settings.pingInterval;
    running.runtime.hub.add(connection);
    webSocket.listen(
      (data) => _onMessage(running, connection, data),
      onDone: () {
        connection.markClosed();
        running.runtime.hub.remove(connection);
      },
      onError: (Object error) =>
          logger.debug('connection ${connection.id}: $error'),
    );
  }

  void _onMessage(_DwRunning running, DwConnection connection, Object? data) {
    // Messages that arrive while stopping are dropped: the client resends
    // them after reconnecting, commands with their idempotency keys.
    if (connection.isClosing || _stopping) return;
    if (data is! String) {
      unawaited(connection.close(DwCloseCode.unsupportedData, 'dw.textOnly'));
      return;
    }
    if (data.length > settings.maxInboundMessageBytes) {
      unawaited(connection.close(DwCloseCode.messageTooBig, 'dw.tooBig'));
      return;
    }
    final Map<String, Object?> json;
    try {
      json = jsonDecode(data) as Map<String, Object?>;
    } catch (_) {
      _violation(connection, 'not a JSON object');
      return;
    }
    switch (json['k']) {
      case 'auth':
        final token = json['token'];
        if (token != null && token is! String) {
          _violation(connection, 'auth token is not a string');
          return;
        }
        connection.authGate = _authenticate(
          running,
          connection,
          connection.authGate,
          token as String?,
        );
      case 'req' || 'cmd':
        if (json['id'] is! int) {
          _violation(connection, 'call without an integer id');
          return;
        }
        unawaited(_call(running, connection, json));
      case final kind && ('sub' || 'unsub'):
        final name = json['ch'];
        if (name is! String) {
          _violation(connection, 'channel name is not a string');
          return;
        }
        _channelOperation(running, connection, kind == 'sub', name);
      default:
        _violation(connection, 'unknown message kind');
    }
  }

  void _violation(DwConnection connection, String what) {
    logger.warning('connection ${connection.id}: protocol violation: $what');
    unawaited(connection.close(DwCloseCode.protocolError, 'dw.protocol'));
  }

  Future<void> _authenticate(
    _DwRunning running,
    DwConnection connection,
    Future<void> previous,
    String? token,
  ) async {
    await previous;
    if (connection.isClosing) return;
    final hub = running.runtime.hub;
    if (token == null) {
      hub.authenticate(connection, null, null);
      connection.send(const DwAuthenticatedMessage());
      return;
    }
    try {
      final session = await running.authService.resolve(token);
      if (connection.isClosing) return;
      if (session == null || hub.wasRecentlyRevoked(session.keyId)) {
        hub.authenticate(connection, null, null);
        connection.send(const DwAuthenticatedMessage(rejected: true));
        return;
      }
      hub.authenticate(connection, session.accountId, session.keyId);
      connection.send(DwAuthenticatedMessage(accountId: session.accountId));
    } catch (error, stackTrace) {
      // Neither "anonymous" nor "rejected" would be true: the client must try
      // again, so the connection closes and the client reconnects.
      final incident = running.runtime.alerts.report(
        where: 'authenticate',
        error: error,
        stackTrace: stackTrace,
      );
      hub.authenticate(connection, null, null);
      await connection.close(DwCloseCode.internalError, 'dw.failed:$incident');
    }
  }

  Future<void> _call(
    _DwRunning running,
    DwConnection connection,
    Map<String, Object?> json,
  ) async {
    final gate = connection.authGate;
    if (!connection.admitCall(
      settings.maxConcurrentCalls,
      settings.maxWaitingCalls,
    )) {
      logger.warning(
        'connection ${connection.id}: more than ${settings.maxWaitingCalls} '
        'calls waiting; disconnecting',
      );
      await connection.close(DwCloseCode.tooManyCalls, 'dw.tooManyCalls');
      return;
    }
    try {
      await gate;
      await connection.callSlot(settings.maxConcurrentCalls);
      final id = json['id']! as int;
      final DwClientMessage message;
      try {
        message = DwClientMessage.fromJson(json, protocol);
      } catch (error, stackTrace) {
        final incident = running.runtime.alerts.report(
          where: 'decode ${json['k']}',
          error: error,
          stackTrace: stackTrace,
          accountId: connection.accountId,
        );
        connection.send(
          DwResultMessage(
            id: id,
            status: DwResultStatus.failed,
            incidentId: incident,
          ),
        );
        return;
      }
      final result = switch (message) {
        DwRequestMessage() => await running.dispatcher.runRequest(
          connection,
          message,
        ),
        DwCommandMessage() => await running.dispatcher.runCommand(
          connection,
          message,
        ),
        _ => throw StateError('unreachable: ${message.runtimeType}'),
      };
      connection.send(result);
    } finally {
      connection.callEnded();
    }
  }

  void _channelOperation(
    _DwRunning running,
    DwConnection connection,
    bool subscribe,
    String name,
  ) {
    final gate = connection.authGate;
    final tail = connection.channelTails[name] ?? Future<void>.value();
    late final Future<void> next;
    next = tail
        .then((_) => gate)
        .then(
          (_) => subscribe
              ? _subscribe(running, connection, name)
              : running.runtime.hub.unsubscribe(connection, name),
        )
        .whenComplete(() {
          if (identical(connection.channelTails[name], next)) {
            connection.channelTails.remove(name);
          }
        });
    connection.channelTails[name] = next;
  }

  Future<void> _subscribe(
    _DwRunning running,
    DwConnection connection,
    String name,
  ) async {
    if (connection.isClosing) return;
    final hub = running.runtime.hub;
    void refuse(DwRefusal refusal) =>
        connection.send(DwSubscriptionRefusedMessage.refused(name, refusal));
    void unauthenticated() =>
        connection.send(DwSubscriptionRefusedMessage.unauthenticated(name));

    final parsed = dwParseChannelName(name);
    final rule = running.channelRules[parsed.kind];
    if (rule == null) {
      return refuse(DwRefusal(DwCoreRefusal.unknownChannel));
    }
    if (connection.accountId == null) return unauthenticated();
    if (connection.subscriptions.contains(name)) {
      return connection.send(DwSubscribedMessage(name));
    }
    final DwChannel? channel = switch (rule) {
      DwKeyedChannelRule() =>
        parsed.key == null ? null : rule.channelFor(parsed.key!),
      DwSingleChannelRule() => parsed.key == null ? DwChannel(rule.kind) : null,
    };
    if (channel == null) {
      return refuse(DwRefusal(DwCoreRefusal.invalid, field: 'channel'));
    }
    final epoch = connection.authEpoch;
    final ctx = running.runtime.context(
      scope: 'subscribe $name',
      accountId: connection.accountId,
      keyId: connection.keyId,
      connection: connection,
    );
    final bool allowed;
    try {
      allowed = switch (rule) {
        DwKeyedChannelRule() => await rule.canSubscribe(ctx, channel),
        DwSingleChannelRule() => await rule.canSubscribe(ctx),
      };
    } catch (error, stackTrace) {
      final incident = running.runtime.alerts.report(
        where: 'subscribe ${parsed.kind}',
        error: error,
        stackTrace: stackTrace,
        accountId: connection.accountId,
      );
      return connection.send(
        DwSubscriptionRefusedMessage.failed(name, incident),
      );
    } finally {
      running.runtime.deliver(ctx);
    }
    if (connection.isClosing) return;
    // The session changed while the check ran: it was a check for someone
    // else.
    if (connection.authEpoch != epoch || connection.accountId == null) {
      return unauthenticated();
    }
    if (!allowed) return refuse(DwRefusal(DwCoreRefusal.forbidden));
    hub.subscribe(connection, name);
    connection.send(DwSubscribedMessage(name));
  }
}

/// The parts that exist while a server runs.
final class _DwRunning {
  _DwRunning({
    required this.database,
    required this.runtime,
    required this.dispatcher,
    required this.authService,
    required this.jobRunner,
    required this.channelRules,
  });

  final DwDatabase database;
  final DwRuntime runtime;
  final DwDispatcher dispatcher;
  final DwAuthService authService;
  final DwJobRunner jobRunner;
  final Map<String, DwChannelRule> channelRules;
  late final RelicApp app;
  late final RelicServer relic;
  List<StreamSubscription<ProcessSignal>> signals = const [];
}
