import 'package:drift/drift.dart';

// Drift resolves composite foreign-key table names through imports.
// ignore: unused_import
import 'dw_offline_assets.dart';
// ignore: unused_import
import 'dw_offline_manifests.dart';

@DataClassName('DwOfflineStagingAssetRow')
class DwOfflineStagingAssets extends Table {
  @override
  String get tableName => 'dw_offline_staging_assets';

  TextColumn get userScopeId => text().named('user_scope_id')();
  TextColumn get packageId => text().named('package_id')();
  TextColumn get manifestRevision => text().named('manifest_revision')();
  TextColumn get assetId => text().named('asset_id')();
  TextColumn get assetRevision => text().named('asset_revision')();
  BoolColumn get isRequired => boolean().named('is_required')();
  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
    assetId,
    assetRevision,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (user_scope_id, package_id, manifest_revision) '
        'REFERENCES dw_offline_manifests '
        '(user_scope_id, package_id, manifest_revision) ON DELETE CASCADE',
    'FOREIGN KEY (user_scope_id, asset_id, asset_revision) '
        'REFERENCES dw_offline_assets '
        '(user_scope_id, asset_id, asset_revision) ON DELETE RESTRICT',
  ];
}
