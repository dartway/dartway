import 'package:dartway_orm/dartway_orm.dart';

part 'declarations.dw.dart';

final class NoTableRow extends DwTableRow with _$NoTableRow {
  const NoTableRow({this.id});

  @override
  final int? id;

  static const tableDef = NoTableTable();
}

@DwSqlTable('no_static_table')
final class NoStaticTableRow extends DwTableRow with _$NoStaticTableRow {
  const NoStaticTableRow({this.id});

  @override
  final int? id;
}

@DwSqlTable('wrong_id')
final class WrongIdRow extends DwTableRow with _$WrongIdRow {
  const WrongIdRow({required this.id});

  @override
  final int id;

  static const tableDef = WrongIdTable();
}

@DwSqlTable('shadowing')
final class ShadowingRow extends DwTableRow with _$ShadowingRow {
  const ShadowingRow({
    this.id,
    required this.tableName,
    required this.tableColumns,
  });

  @override
  final int? id;
  final String tableName;
  final int tableColumns;

  static const tableDef = ShadowingTable();
}

/// A field cannot take the name of the static table definition.
@DwSqlTable('table_def_field')
final class TableDefFieldRow extends DwTableRow with _$TableDefFieldRow {
  const TableDefFieldRow({this.id, required this.tableDef});

  @override
  final int? id;
  final int tableDef;
}

/// The table and repository names derive from the name without `Row`.
@DwSqlTable('club_session')
final class ClubSession extends DwTableRow with _$ClubSession {
  const ClubSession({this.id});

  @override
  final int? id;

  static const tableDef = ClubSessionTable();
}

/// Nothing before the suffix.
@DwSqlTable('bare_row')
final class Row extends DwTableRow with _$Row {
  const Row({this.id});

  @override
  final int? id;

  static const tableDef = RowTable();
}
