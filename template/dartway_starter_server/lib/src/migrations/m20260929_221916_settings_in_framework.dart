// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929221916SettingsInFramework extends DwDatabaseMigration {
  const M20260929221916SettingsInFramework();

  @override
  String get id => '20260929_221916_settings_in_framework';

  @override
  String get checksum => '3c4a747f3bb68668b3c2cb0841d21a22';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The app's settings are a settings object in the framework's
    // `dw_setting` (`ctx.settings`), with their defaults in the contract.
    // What was saved is carried over first, read exactly as the old code
    // read it: the name trimmed, and sign-up off only for a stored `false`
    // (`AppAuth.isSignUpEnabled` compared the trimmed, lower-cased text with
    // it and treated anything else as on).
    await m.carrySettings('AppSettings', fromSql: r'''
SELECT jsonb_strip_nulls(jsonb_build_object(
  'appName',
    (SELECT trim(value) FROM app_setting WHERE key = 'appName'),
  'signUpEnabled',
    (SELECT lower(trim(value)) <> 'false'
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
