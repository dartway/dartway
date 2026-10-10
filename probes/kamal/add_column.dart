import 'package:dartway_core_server/dartway_core_server.dart';

final class ProbeAddColumn extends DwDatabaseMigration {
  const ProbeAddColumn();
  @override
  String get id => '20261010_120000_probe_column';
  @override
  String get checksum => 'unsealed';
  @override
  Future<void> up(DwMigrationContext m) async {
    await m.sql('ALTER TABLE user_profile ADD COLUMN probe_marker text');
    await m.sql('SELECT pg_sleep(5)');
  }

  @override
  Future<void> down(DwMigrationContext m) =>
      m.sql('ALTER TABLE user_profile DROP COLUMN probe_marker');
}
