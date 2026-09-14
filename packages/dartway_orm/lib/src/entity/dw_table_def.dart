import '../db/dw_result_row.dart';
import '../query/dw_table_column.dart';
import '../schema/dw_database_schema.dart';
import 'dw_table_row.dart';

/// The generated description of a row class's table: its columns, its
/// schema and the codec between result rows and row objects.
///
/// A row class `<Name>Row` declares `static const table = <Name>Table();`;
/// the subclass is written by `dartway generate` into the row class's part
/// file. Instances are `const`, so each table is one canonical object the ORM
/// can attach its prepared SQL to.
abstract class DwTableDef<R extends DwTableRow> {
  const DwTableDef(this.name);

  final String name;

  /// The primary key every table has.
  DwTableColumn<int> get id => DwTableColumn.id;

  /// Every column in declaration order, [id] first.
  List<DwTableColumn<Object?>> get columns;

  List<DwIndexSchema> get indexSchemas => const [];

  DwTableSchema get schema => DwTableSchema(
    name,
    columns: [for (final column in columns) column.schema],
    indexes: indexSchemas,
  );

  R fromRow(DwResultRow row);

  /// Dart values by SQL column name; `id` is absent when the row has none
  /// yet. The ORM encodes each value through its column's type.
  Map<String, Object?> toRow(R row);

  @override
  String toString() => 'DwTableDef($name)';
}
