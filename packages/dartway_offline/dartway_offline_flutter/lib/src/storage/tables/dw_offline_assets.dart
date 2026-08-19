import 'package:drift/drift.dart';

@DataClassName('DwOfflineAssetRow')
class DwOfflineAssets extends Table {
  @override
  String get tableName => 'dw_offline_assets';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get assetId => text().named('asset_id')();

  TextColumn get assetRevision => text().named('asset_revision')();

  IntColumn get expectedSizeBytes => integer()
      .named('expected_size_bytes')
      .customConstraint('NOT NULL CHECK (expected_size_bytes >= 0)')();

  TextColumn get checksum => text()();

  TextColumn get mimeType => text().named('mime_type')();

  TextColumn get relativePath => text().named('relative_path')();

  TextColumn get downloadUrl => text().named('download_url').nullable()();

  TextColumn get allowedRedirectHostsJson =>
      text().named('allowed_redirect_hosts_json').nullable()();

  TextColumn get blobName => text().named('blob_name').nullable()();

  TextColumn get assetState => text().named('asset_state')();

  IntColumn get refCount => integer()
      .named('ref_count')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (ref_count >= 0)')();

  BoolColumn get isTombstoned =>
      boolean().named('is_tombstoned').withDefault(const Constant(false))();

  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, assetId, assetRevision};
}
