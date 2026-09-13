import 'package:dartway_orm/dartway_orm.dart';

part 'declarations.dw.dart';

final class NoTable extends DwEntity with _$NoTable {
  const NoTable({this.id});

  @override
  final int? id;

  static const table = NoTableTable();
}

@DwTable('no_static_table')
final class NoStaticTable extends DwEntity with _$NoStaticTable {
  const NoStaticTable({this.id});

  @override
  final int? id;
}

@DwTable('wrong_id')
final class WrongId extends DwEntity with _$WrongId {
  const WrongId({required this.id});

  @override
  final int id;

  static const table = WrongIdTable();
}

@DwTable('shadowing')
final class Shadowing extends DwEntity with _$Shadowing {
  const Shadowing({this.id, required this.name, required this.columns});

  @override
  final int? id;
  final String name;
  final int columns;

  static const table = ShadowingTable();
}
