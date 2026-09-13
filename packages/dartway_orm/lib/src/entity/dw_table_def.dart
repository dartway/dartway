import '../db/dw_row.dart';
import '../query/dw_column.dart';
import '../schema/dw_schema.dart';
import 'dw_entity.dart';

/// The generated description of an entity's table: its columns, its schema
/// and the codec between rows and entities.
///
/// An entity declares `static const table = <Name>Table();`; the subclass is
/// written by `dartway generate` into the entity's part file. Instances are
/// `const`, so each table is one canonical object the ORM can attach its
/// prepared SQL to.
abstract class DwTableDef<E extends DwEntity> {
  const DwTableDef(this.name);

  final String name;

  /// The primary key every entity table has.
  DwColumn<int> get id => DwColumn.id;

  /// Every column in declaration order, [id] first.
  List<DwColumn<Object?>> get columns;

  List<DwIndexSchema> get indexSchemas => const [];

  DwTableSchema get schema => DwTableSchema(
    name,
    columns: [for (final column in columns) column.schema],
    indexes: indexSchemas,
  );

  E fromRow(DwRow row);

  /// Dart values by SQL column name; `id` is absent when the entity has none
  /// yet. The ORM encodes each value through its column's type.
  Map<String, Object?> toRow(E entity);

  @override
  String toString() => 'DwTableDef($name)';
}
