import 'package:drift/drift.dart';

// Drift resolves the composite manifest foreign key through this import.
// ignore: unused_import
import 'dw_offline_manifests.dart';

@DataClassName('DwOfflinePackageSnapshotRow')
class DwOfflinePackageSnapshots extends Table {
  @override
  String get tableName => 'dw_offline_package_snapshots';

  TextColumn get userScopeId => text().named('user_scope_id')();
  TextColumn get packageId => text().named('package_id')();
  TextColumn get manifestRevision => text().named('manifest_revision')();
  TextColumn get queryKey => text().named('query_key')();
  TextColumn get envelopeJson => text().named('envelope_json')();
  IntColumn get capturedAtEpochMs => integer().named('captured_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
    queryKey,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (user_scope_id, package_id, manifest_revision) '
        'REFERENCES dw_offline_manifests '
        '(user_scope_id, package_id, manifest_revision) ON DELETE CASCADE',
  ];
}
