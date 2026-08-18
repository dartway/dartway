import 'package:drift/drift.dart';

@DataClassName('DwOfflinePackageRow')
class DwOfflinePackages extends Table {
  @override
  String get tableName => 'dw_offline_packages';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get packageId => text().named('package_id')();

  TextColumn get contentIdentity => text().named('content_identity')();

  TextColumn get activeManifestRevision =>
      text().named('active_manifest_revision').nullable()();

  TextColumn get activeManifestDigest =>
      text().named('active_manifest_digest').nullable()();

  TextColumn get stagingManifestRevision =>
      text().named('staging_manifest_revision').nullable()();

  TextColumn get stagingManifestDigest =>
      text().named('staging_manifest_digest').nullable()();

  TextColumn get aggregateStatus => text().named('aggregate_status')();

  IntColumn get completedAssetCount => integer()
      .named('completed_asset_count')
      .customConstraint('NOT NULL CHECK (completed_asset_count >= 0)')();

  IntColumn get totalAssetCount => integer()
      .named('total_asset_count')
      .customConstraint(
        'NOT NULL CHECK (total_asset_count >= completed_asset_count)',
      )();

  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, packageId};
}
