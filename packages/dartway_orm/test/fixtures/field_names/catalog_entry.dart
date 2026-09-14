import 'package:dartway_orm/dartway_orm.dart';

part 'catalog_entry.dw.dart';

/// Hand-written input of `dartway generate`; its part is the generator's
/// output, reproduced byte for byte by the generator's tests (D-040).
///
/// Every field takes a name a table definition or its queries could have
/// wanted for themselves: the generated table class has a column getter of
/// each name, and `fromRow` reads a column called `row`.
@DwSqlTable(
  'catalog_entry',
  indexes: [
    DwTableIndex(['name']),
  ],
)
final class CatalogEntryRow extends DwTableRow with _$CatalogEntryRow {
  const CatalogEntryRow({
    this.id,
    required this.name,
    this.schema,
    required this.columns,
    this.table,
    required this.row,
    required this.where,
    this.order = 0,
  });

  @override
  final int? id;

  final String name;
  final String? schema;
  final int columns;
  final int? table;
  final String row;
  final String where;
  final int order;

  static const tableDef = CatalogEntryTable();
}
