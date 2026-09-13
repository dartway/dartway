import 'package:dartway_orm/dartway_orm.dart' as orm;

part 'prefixed.dw.dart';

@orm.DwTable('prefixed')
final class Prefixed extends orm.DwEntity with _$Prefixed {
  const Prefixed({this.id});

  @override
  final int? id;

  static const table = PrefixedTable();
}
