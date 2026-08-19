import 'package:drift/drift.dart';

// Drift resolves composite foreign-key table names through imports.
// ignore: unused_import
import 'dw_offline_packages.dart';

@DataClassName('DwOfflineManifestRow')
class DwOfflineManifests extends Table {
  @override
  String get tableName => 'dw_offline_manifests';

  TextColumn get userScopeId => text().named('user_scope_id')();
  TextColumn get packageId => text().named('package_id')();
  TextColumn get manifestRevision => text().named('manifest_revision')();
  TextColumn get payloadDigest => text().named('payload_digest')();
  TextColumn get envelopeJson => text().named('envelope_json')();
  BlobColumn get payloadBytes => blob().named('payload_bytes')();
  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (user_scope_id, package_id) '
        'REFERENCES dw_offline_packages (user_scope_id, package_id) '
        'ON DELETE CASCADE',
  ];
}
