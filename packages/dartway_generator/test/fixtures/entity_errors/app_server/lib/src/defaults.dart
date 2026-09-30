import 'package:dartway_orm/dartway_orm.dart';

part 'defaults.dw.dart';

/// An id with a default is a sentinel: a row always comes with its own.
@DwSqlTable('default_id')
final class DefaultIdRow extends DwTableRow with _$DefaultIdRow {
  const DefaultIdRow({this.id = 0});

  @override
  final int id;

  static const tableDef = DefaultIdTable();
}
