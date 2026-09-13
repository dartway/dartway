import 'package:dartway_orm/dartway_orm.dart';

part 'misplaced.dw.dart';

@DwTable('misplaced')
final class Misplaced extends DwEntity with _$Misplaced {
  const Misplaced({this.id});

  @override
  final int? id;

  static const table = MisplacedTable();
}
