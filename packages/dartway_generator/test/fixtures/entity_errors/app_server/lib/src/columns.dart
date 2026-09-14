import 'package:dartway_orm/dartway_orm.dart';

import 'values.dart';

part 'columns.dw.dart';

@DwSqlTable(
  'columns',
  indexes: [
    DwTableIndex(['missing']),
    DwTableIndex(['title'], name: 'columns_title_idx'),
    DwTableIndex(['title']),
  ],
)
final class ColumnsRow extends DwTableRow with _$ColumnsRow {
  const ColumnsRow({
    this.id,
    required this.title,
    required this.view,
    required this.dates,
    required this.set,
    required this.ownerName,
    required this.same,
    required this.alsoSame,
  });

  @override
  final int? id;
  final String title;
  final ValueView view;
  final List<DateTime> dates;
  final Set<int> set;

  @DwForeignKey('owner')
  final String ownerName;

  final int same;

  @DwColumnName('same')
  final int alsoSame;

  static const tableDef = ColumnsTable();
}

@DwSqlTable('shared_name')
final class SameTableARow extends DwTableRow with _$SameTableARow {
  const SameTableARow({this.id});

  @override
  final int? id;

  static const tableDef = SameTableATable();
}

@DwSqlTable('shared_name')
final class SameTableBRow extends DwTableRow with _$SameTableBRow {
  const SameTableBRow({this.id});

  @override
  final int? id;

  static const tableDef = SameTableBTable();
}

@DwSqlTable(
  'a_table_name_that_is_far_too_long_for_postgres_to_keep_in_one_piece',
)
final class LongNameRow extends DwTableRow with _$LongNameRow {
  const LongNameRow({this.id});

  @override
  final int? id;

  static const tableDef = LongNameTable();
}
