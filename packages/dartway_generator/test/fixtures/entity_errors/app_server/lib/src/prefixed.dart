import 'package:dartway_orm/dartway_orm.dart' as orm;

part 'prefixed.dw.dart';

@orm.DwSqlTable('prefixed')
final class PrefixedRow extends orm.DwTableRow with _$PrefixedRow {
  const PrefixedRow({this.id});

  @override
  final int? id;

  static const tableDef = PrefixedTable();
}
