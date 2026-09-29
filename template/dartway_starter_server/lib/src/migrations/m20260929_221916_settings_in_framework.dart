// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929221916SettingsInFramework extends DwDatabaseMigration {
  const M20260929221916SettingsInFramework();

  @override
  String get id => '20260929_221916_settings_in_framework';

  @override
  String get checksum => '703b4e86cb49c4ffa68dc81132a19ccd';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The app's settings are a settings object in the framework's
    // `dw_setting` (`ctx.settings`), with their defaults in the contract.
    await m.dropTable('app_setting');
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.createTable(
      DwTableSchema(
        'app_setting',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema('key', 'text', unique: true),
          DwColumnSchema('value', 'text'),
        ],
      ),
    );
  }
}
