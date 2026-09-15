import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestDatabase, DwTestServer;
import 'package:test/test.dart';

import 'support/test_app.dart' show RecordingLogger, adminConfig, eventually;

/// A command a module answers.
final class CountVisit extends DwActionCommand<int> {
  const CountVisit();

  @override
  String get dwTypeName => 'CountVisit';

  @override
  Map<String, Object?> toJson() => const {};
}

final protocol = DwWireProtocol([
  DwProtocolEntry<CountVisit>('CountVisit', (_) => const CountVisit()),
], include: DwWireProtocol.core);

final class _VisitsTable extends DwDatabaseMigration {
  const _VisitsTable();

  @override
  String get id => '20260915_000000_visits';

  @override
  String get checksum => 'visits-1';

  @override
  List<DwMigrationRef> get dependsOn => const [
    DwMigrationRef('dw', '20260913_000000_dw_initial'),
  ];

  @override
  Future<void> up(DwMigrationContext m) =>
      m.sql('CREATE TABLE visit_count (n bigint NOT NULL)');

  @override
  Future<void> down(DwMigrationContext m) => m.sql('DROP TABLE visit_count');
}

/// A module with a table, a call, a job and something to close.
final class VisitsModule extends DwServerModule {
  VisitsModule({this.name = 'visits', this.jobName = 'dw.visits.count'});

  final String name;
  final String jobName;
  bool closed = false;
  final List<int> counted = [];

  @override
  String get namespace => name;

  @override
  List<DwDatabaseMigration> get migrations => const [_VisitsTable()];

  @override
  List<DwCallHandler> get handlers => [
    DwCallHandler.command<CountVisit, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async {
        // The module's runtime, reached through the context.
        final module = ctx.module<VisitsModule>();
        final rows = await ctx.db.query(
          'INSERT INTO visit_count (n) VALUES (1) RETURNING '
          '(SELECT count(*) FROM visit_count) + 1 AS n',
        );
        await ctx.jobs.enqueue(module.jobName, {'n': rows.single['n']});
        return rows.single.get<int>('n');
      },
    ),
  ];

  @override
  List<DwJobDefinition> get jobs => [
    DwJobDefinition(
      jobName,
      handle: (ctx, payload) async => counted.add(payload['n']! as int),
    ),
  ];

  @override
  List<String> problems(DwWireProtocol protocol) =>
      protocol.knows(CountVisit) ? const [] : ['visits: CountVisit missing'];

  @override
  Future<void> close() async => closed = true;
}

DwAppServer serverWith(
  DwDatabaseConfig database,
  List<DwServerModule> modules, {
  DwWireProtocol? wire,
}) => DwAppServer(
  protocol: wire ?? protocol,
  migrations: const [],
  database: database,
  auth: DwAuthConfig(
    normalize: (kind, raw) => raw,
    deliverCode: (ctx, kind, identifier, code) async {},
  ),
  handlers: const [],
  modules: modules,
  logger: RecordingLogger(),
);

Future<List<String>> problemsOf(DwAppServer server) async {
  try {
    await DwTestServer.start(server);
  } on DwStartupException catch (error) {
    return error.problems;
  }
  fail('the server started');
}

void main() {
  const unreachable = DwDatabaseConfig(
    host: '127.0.0.1',
    port: 1,
    name: 'none',
    user: 'none',
    password: 'none',
  );

  test(
    'a module brings its migrations, calls and jobs, and is closed on stop',
    () async {
      final database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'server_test',
      );
      addTearDown(database.drop);
      final module = VisitsModule();
      final server = await DwTestServer.start(
        serverWith(database.config, [module]),
      );
      final caller = server.caller();
      addTearDown(caller.close);

      final ledger = await server.db.query(
        'SELECT namespace, id FROM dw_migrations ORDER BY seq',
      );
      expect({for (final row in ledger) row['namespace']}, {'dw', 'visits'});
      expect(
        (await caller.call(const CountVisit())).value(const CountVisit()),
        1,
      );
      await eventually(() => module.counted.contains(1));

      await server.stop();
      expect(module.closed, isTrue);
    },
  );

  test('ctx.module of a module the server does not have says so', () async {
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    addTearDown(database.drop);
    final logger = RecordingLogger();
    final server = await DwTestServer.start(
      DwAppServer(
        protocol: protocol,
        migrations: const [],
        database: database.config,
        auth: DwAuthConfig(
          normalize: (kind, raw) => raw,
          deliverCode: (ctx, kind, identifier, code) async {},
        ),
        handlers: [
          DwCallHandler.command<CountVisit, int>(
            access: DwAccessRule.anonymous,
            handle: (ctx, command) async =>
                ctx.module<VisitsModule>().counted.length,
          ),
        ],
        logger: logger,
      ),
    );
    addTearDown(server.stop);
    final caller = server.caller();
    addTearDown(caller.close);
    expect((await caller.call(const CountVisit())).status, 500);
    expect(
      RecordingLogger.lines,
      contains(contains('This server has no VisitsModule')),
    );
  });

  test(
    'a module is refused by its name, its jobs, its calls and its own word',
    () async {
      expect(
        await problemsOf(
          serverWith(unreachable, [
            VisitsModule(name: 'app'),
            VisitsModule(name: 'Bad-Name', jobName: 'dw.other.count'),
          ], wire: DwWireProtocol.core),
        ),
        containsAll([
          contains('namespace "app" must be'),
          contains('namespace "Bad-Name" must be'),
          contains('job "dw.other.count" must be named "dw.Bad-Name.…"'),
          contains('answers CountVisit, which the protocol does not register'),
          'visits: CountVisit missing',
        ]),
      );
      expect(
        await problemsOf(
          serverWith(unreachable, [VisitsModule(), VisitsModule()]),
        ),
        containsAll([
          'module namespace "visits" is used twice',
          'CountVisit has more than one handler',
        ]),
      );
    },
  );
}
