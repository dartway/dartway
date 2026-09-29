// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929221916SettingsInFramework extends DwDatabaseMigration {
  const M20260929221916SettingsInFramework();

  @override
  String get id => '20260929_221916_settings_in_framework';

  @override
  String get checksum => '05b96c90a5acf692d16cba56e3701d11';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The app's settings are a settings object in the framework's
    // `dw_setting` (`ctx.settings`), with their defaults in the contract.
    // What was saved is carried over first, a toggle read the way the app
    // read it.
    await m.carrySettings('AppSettings', fromSql: r'''
SELECT jsonb_strip_nulls(jsonb_build_object(
  'appName',
    (SELECT nullif(trim(value), '') FROM app_setting WHERE key = 'appName'),
  'signUpEnabled',
    (SELECT lower(trim(value)) NOT IN ('false', '0', 'no')
     FROM app_setting WHERE key = 'signUpEnabled')))''');
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
