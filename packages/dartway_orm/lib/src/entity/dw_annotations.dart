import 'package:meta/meta_meta.dart';

/// Declares a class as a database entity stored in the table [name].
///
/// The generator reads the class and writes its table definition, codecs and
/// schema into the part file; the annotation itself carries only what cannot
/// be derived from the Dart declaration.
@Target({TargetKind.classType})
final class DwTable {
  const DwTable(this.name, {this.indexes = const []});

  /// The SQL table name.
  final String name;

  final List<DwIndex> indexes;
}

/// An index over entity fields, named by their Dart names.
final class DwIndex {
  const DwIndex(this.fields, {this.unique = false, this.name});

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
final class DwReferences {
  const DwReferences(this.tableName, {this.onDelete = DwOnDelete.noAction});

  final String tableName;
  final DwOnDelete onDelete;

  @override
  bool operator ==(Object other) =>
      other is DwReferences &&
      other.tableName == tableName &&
      other.onDelete == onDelete;

  @override
  int get hashCode => Object.hash(tableName, onDelete);

  @override
  String toString() => 'DwReferences($tableName, onDelete: ${onDelete.name})';
}

/// Overrides the SQL column name, which defaults to the snake_case field name.
@Target({TargetKind.field})
final class DwColumnName {
  const DwColumnName(this.name);

  final String name;
}

/// A database-side default for the column.
///
/// The default applies to rows the entity does not write: rows that existed
/// when the column was added, and raw SQL inserts. An entity insert always
/// writes every column.
@Target({TargetKind.field})
final class DwDefault {
  /// A raw SQL expression, e.g. `'0'`, `"'draft'"`, `"'[]'::jsonb"`.
  const DwDefault(this.sql);

  const DwDefault.now() : sql = 'now()';

  final String sql;

  @override
  bool operator ==(Object other) => other is DwDefault && other.sql == sql;

  @override
  int get hashCode => sql.hashCode;

  @override
  String toString() => 'DwDefault($sql)';
}

/// A single-column unique constraint.
@Target({TargetKind.field})
final class DwUnique {
  const DwUnique();
}
