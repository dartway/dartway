import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta_meta.dart';

/// Declares a row class (`<Name>Row extends DwTableRow`) stored in the table
/// [name].
///
/// The generator reads the class and writes its table definition, codecs and
/// schema into the part file; the annotation itself carries only what cannot
/// be derived from the Dart declaration.
@Target({TargetKind.classType})
final class DwSqlTable {
  const DwSqlTable(this.name, {this.indexes = const []});

  /// The SQL table name.
  final String name;

  final List<DwTableIndex> indexes;
}

/// An index over row class fields, named by their Dart names.
final class DwTableIndex {
  const DwTableIndex(this.fields, {this.unique = false, this.name});

  /// Dart field names, in index order.
  final List<String> fields;

  final bool unique;

  /// Defaults to `<table>_<columns>_idx` (`_key` when unique), the names
  /// Postgres itself would pick, so an introspected index matches its source.
  final String? name;
}

/// What happens to a referencing row when the referenced row is deleted.
enum DwOnDelete {
  noAction('NO ACTION'),
  restrict('RESTRICT'),
  cascade('CASCADE'),
  setNull('SET NULL');

  const DwOnDelete(this.sql);

  final String sql;
}

/// A foreign key to the `id` of [tableName].
///
/// Used both as a field annotation and as the value describing a foreign key
/// in a schema, so the annotation and the schema cannot disagree about what a
/// reference is.
@Target({TargetKind.field})
final class DwForeignKey {
  const DwForeignKey(
    this.tableName, {
    this.onDelete = DwOnDelete.noAction,
    this.relation,
    this.reverse,
  });

  /// Generated forward and reverse relation names; not database schema.
  final String? relation;
  final String? reverse;

  final String tableName;
  final DwOnDelete onDelete;

  @override
  bool operator ==(Object other) =>
      other is DwForeignKey &&
      other.tableName == tableName &&
      other.onDelete == onDelete;

  @override
  int get hashCode => Object.hash(tableName, onDelete);

  @override
  String toString() => 'DwForeignKey($tableName, onDelete: ${onDelete.name})';
}

/// Overrides the SQL column name, which defaults to the snake_case field name.
@Target({TargetKind.field})
final class DwColumnName {
  const DwColumnName(this.name);

  final String name;
}

/// A database-side default for the column.
///
/// The default applies to rows written without the column: rows that existed
/// when the column was added, and raw SQL inserts. A repository insert always
/// writes every column.
@Target({TargetKind.field})
final class DwDefaultValue {
  /// A raw SQL expression, e.g. `'0'`, `"'draft'"`, `"'[]'::jsonb"`.
  const DwDefaultValue(this.sql);

  const DwDefaultValue.now() : sql = 'now()';

  final String sql;

  @override
  bool operator ==(Object other) => other is DwDefaultValue && other.sql == sql;

  @override
  int get hashCode => sql.hashCode;

  @override
  String toString() => 'DwDefaultValue($sql)';
}

/// A single-column unique constraint.
@Target({TargetKind.field})
final class DwUniqueColumn {
  const DwUniqueColumn();
}

/// A non-null enum field whose changes go through a guarded transition.
@Target({TargetKind.field})
final class DwStateColumn<S extends Enum> {
  const DwStateColumn(this.transitions);

  final DwStateTransitions<S> transitions;
}

/// An ordinary write attempted to change a state column or insert a value
/// outside its initial set. Use the repository's guarded transition instead.
final class DwStateWriteException implements Exception {
  const DwStateWriteException(this.tableName, this.operation);

  final String tableName;
  final String operation;

  @override
  String toString() =>
      'DwStateWriteException($tableName, $operation): '
      'state columns require an initial value on insert and a guarded transition';
}
