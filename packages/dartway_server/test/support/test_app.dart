import 'dart:async';
import 'dart:io';

import 'package:dartway_server/dartway_server.dart';
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

import 'dtos.dart';

export 'dtos.dart';

/// The Postgres server the suites run against: `DW_DATABASE_*` from the
/// environment. A missing variable fails the suite loudly.
DwDatabaseConfig adminConfig() {
  try {
    return DwDatabaseConfig.fromEnvironment(Platform.environment);
  } on ArgumentError catch (error) {
    throw StateError(
      'The dartway_server suites need a Postgres server: set DW_DATABASE_HOST, '
      '_PORT, _NAME (a maintenance database), _USER, _PASSWORD and _SSL. '
      '(${error.message})',
    );
  }
}

/// Alerts recorded for assertions.
final class RecordingAlerts implements DwAlerts {
  final List<DwIncident> incidents = [];
  final List<String?> notes = [];

  @override
  Future<void> send(DwIncident incident, {String? suppressedNote}) async {
    incidents.add(incident);
    notes.add(suppressedNote);
  }
}

/// Log lines recorded for assertions (and echoed when DW_TEST_LOG is set).
final class RecordingLogger implements DwLogger {
  RecordingLogger([this.scope]);

  final String? scope;
  static final List<String> lines = [];
  static final bool _echo = Platform.environment['DW_TEST_LOG'] != null;

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final line =
        '${level.name} ${scope ?? ''} $message${error == null ? '' : ': $error'}';
    lines.add(line);
    if (_echo) stderr.writeln(line);
  }

  @override
  DwLogger scoped(String scope) =>
      RecordingLogger(this.scope == null ? scope : '${this.scope} $scope');
}

final class _AppMigration extends DwMigration {
  const _AppMigration();

  @override
  String get id => '20260913_120000_test_app';

  @override
  String get checksum => 'test-app-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('''
    CREATE TABLE note (id bigserial PRIMARY KEY, text text NOT NULL, owner_id bigint);
    CREATE TABLE profile (
      account_id bigint PRIMARY KEY REFERENCES dw_account (id),
      name text NOT NULL,
      identifier text NOT NULL
    );
    CREATE TABLE counter (label text PRIMARY KEY, n integer NOT NULL);
    CREATE TABLE job_log (id bigserial PRIMARY KEY, name text NOT NULL, tag text, at timestamptz NOT NULL DEFAULT now());
  ''');

  @override
  Future<void> down(DwMigrationContext m) =>
      m.sql('DROP TABLE job_log, counter, profile, note');
}

/// The test application: its handlers, channels and hooks, with everything a
/// test wants to observe recorded.
final class TestApp {
  TestApp();

  final RecordingAlerts alerts = RecordingAlerts();
  final RecordingLogger logger = RecordingLogger();

  /// identifier → last delivered code.
  final Map<String, String> delivered = {};
  final List<String> deliveredTo = [];

  /// Identifiers whose delivery throws.
  final Set<String> failingDelivery = {};
  final List<int> createdAccounts = [];

  /// Accounts that pass `SecretNotes`' access check.
  final Set<int> secretReaders = {};

  /// Labels of `Count(mode: failOnce)` that have failed already.
  final Set<String> failedOnce = {};

  /// Job name → how many times it should still fail.
  final Map<String, int> jobFailures = {};
  final List<String> jobRuns = [];
  final StreamController<String> jobEvents = StreamController.broadcast();

  static const reviewer = 'reviewer@example.com';

  DwAuth auth({
    Duration resendDelay = const Duration(seconds: 30),
    int maxRequestsPerWindow = 3,
    int maxAttempts = 3,
  }) => DwAuth(
    normalize: (kind, raw) {
      final value = raw.trim().toLowerCase();
      return switch (kind) {
        DwIdentifierKind.email => value.contains('@') ? value : null,
        DwIdentifierKind.phone =>
          RegExp(r'^\+\d{6,15}$').hasMatch(value) ? value : null,
      };
    },
    deliverCode: (ctx, kind, identifier, code) async {
      if (failingDelivery.contains(identifier)) {
        throw StateError('delivery provider is down');
      }
      delivered[identifier] = code;
      deliveredTo.add(identifier);
    },
    fixedCode: (ctx, kind, identifier, accountId) async =>
        identifier == reviewer ? '000000' : null,
    onAccountCreated: (ctx, accountId, kind, identifier, registration) async {
      createdAccounts.add(accountId);
      await ctx.db.execute(
        'INSERT INTO profile (account_id, name, identifier) '
        'VALUES (@account, @name, @identifier)',
        params: {
          'account': accountId,
          'name': registration['name'] ?? '',
          'identifier': identifier,
        },
      );
    },
    maxAttempts: maxAttempts,
    maxRequestsPerWindow: maxRequestsPerWindow,
    requestWindow: const Duration(minutes: 10),
    resendDelay: resendDelay,
  );

  static Future<NoteView> _insertNote(DwDb db, String text, int? owner) async {
    final row = (await db.query(
      'INSERT INTO note (text, owner_id) VALUES (@text, @owner::int8) '
      'RETURNING id',
      params: {'text': text, 'owner': owner},
    )).single;
    return NoteView(id: row.get<int>('id'), text: text, ownerId: owner);
  }

  static NoteView _note(DwRow row) => NoteView(
    id: row.get<int>('id'),
    text: row.get<String>('text'),
    ownerId: row['owner_id'] as int?,
  );

  Future<int> _count(DwDb db, String label) async => (await db.query(
    'INSERT INTO counter (label, n) VALUES (@label, 1) '
    'ON CONFLICT (label) DO UPDATE SET n = counter.n + 1 RETURNING n',
    params: {'label': label},
  )).single.get<int>('n');

  List<DwHandler> handlers() => [
    DwHandler.request<ListNotes, List<NoteView>>(
      access: DwAccess.anonymous,
      handle: (ctx, request) async => [
        for (final row in await ctx.db.query(
          'SELECT * FROM note WHERE @owner::int8 IS NULL OR owner_id = @owner '
          'ORDER BY id',
          params: {'owner': request.ownerId},
        ))
          _note(row),
      ],
    ),
    DwHandler.request<LiveNotes, List<NoteView>>(
      access: DwAccess.signedIn,
      handle: (ctx, request) async => [
        for (final row in await ctx.db.query('SELECT * FROM note ORDER BY id'))
          _note(row),
      ],
    ),
    DwHandler.request<MyNotes, List<NoteView>>(
      access: DwAccess.signedIn,
      handle: (ctx, request) async => [
        for (final row in await ctx.db.query(
          'SELECT * FROM note WHERE owner_id = @owner ORDER BY id',
          params: {'owner': ctx.requireAccountId},
        ))
          _note(row),
      ],
    ),
    DwHandler.request<SecretNotes, List<NoteView>>(
      access: DwAccess.check(
        (ctx) async => secretReaders.contains(ctx.accountId),
      ),
      handle: (ctx, request) async => const [],
    ),
    DwHandler.request<GetNote, NoteView>(
      access: DwAccess.anonymous,
      handle: (ctx, request) async {
        final rows = await ctx.db.query(
          'SELECT * FROM note WHERE id = @id',
          params: {'id': request.noteId},
        );
        return rows.isEmpty
            ? ctx.refuse(DwCoreRefusal.notFound)
            : _note(rows.single);
      },
    ),
    DwHandler.request<FindNote, NoteView?>(
      access: DwAccess.anonymous,
      handle: (ctx, request) async {
        final rows = await ctx.db.query(
          'SELECT * FROM note WHERE id = @id',
          params: {'id': request.noteId},
        );
        return rows.isEmpty ? null : _note(rows.single);
      },
    ),
    DwHandler.page<FeedNotes, NoteView>(
      access: DwAccess.anonymous,
      handle: (ctx, request, page) async => [
        for (final row in await ctx.db.query(
          'SELECT * FROM note WHERE text LIKE @prefix ORDER BY id '
          'LIMIT @limit OFFSET @offset',
          params: {
            'prefix': '${request.prefix}%',
            'limit': page.fetchLimit,
            'offset': page.offset,
          },
        ))
          _note(row),
      ],
    ),
    DwHandler.page<NoteHistory, NoteView>(
      access: DwAccess.anonymous,
      handle: (ctx, request, page) async => [
        for (final row in await ctx.db.query(
          'SELECT * FROM note WHERE text LIKE @prefix '
          'AND (@before::int8 IS NULL OR id < @before) '
          'ORDER BY id DESC LIMIT @limit',
          params: {
            'prefix': '${request.prefix}%',
            'before': page.before,
            'limit': page.fetchLimit,
          },
        ))
          _note(row),
      ],
    ),
    DwHandler.request<ExplodingRequest, List<NoteView>>(
      access: DwAccess.anonymous,
      handle: (ctx, request) async =>
          throw StateError('database password is ${request.secret}'),
    ),
    DwHandler.request<SlowRequest, List<NoteView>>(
      access: DwAccess.anonymous,
      handle: (ctx, request) async {
        await Future<void>.delayed(Duration(milliseconds: request.millis));
        return const [];
      },
    ),
    DwHandler.command<CreateNote, NoteView>(
      access: DwAccess.signedIn,
      handle: (ctx, command) async {
        final note = await _insertNote(
          ctx.db,
          command.text,
          ctx.requireAccountId,
        );
        ctx.publish(const DwChannel(TestChannel.notes), note);
        for (var i = 0; i < command.extraPublishes; i++) {
          ctx.publish(
            const DwChannel(TestChannel.notes),
            NoteView(
              id: note.id,
              text: '${note.text} #$i',
              ownerId: note.ownerId,
            ),
          );
        }
        ctx.publish(DwChannel(TestChannel.account, ctx.requireAccountId), note);
        return note;
      },
    ),
    DwHandler.command<PublishAndEnd, void>(
      access: DwAccess.signedIn,
      handle: (ctx, command) async {
        switch (command.ending) {
          case 'refuse':
            final note = await _insertNote(ctx.db, 'refused', null);
            ctx.publish(const DwChannel(TestChannel.notes), note);
            ctx.refuse(DwCoreRefusal.conflict);
          case 'fail':
            final note = await _insertNote(ctx.db, 'failed', null);
            ctx.publish(const DwChannel(TestChannel.notes), note);
            throw StateError('after publish');
          default:
            throw ArgumentError(command.ending);
        }
      },
    ),
    DwHandler.command<Count, int>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async {
        final n = await _count(ctx.db, command.label);
        switch (command.mode) {
          case 'refuse':
            ctx.refuse(DwCoreRefusal.conflict, params: {'n': n});
          case 'failOnce' when failedOnce.add(command.label):
            throw StateError('first execution fails');
          case 'conflictOnce' when failedOnce.add(command.label):
            throw DwSerializationFailure('could not serialize access');
        }
        return n;
      },
    ),
    DwHandler.command<CountOutside, int>(
      access: DwAccess.anonymous,
      transactional: false,
      handle: (ctx, command) async {
        if (ctx.db.inTransaction) throw StateError('expected no transaction');
        final n = await ctx.transaction((tx) => _count(tx, command.label));
        final note = await ctx.transaction(
          (tx) => _insertNote(tx, 'outside ${command.label}', null),
        );
        ctx.publish(const DwChannel(TestChannel.notes), note);
        if (command.label.startsWith('fail')) {
          throw StateError('after a committed transaction');
        }
        return n;
      },
    ),
    DwHandler.command<Ping, String>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async => 'pong',
    ),
    DwHandler.command<NeedsAccount, int>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async => ctx.requireAccountId,
    ),
    DwHandler.command<RevokeNotes, void>(
      access: DwAccess.signedIn,
      handle: (ctx, command) async {
        ctx.revoke(const DwChannel(TestChannel.notes), command.accountId);
        final note = await _insertNote(ctx.db, 'after revoke', null);
        ctx.publish(const DwChannel(TestChannel.notes), note);
      },
    ),
    DwHandler.command<RevokeSessions, void>(
      access: DwAccess.signedIn,
      handle: (ctx, command) async {
        await ctx.accounts.revokeKeys(command.accountId);
        if (command.ending == 'refuse') ctx.refuse(DwCoreRefusal.conflict);
      },
    ),
    DwHandler.command<EnsureAccount, int>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async => (await ctx.accounts.ensure(
        DwIdentifierKind.email,
        command.email,
      )).accountId,
    ),
    DwHandler.command<EnqueueJob, bool>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async {
        final enqueued = await ctx.jobs.enqueue(
          command.name,
          {'tag': command.tag},
          key: command.key,
          runAt: command.delayMillis == null
              ? null
              : DateTime.now().add(
                  Duration(milliseconds: command.delayMillis!),
                ),
        );
        if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
        return enqueued;
      },
    ),
    DwHandler.command<Burst, void>(
      access: DwAccess.anonymous,
      handle: (ctx, command) async {
        for (var i = 0; i < command.count; i++) {
          ctx.publish(
            const DwChannel(TestChannel.public),
            NoteView(id: i, text: 'x' * command.size),
          );
        }
      },
    ),
  ];

  List<DwChannelRule> channels() => [
    DwChannelRule.single(TestChannel.notes, canSubscribe: (ctx) async => true),
    DwChannelRule.single(TestChannel.public, canSubscribe: (ctx) async => true),
    DwChannelRule.keyed<int>(
      TestChannel.account,
      parseKey: int.parse,
      canSubscribe: (ctx, accountId) async => ctx.accountId == accountId,
    ),
    DwChannelRule.single(
      TestChannel.broken,
      canSubscribe: (ctx) async => throw StateError('rule is broken'),
    ),
    DwChannelRule.single(
      TestChannel.nobody,
      canSubscribe: (ctx) async => false,
    ),
  ];

  Future<void> _logJob(DwContext ctx, String name, Object? tag) async {
    await ctx.db.execute(
      'INSERT INTO job_log (name, tag) VALUES (@name, @tag::text)',
      params: {'name': name, 'tag': tag},
    );
  }

  List<DwJobDefinition> jobs({bool withTick = false}) => [
    DwJobDefinition(
      'record',
      handle: (ctx, payload) async {
        await _logJob(ctx, 'record', payload['tag']);
        jobRuns.add('record:${payload['tag']}');
        jobEvents.add('record:${payload['tag']}');
      },
    ),
    DwJobDefinition(
      'flaky',
      maxAttempts: 3,
      backoff: (attempt) => const Duration(milliseconds: 50),
      handle: (ctx, payload) async {
        await _logJob(ctx, 'flaky-attempt', payload['tag']);
        final left = jobFailures['flaky:${payload['tag']}'] ?? 0;
        if (left > 0) {
          jobFailures['flaky:${payload['tag']}'] = left - 1;
          throw StateError('flaky failure, $left left');
        }
        jobEvents.add('flaky:${payload['tag']}');
      },
    ),
    DwJobDefinition(
      'outside',
      transactional: false,
      maxAttempts: 2,
      backoff: (attempt) => const Duration(milliseconds: 50),
      handle: (ctx, payload) async {
        if (ctx.db.inTransaction) throw StateError('expected no transaction');
        final left = jobFailures['outside:${payload['tag']}'] ?? 0;
        if (left > 0) {
          jobFailures['outside:${payload['tag']}'] = left - 1;
          throw StateError('outside failure');
        }
        await _logJob(ctx, 'outside', payload['tag']);
        jobEvents.add('outside:${payload['tag']}');
      },
    ),
    if (withTick)
      DwRecurringJob(
        'tick',
        every: const Duration(milliseconds: 300),
        handle: (ctx) async {
          await _logJob(ctx, 'tick', null);
          jobEvents.add('tick');
        },
      ),
  ];

  DwServer server(
    DwDatabaseConfig database, {
    DwAuth? auth,
    DwServerSettings settings = const DwServerSettings(
      jobPollInterval: Duration(seconds: 30),
    ),
    List<DwHandler>? handlers,
    List<DwChannelRule>? channels,
    List<DwJobDefinition>? jobs,
    List<DwRoute> routes = const [],
    List<DwMigration>? migrations,
    DwProtocol? protocol,
    DwSchema? schema,
  }) => DwServer(
    protocol: protocol ?? testProtocol,
    schema: schema,
    migrations: migrations ?? const [_AppMigration()],
    database: database,
    auth: auth ?? this.auth(),
    handlers: handlers ?? this.handlers(),
    channels: channels ?? this.channels(),
    jobs: jobs ?? this.jobs(),
    routes: routes,
    alerts: alerts,
    logger: logger,
    settings: settings,
  );

  /// Signs [identifier] in through the wire and returns the session.
  Future<DwSession> signIn(
    DwTestConnection connection,
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
    Map<String, String> registration = const {},
  }) async {
    final ticketResult = await connection.command(
      DwRequestCode(kind: kind, identifier: identifier),
    );
    final ticket = ticketResult.okCommandValue(
      DwRequestCode(kind: kind, identifier: identifier),
      testProtocol,
    );
    final normalized = identifier.trim().toLowerCase();
    final code = normalized == reviewer ? '000000' : delivered[normalized]!;
    final verify = DwVerifyCode(
      ticketId: ticket.id,
      code: code,
      registration: registration,
    );
    return (await connection.command(
      verify,
    )).okCommandValue(verify, testProtocol);
  }
}

/// A database and a started server for one test file; torn down after it.
final class Harness {
  Harness._(this.app, this.database, this.server);

  final TestApp app;
  final DwTestDatabase database;
  DwTestServer server;

  static Future<Harness> start({
    TestApp? app,
    DwServer Function(TestApp app, DwDatabaseConfig config)? build,
  }) async {
    final testApp = app ?? TestApp();
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    try {
      final server = await DwTestServer.start(
        build?.call(testApp, database.config) ??
            testApp.server(database.config),
      );
      return Harness._(testApp, database, server);
    } catch (_) {
      await database.drop();
      rethrow;
    }
  }

  DwDb get db => server.db;

  Future<DwTestConnection> connect() => server.connect();

  /// A connection signed in as [identifier].
  Future<(DwTestConnection, DwSession)> signedIn(String identifier) async {
    final connection = await connect();
    final session = await app.signIn(connection, identifier);
    final authed = await connection.authenticate(session.token);
    expect(authed.accountId, session.id);
    return (connection, session);
  }

  Future<void> stop() async {
    await server.stop();
    await database.drop();
  }
}

/// Registers a harness for the enclosing test file.
Harness Function() useHarness({
  DwServer Function(TestApp app, DwDatabaseConfig config)? build,
}) {
  Harness? harness;
  setUpAll(() async => harness = await Harness.start(build: build));
  tearDownAll(() async => harness?.stop());
  return () => harness!;
}

/// Polls [condition] until it holds or [timeout] passes.
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'condition not met within $timeout${reason == null ? '' : ': $reason'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
