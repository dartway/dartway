import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

/// The club's settings moved from a key/value table into a settings object;
/// the migration that drops the table carries what was saved (#388).
void main() {
  late DwTestDatabase database;
  late DwPostgresDatabase opened;

  setUp(() async {
    database = await DwTestDatabase.create(prefix: 'dw_example_test');
    opened = await DwPostgresDatabase.open(database.config);
  });
  tearDown(() async {
    await opened.close();
    await database.drop();
  });

  Future<void> migrate(bool Function(String id) upTo) => DwMigrationRunner(
    opened.db,
    migrations: {
      'dw': DwAppServer.frameworkMigrations,
      // The analytics module's tables are not this migration's business.
      'app': [
        for (final migration in appMigrations)
          if (upTo(migration.id)) migration,
      ],
    },
  ).apply();

  test('saved values become the settings object; a blank phone is none, and '
      'what was never saved stays the default', () async {
    await migrate((id) => id.compareTo('20260929_222324') < 0);
    await opened.db.execute(
      "INSERT INTO app_setting (key, value) VALUES "
      "('clubName', ' Iron Gym '), ('bookingEnabled', 'false'), "
      "('supportPhone', '  ')",
    );
    await migrate((_) => true);

    final server = await DwTestServer.start(
      DartwayExampleServer.build(
        database: database.config,
        port: 0,
        adminIdentifier: null,
      ),
    );
    try {
      expect(
        await server.runInContext((ctx) => ctx.settings.read<ClubSettings>()),
        const ClubSettings(clubName: 'Iron Gym', bookingEnabled: false),
      );
    } finally {
      await server.stop();
    }
  });
}
