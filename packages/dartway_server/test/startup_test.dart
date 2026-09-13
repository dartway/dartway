import 'dart:io';

import 'package:dartway_server/dartway_server.dart';
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

final class _FailingMigration extends DwMigration {
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
    Future<List<String>> problems(DwServer server) async {
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
          handlers: [
            ...app.handlers().where((h) => h.type != NoteHistory),
            DwHandler.request<ListNotes, List<NoteView>>(
              access: DwAccess.anonymous,
              handle: (ctx, request) async => const [],
            ),
            DwHandler.request<UnregisteredRequest, List<NoteView>>(
              access: DwAccess.anonymous,
              handle: (ctx, request) async => const [],
            ),
            DwHandler.request<NoteHistory, DwPage<NoteView>>(
              access: DwAccess.anonymous,
              handle: (ctx, request) async => const DwPage([], hasMore: false),
            ),
            DwHandler.command<DwSignOut, void>(
              access: DwAccess.signedIn,
              handle: (ctx, command) async {},
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
            DwJobDefinition('dw.mine', handle: (ctx, payload) async {}),
            DwJobDefinition('twin', handle: (ctx, payload) async {}),
            DwJobDefinition('twin', handle: (ctx, payload) async {}),
            DwRecurringJob(
              'never',
              every: Duration.zero,
              handle: (ctx) async {},
            ),
          ],
          routes: [
            DwRoute.get('/dw', (ctx, request) => Response.ok()),
            DwRoute.post('/hook', (ctx, request) => Response.ok()),
            DwRoute.post('/hook', (ctx, request) => Response.ok()),
          ],
        ),
      );
      expect(found, [
        'ListNotes has more than one handler',
        'a handler is registered for UnregisteredRequest, which the protocol '
            'does not know',
        'NoteHistory is paginated: register it with DwHandler.page',
        'DwSignOut has a built-in handler and cannot have another',
        'channel kind "notes" has more than one rule',
        'job "dw.mine": names starting with "dw." are the framework\'s',
        'job "twin" is declared more than once',
        'recurring job "never" needs a positive interval',
        'route GET /dw is reserved by the framework',
        'route POST /hook is declared twice',
      ]);
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
        'dw/20260913_000000_dw_initial',
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

    test('the framework migration rolls back and applies again', () async {
      final opened = await DwDatabase.open(database.config);
      try {
        final migrator = DwMigrator(
          opened.db,
          migrations: {'dw': DwServer.frameworkMigrations},
        );
        await migrator.apply();
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
        ]);
        await migrator.rollback(batch: 1);
        expect(await tables(), isEmpty);
        await migrator.apply();
        expect(await tables(), hasLength(7));
      } finally {
        await opened.close();
      }
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
        // The framework migration committed before the app one failed.
        final opened = await DwDatabase.open(database.config);
        final ledger = await opened.db.query(
          'SELECT namespace FROM dw_migrations',
        );
        expect(ledger.map((r) => r['namespace']), ['dw']);
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
}
