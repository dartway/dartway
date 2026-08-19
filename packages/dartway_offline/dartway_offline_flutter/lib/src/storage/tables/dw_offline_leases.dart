import 'package:drift/drift.dart';

@DataClassName('DwOfflineLeaseRow')
class DwOfflineLeases extends Table {
  @override
  String get tableName => 'dw_offline_leases';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get leaseId => text().named('lease_id')();

  TextColumn get leaseEnvelopeJson => text().named('lease_envelope_json')();

  IntColumn get trustedAtEpochMs => integer().named('trusted_at_epoch_ms')();

  IntColumn get expiresAtEpochMs => integer().named('expires_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, leaseId};
}
