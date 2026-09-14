import 'package:dartway_server/dartway_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// `GET /health` answers for the database the server depends on. The server
/// here connects as an ordinary role, so taking its login away makes the
/// database unreachable for it while the test keeps its own connection.
void main() {
  final app = TestApp();
  late DwPostgresDatabase admin;
  late DwTestDatabase database;
  late DwTestServer server;
  final role = 'dw_health_${DateTime.now().microsecondsSinceEpoch}';

  setUpAll(() async {
    admin = await DwPostgresDatabase.open(
      adminConfig().copyWith(maxConnections: 1),
    );
    await admin.db.execute("CREATE ROLE $role LOGIN PASSWORD 'probe'");
    database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    await admin.db.execute(
      'ALTER DATABASE "${database.config.name}" OWNER TO $role',
    );
    final config = DwDatabaseConfig(
      host: database.config.host,
      port: database.config.port,
      name: database.config.name,
      user: role,
      password: 'probe',
      ssl: database.config.ssl,
      maxConnections: 2,
      connectTimeout: const Duration(seconds: 2),
    );
    server = await DwTestServer.start(app.server(config));
  });

  tearDownAll(() async {
    await server.stop();
    await database.drop();
    await admin.db.execute('DROP ROLE IF EXISTS $role');
    await admin.close();
  });

  test('200 while the database answers, 503 while it does not, 200 again '
      'once it does', () async {
    final caller = server.caller();
    addTearDown(caller.close);
    final ok = await caller.raw('GET', '/health');
    expect((ok.status, ok.text), (200, 'ok'));

    await admin.db.execute('ALTER ROLE $role NOLOGIN');
    try {
      await admin.db.execute(
        'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
        "WHERE usename = '$role'",
      );
      await eventually(
        () async => (await caller.raw('GET', '/health')).status == 503,
      );
      final down = await caller.raw('GET', '/health');
      expect(down.text, 'database unavailable');
    } finally {
      await admin.db.execute('ALTER ROLE $role LOGIN');
    }
    await eventually(
      () async => (await caller.raw('GET', '/health')).status == 200,
    );
  });
}
