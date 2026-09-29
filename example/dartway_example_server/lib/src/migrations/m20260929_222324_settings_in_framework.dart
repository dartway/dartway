// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929222324SettingsInFramework extends DwDatabaseMigration {
  const M20260929222324SettingsInFramework();

  @override
  String get id => '20260929_222324_settings_in_framework';

  @override
  String get checksum => '9fb0e842532280a0a20a83ff505f5f89';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The club's settings are a settings object in the framework's
    // `dw_setting` (`ctx.settings`), with their defaults in the contract.
    // What was saved is carried over first: a text as it was (a blank phone
    // is no phone), a toggle read the way the app read it.
    await m.carrySettings('ClubSettings', fromSql: r'''
SELECT jsonb_strip_nulls(jsonb_build_object(
  'clubName',
    (SELECT nullif(trim(value), '') FROM app_setting WHERE key = 'clubName'),
  'bookingEnabled',
    (SELECT lower(trim(value)) IN ('true', '1', 'yes')
     FROM app_setting WHERE key = 'bookingEnabled'),
  'supportPhone',
    (SELECT nullif(trim(value), '') FROM app_setting WHERE key = 'supportPhone')))''');
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
