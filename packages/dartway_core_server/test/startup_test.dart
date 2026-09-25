import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

final class _FailingMigration extends DwDatabaseMigration {
  const _FailingMigration();

  @override
  String get id => '20260913_130000_broken';

  @override
  String get checksum => 'broken';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('CREATE TABLE ( oops');
}

void main() {
  final app = TestApp();
  const unused = DwDatabaseConfig(
    host: '127.0.0.1',
    port: 1,
    name: 'never_opened',
    user: 'nobody',
    password: '',
    ssl: false,
  );

  group('validation happens before anything is opened', () {
    Future<List<String>> problems(DwAppServer server) async {
      try {
        await DwTestServer.start(server);
      } on DwStartupException catch (error) {
        return error.problems;
      }
      fail('the server started');
    }

    test('every problem is reported at once', () async {
      final found = await problems(
        app.server(
          unused,
          protocol: DwWireProtocol([
            DwProtocolEntry<OrphanRequest>(
              'OrphanRequest',
              OrphanRequest.fromJson,
            ),
            DwProtocolEntry<OrphanCommand>(
              'OrphanCommand',
              OrphanCommand.fromJson,
            ),
          ], include: testProtocol),
          handlers: [
            ...app.handlers(),
            DwCallHandler.list<ListNotes, NoteView>(
              access: DwAccessRule.anonymous,
              handle: (ctx, request) async => const [],
            ),
            DwCallHandler.list<UnregisteredRequest, NoteView>(
              access: DwAccessRule.anonymous,
              handle: (ctx, request) async => const [],
            ),
            DwCallHandler.command<DwSignOut, void>(
              access: DwAccessRule.signedIn,
              handle: (ctx, command) async {},
            ),
            DwCallHandler.list<ListNotes, NoteView>(
              access: DwAccessRule.check<NotesOfOwner>(
                (ctx, request) async => true,
              ),
              handle: (ctx, request) async => const [],
            ),
            DwCallHandler.list<ListNotes, NoteView>(
              access: DwAccessRule.resource<GetMyNote, NoteView>(
                load: (ctx, request) async => null,
                allows: (ctx, request, note) => true,
              ),
              handle: (ctx, request) async => const [],
            ),
          ],
          channels: [
            ...app.channels(),
            DwChannelRule.single(
              TestChannel.notes,
              canSubscribe: (ctx) async => true,
            ),
          ],
          jobs: [
            DwQueuedJob(DwJobKind.withoutPayload('dw.mine'), handle: (ctx, _) async {}),
            DwQueuedJob(DwJobKind.withoutPayload('twin'), handle: (ctx, _) async {}),
            DwQueuedJob(DwJobKind.withoutPayload('twin'), handle: (ctx, _) async {}),
            DwRecurringJob(
              'never',
              every: Duration.zero,
              handle: (ctx) async {},
            ),
          ],
          routes: [
            for (final path in ['/dw', '/dw/live', '/dw/ListNotes', '/health'])
              DwHttpRoute.get(path, (ctx, request) => DwHttpResponse.empty()),
            DwHttpRoute.post('hook', (ctx, request) => DwHttpResponse.empty()),
            DwHttpRoute.post('/hook', (ctx, request) => DwHttpResponse.empty()),
            DwHttpRoute.post('/hook', (ctx, request) => DwHttpResponse.empty()),
            DwHttpRoute.any('/hook', (ctx, request) => DwHttpResponse.empty()),
          ],
          settings: const DwServerSettings(
            allowedOrigins: {
              'https://app.example.com',
              'http://localhost:5000',
              'app.example.com',
              'https://app.example.com/',
              'ftp://files.example.com',
            },
          ),
        ),
      );
      expect(found, [
        'ListNotes has more than one handler',
        'the list(UnregisteredRequest) handler answers UnregisteredRequest, '
            'which the protocol does not register',
        'DwSignOut has a built-in handler and cannot have another',
        'ListNotes has more than one handler',
        'the access check of the list(ListNotes) handler is written for '
            'NotesOfOwner',
        'ListNotes has more than one handler',
        'the access check of the list(ListNotes) handler is written for '
            'GetMyNote',
        'OrphanRequest is a registered request without a handler',
        'OrphanCommand is a registered command without a handler',
        'channel kind "notes" has more than one rule',
        'job "dw.mine": names starting with "dw." are the framework\'s',
        'job "twin" is declared more than once',
        'recurring job "never" needs a positive interval',
        for (final origin in [
          'app.example.com',
          'https://app.example.com/',
          'ftp://files.example.com',
        ])
          'allowed origin "$origin" is not a full origin: scheme, host and an '
              'optional port, as a browser sends it (https://app.example.com, '
              'http://localhost:5000)',
        'route GET /dw is reserved by the framework',
        'route GET /dw/live is reserved by the framework',
        'route GET /dw/ListNotes is reserved by the framework',
        'route GET /health is reserved by the framework',
        'route POST hook: a path starts with "/"',
        'route POST /hook is declared twice',
      ]);
    });

    test('a window handler whose position cannot be a cursor fails where it '
        'is declared', () {
      expect(
        () => DwCallHandler.window<_DoubleSortWindow, MessageView, double, int>(
          access: DwAccessRule.anonymous,
          handle: (ctx, request, window) async => const [],
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            DwCallHandler.window<
              _ObjectIdWindow,
              MessageView,
              DateTime,
              Object
            >(
              access: DwAccessRule.anonymous,
              handle: (ctx, request, window) async => const [],
            ),
        throwsArgumentError,
      );
      expect(
        () => DwCallHandler.list<ListNotes, NoteView>(
          access: DwAccessRule.anonymous,
          maxBodyBytes: 0,
          handle: (ctx, request) async => const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('migrations', () {
    late DwTestDatabase database;
    setUp(() async {
      database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'server_test',
      );
    });
    tearDown(() => database.drop());

    test('the framework namespace is applied before the app, once', () async {
      final server = await DwTestServer.start(app.server(database.config));
      final ledger = await server.db.query(
        'SELECT namespace, id, batch FROM dw_migrations ORDER BY seq',
      );
      expect(ledger.map((r) => '${r['namespace']}/${r['id']}'), [
        // Every framework migration first, whatever the ids: the app's is
        // older than three of them and follows all of them (D-060).
        'dw/20260913_000000_dw_initial',
        'dw/20260914_000000_dw_stored_file',
        'dw/20260914_180000_dw_stored_file_bucket',
        'dw/20260914_220000_dw_keys_and_identities',
        'app/20260913_120000_test_app',
      ]);
      await server.stop();

      final again = await DwTestServer.start(app.server(database.config));
      final batches = await again.db.query(
        'SELECT DISTINCT batch FROM dw_migrations',
      );
      expect(batches, hasLength(1), reason: 'nothing pending on restart');
      await again.stop();
    });

    test('migrate applies what a start would, and serves nothing', () async {
      final server = app.server(database.config);
      await server.migrate();
      final opened = await DwPostgresDatabase.open(database.config);
      try {
        final ledger = await opened.db.query(
          "SELECT id FROM dw_migrations WHERE namespace = 'app'",
        );
        expect(ledger.map((r) => r['id']), ['20260913_120000_test_app']);
        // Nothing stayed open: no listener, no job connection.
        final others = await opened.db.query(
          'SELECT count(*)::int AS n FROM pg_stat_activity '
          'WHERE datname = current_database() AND pid <> pg_backend_pid()',
        );
        expect(others.single['n'], 0);
      } finally {
        await opened.close();
      }
      expect(
        () => server.stop(),
        returnsNormally,
        reason: 'a migrate-only server was never running',
      );
    });

    test('the framework migration rolls back and applies again', () async {
      final opened = await DwPostgresDatabase.open(database.config);
      try {
        final runner = DwMigrationRunner(
          opened.db,
          migrations: {'dw': DwAppServer.frameworkMigrations},
        );
        await runner.apply();
        Future<List<String>> tables() async => [
          for (final row in await opened.db.query(
            "SELECT tablename FROM pg_tables WHERE tablename LIKE 'dw\\_%' "
            "AND tablename <> 'dw_migrations' ORDER BY tablename",
          ))
            row['tablename']! as String,
        ];
        expect(await tables(), [
          'dw_account',
          'dw_auth_key',
          'dw_code_ticket',
          'dw_command_outcome',
          'dw_identity',
          'dw_job',
          'dw_recurring_job',
          'dw_stored_file',
        ]);
        await runner.rollback(batch: 1);
        expect(await tables(), isEmpty);
        await runner.apply();
        expect(await tables(), hasLength(8));
      } finally {
        await opened.close();
      }
    });

    test('a declared schema must exist after migrating: missing tables and '
        'columns stop the start, everything else is not the server\'s '
        'business', () async {
      DwDatabaseSchema schema(List<DwTableSchema> tables) =>
          DwDatabaseSchema.fromTables(tables);
      final note = DwTableSchema(
        'note',
        columns: [
          DwColumnSchema.primaryKey(),
          // Declared as a varchar: a type difference does not fail the start.
          DwColumnSchema('text', 'character varying'),
          DwColumnSchema('owner_id', 'bigint', nullable: true),
        ],
      );

      final missing = app.server(
        database.config,
        schema: schema([
          note,
          DwTableSchema(
            'profile',
            columns: [
              DwColumnSchema('account_id', 'bigint'),
              DwColumnSchema('name', 'text'),
              DwColumnSchema('avatar_url', 'text', nullable: true),
            ],
          ),
          DwTableSchema('invoice', columns: [DwColumnSchema.primaryKey()]),
        ]),
      );
      await expectLater(
        DwTestServer.start(missing),
        throwsA(
          isA<DwStartupException>().having((e) => e.problems, 'problems', [
            'table "invoice" is declared in the schema and missing from the '
                'database: is its migration registered?',
            'column "profile.avatar_url" is declared in the schema and '
                'missing from the database: is its migration registered?',
          ]),
        ),
      );
      expect(() => missing.boundPort, throwsStateError);

      final present = await DwTestServer.start(
        app.server(database.config, schema: schema([note])),
      );
      await present.stop();
    });

    test(
      'a failing migration stops the start and leaves nothing listening',
      () async {
        final server = app.server(
          database.config,
          migrations: const [_FailingMigration()],
        );
        await expectLater(
          DwTestServer.start(server),
          throwsA(isA<Exception>()),
        );
        expect(() => server.boundPort, throwsStateError);
        final opened = await DwPostgresDatabase.open(database.config);
        final ledger = await opened.db.query(
          'SELECT namespace FROM dw_migrations',
        );
        // The framework's migrations, all applied before the app's failed;
        // nothing of the app's is recorded.
        expect(ledger.map((r) => r['namespace']).toSet(), {'dw'});
        expect(ledger, hasLength(DwAppServer.frameworkMigrations.length));
        await opened.close();
      },
    );
  });

  test('an unreachable database fails the start', () async {
    final server = app.server(unused);
    await expectLater(
      DwTestServer.start(server),
      throwsA(anyOf(isA<DwDatabaseException>(), isA<SocketException>())),
    );
  });

  test(
    'a port already taken fails the start and releases the database',
    () async {
      final database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'server_test',
      );
      addTearDown(database.drop);
      final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(taken.close);
      final server = app.server(database.config);
      await expectLater(
        server.startOn(
          port: taken.port,
          address: InternetAddress.loopbackIPv4,
          handleSignals: false,
        ),
        throwsA(isA<SocketException>()),
      );
      expect(() => server.boundPort, throwsStateError);
    },
  );
}

/// A window whose sort value no cursor can carry.
final class _DoubleSortWindow
    extends DwWindowRequest<MessageView, double, int> {
  const _DoubleSortWindow() : super(pageSize: 2);

  @override
  DwWindowPosition<double, int> positionOf(MessageView item) =>
      (sortValue: 1.0, id: item.id);

  @override
  String get dwTypeName => '_DoubleSortWindow';

  @override
  Map<String, Object?> toJson() => const {};
}

/// A window whose id type is not an int or a String.
final class _ObjectIdWindow
    extends DwWindowRequest<MessageView, DateTime, Object> {
  const _ObjectIdWindow() : super(pageSize: 2);

  @override
  DwWindowPosition<DateTime, Object> positionOf(MessageView item) =>
      (sortValue: item.sentAt, id: item.id);

  @override
  String get dwTypeName => '_ObjectIdWindow';

  @override
  Map<String, Object?> toJson() => const {};
}
