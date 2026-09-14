import 'package:dartway_orm/dartway_orm.dart';

part 'declarations.dw.dart';

final class NoTableRow extends DwTableRow with _$NoTableRow {
  const NoTableRow({this.id});

  @override
  final int? id;

  static const table = NoTableTable();
}

@DwTable('no_static_table')
final class NoStaticTableRow extends DwTableRow with _$NoStaticTableRow {
  const NoStaticTableRow({this.id});

  @override
  final int? id;
}

@DwTable('wrong_id')
final class WrongIdRow extends DwTableRow with _$WrongIdRow {
  const WrongIdRow({required this.id});

  @override
  final int id;

  static const table = WrongIdTable();
}

@DwTable('shadowing')
final class ShadowingRow extends DwTableRow with _$ShadowingRow {
  const ShadowingRow({this.id, required this.name, required this.columns});

  @override
  final int? id;
  final String name;
  final int columns;

  static const table = ShadowingTable();
}

/// The table and repository names derive from the name without `Row`.
@DwTable('club_session')
final class ClubSession extends DwTableRow with _$ClubSession {
  const ClubSession({this.id});

  @override
  final int? id;

  static const table = ClubSessionTable();
}

/// Nothing before the suffix.
@DwTable('bare_row')
final class Row extends DwTableRow with _$Row {
  const Row({this.id});

  @override
  final int? id;

  static const table = RowTable();
}
