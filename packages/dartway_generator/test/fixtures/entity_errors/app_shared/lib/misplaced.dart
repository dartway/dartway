import 'package:dartway_orm/dartway_orm.dart';

part 'misplaced.dw.dart';

@DwSqlTable('misplaced')
final class MisplacedRow extends DwTableRow with _$MisplacedRow {
  const MisplacedRow({this.id});

  @override
  final int? id;

  static const table = MisplacedTable();
}
