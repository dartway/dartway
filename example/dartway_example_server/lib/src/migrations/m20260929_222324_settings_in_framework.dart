// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929222324SettingsInFramework extends DwDatabaseMigration {
  const M20260929222324SettingsInFramework();

  @override
  String get id => '20260929_222324_settings_in_framework';

  @override
  String get checksum => 'de2d71edfaac76288329238348483d1f';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The club's settings are a settings object in the framework's
    // `dw_setting` (`ctx.settings`), with their defaults in the contract.
    // What was saved is carried over first, read exactly as the app read it
    // (`AppSettingKey.parse`): a text trimmed — an empty phone was the
    // default, no phone — and a toggle on for `true`/`1`/`yes`, off for
    // `false`/`0`/`no`, and its default for anything else.
    await m.carrySettings('ClubSettings', fromSql: r'''
SELECT jsonb_strip_nulls(jsonb_build_object(
  'clubName',
    (SELECT trim(value) FROM app_setting WHERE key = 'clubName'),
  'bookingEnabled',
    (SELECT CASE
       WHEN lower(trim(value)) IN ('true', '1', 'yes') THEN true
       WHEN lower(trim(value)) IN ('false', '0', 'no') THEN false
     END
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
