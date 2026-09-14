import 'package:analyzer/dart/element/element.dart';

import '../analysis/wire_type.dart';
import '../emit/value_class_writer.dart';

/// A field of an entity: a value of the entity and, unless it is `id`, a
/// column of its table.
final class EntityField implements ValueField {
  const EntityField({
    required this.name,
    required this.type,
    required this.spelling,
    required this.column,
  });

  @override
  final String name;
  @override
  final WireType type;
  @override
  final String spelling;

  /// The column, or `null` for `id` (every table's primary key, declared by
  /// `DwTableDef`).
  final EntityColumn? column;
}

/// A column declared by the generated table class.
final class EntityColumn {
  const EntityColumn({
    required this.sqlName,
    required this.dwType,
    required this.unique,
    required this.defaultValue,
    required this.references,
  });

  final String sqlName;

  /// The `DwColumnType` expression: `DwColumnType.bigint`,
  /// `DwEnumType(Kind.values)`, …
  final String dwType;
  final bool unique;

  /// A const `DwDefaultValue` expression, or `null`.
  final String? defaultValue;

  /// A const `DwForeignKey` expression, or `null`.
  final String? references;
}

/// An index of the table.
final class EntityIndex {
  const EntityIndex(this.name, this.columns, {required this.unique});

  final String name;
  final List<String> columns;
  final bool unique;
}

/// A row class (`<Entity>Row extends DwTableRow`) the generator writes a
/// mixin, a `copyWith` and a table definition for.
final class EntityClass {
  const EntityClass({
    required this.name,
    required this.superclass,
    required this.tableName,
    required this.fields,
    required this.indexes,
    required this.element,
  });

  final String name;

  /// The `extends` clause as written, which the mixin is declared `on`.
  final String superclass;
  final String tableName;

  /// In declaration order, `id` included.
  final List<EntityField> fields;

  /// Sorted by name, the order `DwTableSchema` keeps them in.
  final List<EntityIndex> indexes;

  final ClassElement element;

  /// The entity the row class stores: its name without the `Row` suffix,
  /// which the reader has checked is there.
  String get entityName => entityNameOf(name)!;

  /// `SessionBookingRow` → `SessionBookingTable`.
  String get tableClass => '${entityName}Table';

  /// The repository getter on the project's `DwDatabaseHandle` extension:
  /// `SessionBookingRow` → `sessionBookings`.
  String get repositoryGetter => pluralCamelCase(entityName);
}

/// The static member every row class declares its table definition in:
/// `static const tableDef = <Entity>Table();`. Named so that no row field
/// wants it (a field `table` is common: a restaurant booking has one).
const tableDefMember = 'tableDef';

/// The suffix every row class name carries.
const rowSuffix = 'Row';

/// `SessionBookingRow` → `SessionBooking`; `null` for a name that is not a
/// row class name (no `Row` suffix, or nothing before it).
///
/// The suffix is required rather than stripped when present: a row class and
/// the data object shown to clients would otherwise be free to share a name
/// (`SessionBooking` on both sides), and the table and repository names are
/// derived from the entity name, which must not depend on whether an author
/// remembered a convention.
String? entityNameOf(String className) =>
    className.length > rowSuffix.length && className.endsWith(rowSuffix)
    ? className.substring(0, className.length - rowSuffix.length)
    : null;

/// `ClubSession` → `clubSessions`, `Category` → `categories`, `Address` →
/// `addresses`.
///
/// Deliberately a plain rule, not a dictionary: the name must be predictable
/// from the class name alone (`Person` → `persons`). A getter that reads
/// badly is fixed by renaming the class, never by a lookup table nobody can
/// see.
String pluralCamelCase(String className) {
  final camel = _lowerCamel(className);
  final lower = camel.toLowerCase();
  if (RegExp(r'[^aeiou]y$').hasMatch(lower)) {
    return '${camel.substring(0, camel.length - 1)}ies';
  }
  if (RegExp(r'(s|x|z|ch|sh)$').hasMatch(lower)) return '${camel}es';
  return '${camel}s';
}

/// `ClubSession` → `clubSession`, `URLVisit` → `urlVisit`.
String _lowerCamel(String className) {
  var upper = 0;
  while (upper < className.length &&
      className[upper] != className[upper].toLowerCase()) {
    upper++;
  }
  if (upper == 0) return className;
  // In `URLVisit` the last capital starts the next word.
  final lowered = upper > 1 && upper < className.length ? upper - 1 : upper;
  return className.substring(0, lowered).toLowerCase() +
      className.substring(lowered);
}

/// `previousSessionId` → `previous_session_id`, `userID` → `user_id`,
/// `httpServer` → `http_server`, `HTTPServer` → `http_server`.
String snakeCase(String identifier) => identifier
    .replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
      (_) => '_',
    )
    .toLowerCase();
