import 'package:dartway_orm/dartway_orm.dart';

/// Runs a diff's changes, answering every decision the obvious way — drop
/// what is dropped, backfill with [backfill]. The draft writer emits the same
/// calls as source; this lets the diff tests prove the order runs without
/// compiling a file.
Future<void> applyChanges(
  DwMigrationContext m,
  List<DwSchemaChange> changes, {
  String backfill = '0',
}) async {
  for (final change in changes) {
    final table = change.table;
    switch (change) {
      case DwCreateTable(:final schema):
        await m.createTable(schema);
      case DwDropTable(:final schema):
        await m.dropTable(schema.name);
      case DwAddColumn(:final column) when change.requiresDecision:
        await m.addColumn(table, column, backfill: backfill);
      case DwAddColumn(:final column):
        await m.addColumn(table, column);
      case DwDropColumn(:final column):
        await m.dropColumn(table, column.name);
      case DwAlterColumnType(:final column, :final to):
        await m.alterColumnType(table, column, to, using: '"$column"::$to');
      case DwAlterColumnNullability(:final column, :final nullable):
        await m.alterColumnNullability(
          table,
          column,
          nullable: nullable,
          backfill: nullable ? null : backfill,
        );
      case DwAlterColumnDefault(:final column, :final to):
        await m.alterColumnDefault(table, column, to);
      case DwAddUnique(:final column):
        await m.addUnique(table, column);
      case DwDropUnique(:final column):
        await m.dropUnique(table, column);
      case DwAddForeignKey(:final column, :final references):
        await m.addForeignKey(table, column, references);
      case DwDropForeignKey(:final column):
        await m.dropForeignKey(table, column);
      case DwCreateIndex(:final index):
        await m.createIndex(table, index);
      case DwDropIndex(:final index):
        await m.dropIndex(index.name);
    }
  }
}
