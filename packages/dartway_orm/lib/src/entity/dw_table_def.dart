import '../db/dw_result_row.dart';
import '../query/dw_table_column.dart';
import '../schema/dw_database_schema.dart';
import 'dw_table_row.dart';

/// The generated description of a row class's table: its columns, its
/// schema and the codec between result rows and row objects.
///
/// A row class `<Name>Row` declares `static const tableDef = <Name>Table();`;
/// the subclass is written by `dartway generate` into the row class's part
/// file. Instances are `const`, so each table is one canonical object the ORM
/// can attach its prepared SQL to.
///
/// The generated subclass adds one getter per column, named like the row
/// field, so the members declared here are named the way no row field would
/// want to be (`tableName`, not `name`): a field cannot take a member's name.
abstract class DwTableDef<R extends DwTableRow> {
  const DwTableDef(this.tableName);

  /// The SQL table name.
  final String tableName;

  /// The primary key every table has.
  DwTableColumn<int> get id => DwTableColumn.id;

  /// Every column in declaration order, [id] first.
  List<DwTableColumn<Object?>> get tableColumns;

  List<DwIndexSchema> get indexSchemas => const [];

  DwTableSchema get tableSchema => DwTableSchema(
    tableName,
    columns: [for (final column in tableColumns) column.schema],
    indexes: indexSchemas,
  );

  R fromRow(DwResultRow row);

  /// Dart values by SQL column name; `id` is absent when the row has none
  /// yet. The ORM encodes each value through its column's type.
  Map<String, Object?> toRow(R row);

  @override
  String toString() => 'DwTableDef($tableName)';
}
