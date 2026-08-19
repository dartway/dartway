import 'package:drift/drift.dart';

@DataClassName('DwOfflineSnapshotRow')
class DwOfflineSnapshots extends Table {
  @override
  String get tableName => 'dw_offline_snapshots';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get queryKey => text().named('query_key')();

  TextColumn get envelopeJson => text().named('envelope_json')();

  IntColumn get capturedAtEpochMs => integer().named('captured_at_epoch_ms')();

  IntColumn get expiresAtEpochMs =>
      integer().named('expires_at_epoch_ms').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, queryKey};
}
