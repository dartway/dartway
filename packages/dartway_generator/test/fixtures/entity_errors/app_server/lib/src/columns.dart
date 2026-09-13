import 'package:dartway_orm/dartway_orm.dart';

import 'values.dart';

part 'columns.dw.dart';

@DwTable(
  'columns',
  indexes: [
    DwIndex(['missing']),
    DwIndex(['title'], name: 'columns_title_idx'),
    DwIndex(['title']),
  ],
)
final class Columns extends DwEntity with _$Columns {
  const Columns({
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

  @DwReferences('owner')
  final String ownerName;

  final int same;

  @DwColumnName('same')
  final int alsoSame;

  static const table = ColumnsTable();
}

@DwTable('shared_name')
final class SameTableA extends DwEntity with _$SameTableA {
  const SameTableA({this.id});

  @override
  final int? id;

  static const table = SameTableATable();
}

@DwTable('shared_name')
final class SameTableB extends DwEntity with _$SameTableB {
  const SameTableB({this.id});

  @override
  final int? id;

  static const table = SameTableBTable();
}

@DwTable('a_table_name_that_is_far_too_long_for_postgres_to_keep_in_one_piece')
final class LongName extends DwEntity with _$LongName {
  const LongName({this.id});

  @override
  final int? id;

  static const table = LongNameTable();
}
