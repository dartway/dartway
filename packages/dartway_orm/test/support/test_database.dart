import 'dart:io';
import 'dart:math';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import '../fixtures/generated/dw_schema.dart';

/// The Postgres the suites run against. Overridable through `DW_DATABASE_*`,
/// defaulting to the local test cluster.
DwDatabaseConfig testServerConfig({String? name, int maxConnections = 4}) {
  final env = Platform.environment;
  return DwDatabaseConfig(
    host: env['DW_DATABASE_HOST'] ?? '127.0.0.1',
    port: int.parse(env['DW_DATABASE_PORT'] ?? '55460'),
    name: name ?? env['DW_DATABASE_NAME'] ?? 'dartway',
    user: env['DW_DATABASE_USER'] ?? 'dartway',
    password: env['DW_DATABASE_PASSWORD'] ?? 'dartway',
    ssl: false,
    maxConnections: maxConnections,
  );
}

final _random = Random();

String uniqueDatabaseName([String kind = 'db']) =>
    'orm_test_${kind}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';

/// Creates a fresh database for one suite and drops it afterwards.
///
/// A suite that cannot reach Postgres fails loudly in `setUpAll`: a database
/// tier that silently skips is a tier that does not exist.
final class TestDatabase {
  TestDatabase._(this.name, this.database);

  final String name;
  final DwDatabase database;

  DwDb get db => database.db;

  static Future<TestDatabase> create({
    bool withFixtureSchema = true,
    bool countRoundTrips = false,
    int maxConnections = 4,
  }) async {
    final name = uniqueDatabaseName();
    await createDatabase(name);
    final database = await DwDatabase.open(
      testServerConfig(name: name, maxConnections: maxConnections),
      countRoundTrips: countRoundTrips,
    );
    if (withFixtureSchema) {
      final context = DwMigrationContext(database.db);
      // club_service first: the other two reference it.
      for (final name in ['club_service', 'club_session', 'app_setting']) {
        await context.createTable(fixtureSchema.table(name)!);
      }
    }
    return TestDatabase._(name, database);
  }

  Future<DwDatabase> openAnother({int maxConnections = 4}) => DwDatabase.open(
    testServerConfig(name: name, maxConnections: maxConnections),
  );

  Future<void> dispose() async {
    await database.close();
    await dropDatabase(name);
  }
}

/// Runs statements against the maintenance database.
Future<T> withServer<T>(Future<T> Function(DwDb db) body) async {
  final server = await DwDatabase.open(testServerConfig(maxConnections: 1));
  try {
    return await body(server.db);
  } finally {
    await server.close();
  }
}

Future<void> createDatabase(String name) =>
    withServer((db) => db.execute('CREATE DATABASE "$name"'));

Future<void> dropDatabase(String name) => withServer(
  (db) => db.execute('DROP DATABASE IF EXISTS "$name" WITH (FORCE)'),
);

/// A suite-scoped database with the fixture schema.
TestDatabase Function() useTestDatabase({
  bool withFixtureSchema = true,
  bool countRoundTrips = false,
  int maxConnections = 4,
}) {
  late TestDatabase database;
  setUpAll(() async {
    database = await TestDatabase.create(
      withFixtureSchema: withFixtureSchema,
      countRoundTrips: countRoundTrips,
      maxConnections: maxConnections,
    );
  });
  tearDownAll(() => database.dispose());
  return () => database;
}
