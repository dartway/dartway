import 'package:drift/drift.dart';

// Drift resolves composite foreign-key table names through imports.
// ignore: unused_import
import 'dw_offline_assets.dart';

@DataClassName('DwOfflineReaderPinRow')
class DwOfflineReaderPins extends Table {
  @override
  String get tableName => 'dw_offline_reader_pins';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get readerId => text().named('reader_id')();

  TextColumn get assetId => text().named('asset_id')();

  TextColumn get assetRevision => text().named('asset_revision')();

  IntColumn get pinnedAtEpochMs => integer().named('pinned_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {
    userScopeId,
    readerId,
    assetId,
    assetRevision,
  };

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (user_scope_id, asset_id, asset_revision) '
        'REFERENCES dw_offline_assets '
        '(user_scope_id, asset_id, asset_revision) ON DELETE RESTRICT',
  ];
}
