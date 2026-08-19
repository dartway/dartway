import 'package:drift/drift.dart';

@DataClassName('DwOfflineOutboxRow')
class DwOfflineOutbox extends Table {
  @override
  String get tableName => 'dw_offline_outbox';

  TextColumn get userScopeId => text()
      .named('user_scope_id')
      .customConstraint('NOT NULL CHECK (length(trim(user_scope_id)) > 0)')();

  TextColumn get mutationId => text().named('mutation_id')();

  TextColumn get entityType => text().named('entity_type')();

  TextColumn get entityId => text().named('entity_id')();

  TextColumn get mutationType => text().named('mutation_type')();

  TextColumn get idempotencyKey => text().named('idempotency_key')();

  TextColumn get envelopeJson => text().named('envelope_json')();

  IntColumn get createdAtEpochMs => integer().named('created_at_epoch_ms')();

  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>> get primaryKey => {userScopeId, mutationId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userScopeId, entityType, entityId},
  ];
}
