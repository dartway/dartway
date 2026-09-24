import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestDatabase, DwTestServer;
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'support/push_harness.dart';

void main() {
  DwAppServer server(
    DwDatabaseConfig database, {
    DwWireProtocol? protocol,
    List<DwServerModule> modules = const [],
    List<DwCallHandler> handlers = const [],
    List<DwJobDefinition> jobs = const [],
  }) => DwAppServer(
    protocol: protocol ?? testProtocol,
    migrations: const [],
    database: database,
    auth: DwAuthConfig(
      normalize: (kind, raw) => raw,
      deliverCode: (ctx, kind, identifier, code, accountId) async {},
    ),
    handlers: handlers,
    jobs: jobs,
    modules: modules,
    logger: RecordingLogger([]),
  );

  /// What the server refuses to start over — checked before it opens its
  /// database.
  Future<List<String>> problemsOf(DwAppServer app) async {
    try {
      await DwTestServer.start(app);
    } on DwStartupException catch (error) {
      return error.problems;
    }
    fail('the server started');
  }

  const unreachable = DwDatabaseConfig(
    host: '127.0.0.1',
    port: 1,
    name: 'none',
    user: 'none',
    password: 'none',
  );

  test(
    'a protocol without the push calls refuses to start, naming the fix',
    () async {
      final noPush = DwWireProtocol([
        const DwProtocolEntry<QueueAlert>('QueueAlert', QueueAlert.fromJson),
        const DwProtocolEntry<NewsAlert>('NewsAlert', NewsAlert.fromJson),
      ], include: DwWireProtocol.core);
      final problems = await problemsOf(
        server(
          unreachable,
          protocol: noPush,
          modules: [DwPushModule(providers: const [])],
          handlers: [queueAlertHandler],
        ),
      );
      expect(
        problems,
        contains(contains('DwWireProtocol(dwPushProtocolEntries, include:')),
      );
      expect(
        problems,
        contains(contains('answers DwRegisterPushToken, which the protocol')),
      );
    },
  );

  test(
    'a project cannot answer a push call itself, nor use a module job name',
    () async {
      final problems = await problemsOf(
        server(
          unreachable,
          modules: [DwPushModule(providers: const [])],
          handlers: [
            queueAlertHandler,
            DwCallHandler.command<DwUnregisterPushToken, void>(
              access: DwAccessRule.signedIn,
              handle: (ctx, command) async {},
            ),
          ],
          jobs: [
            DwRecurringJob(
              'dw.push.cleanup',
              every: const Duration(hours: 1),
              handle: (ctx) async {},
            ),
          ],
        ),
      );
      expect(
        problems,
        contains(
          'DwUnregisterPushToken has a built-in handler and cannot have another',
        ),
      );
      expect(
        problems,
        contains(contains('"dw.push.cleanup": names starting with "dw."')),
      );
    },
  );

  test('settings that cannot work refuse to start', () async {
    final problems = await problemsOf(
      server(
        unreachable,
        modules: [
          DwPushModule(
            providers: const [],
            settings: const DwPushSettings(batchSize: 0, maxAttempts: 0),
          ),
        ],
        handlers: [queueAlertHandler],
      ),
    );
    expect(
      problems,
      containsAll([
        'push batchSize must be positive',
        'push maxAttempts must be at least 1',
      ]),
    );
  });

  test('ctx.push without the module says what is missing', () async {
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'push_test',
    );
    addTearDown(database.drop);
    final started = await DwTestServer.start(
      server(
        database.config,
        protocol: DwWireProtocol([
          const DwProtocolEntry<QueueAlert>('QueueAlert', QueueAlert.fromJson),
          const DwProtocolEntry<NewsAlert>('NewsAlert', NewsAlert.fromJson),
        ], include: DwWireProtocol.core),
        handlers: [queueAlertHandler],
      ),
    );
    addTearDown(started.stop);
    final caller = started.caller();
    addTearDown(caller.close);
    final answer = await caller.call(const QueueAlert(recipients: [1]));
    expect(answer.status, 500);
    // No push tables either: the module brings them.
    expect(
      await started.db.query(
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'dw_push_device'",
      ),
      isEmpty,
    );
  });

  test('push migrations apply under their namespace and roll back', () async {
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'push_test',
    );
    addTearDown(database.drop);
    final opened = await DwPostgresDatabase.open(database.config);
    addTearDown(opened.close);
    final migrations = {
      'dw': DwAppServer.frameworkMigrations,
      dwPushNamespace: dwPushMigrations,
    };
    await DwMigrationRunner(opened.db, migrations: migrations).apply();
    final ledger = await opened.db.query(
      "SELECT id FROM dw_migrations WHERE namespace = 'push'",
    );
    expect(
      [for (final row in ledger) row['id']],
      ['20260915_000000_push_initial'],
    );
    await DwMigrationRunner(
      opened.db,
      migrations: {dwPushNamespace: dwPushMigrations},
    ).rollback(
      id: const DwMigrationRef(dwPushNamespace, '20260915_000000_push_initial'),
    );
    expect(
      await opened.db.query(
        "SELECT 1 FROM information_schema.tables WHERE table_name LIKE 'dw_push_%'",
      ),
      isEmpty,
    );
  });
}
