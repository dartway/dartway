import 'package:dartway_core_server/dartway_core_server.dart';

final class ProbeFailedMigration extends DwDatabaseMigration {
  const ProbeFailedMigration();
  @override
  String get id => '20261010_120100_probe_failure';
  @override
  String get checksum => 'unsealed';
  @override
  Future<void> up(DwMigrationContext m) =>
      m.sql('SELECT * FROM probe_intentionally_missing_table');
}
