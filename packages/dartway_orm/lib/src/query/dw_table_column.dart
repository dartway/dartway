import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../entity/dw_annotations.dart';
import '../entity/dw_column_type.dart';
import '../schema/dw_database_schema.dart';

/// A column of a table, typed by the Dart value it holds.
///
/// A column is the single declaration of everything about one field: its SQL
/// name, how its values are stored, and its schema (nullability comes from
/// `T` itself). Queries, codecs and the schema all read the same object.
///
/// Expressions that make sense only for some types are extensions constrained
/// on `T` (see [DwComparableColumn], [DwStringColumn]), so `gt` on a `bool` or
/// `like` on a `DateTime` does not compile.
final class DwTableColumn<T> {
  const DwTableColumn(
    this.name,
    this.type, {
    this.unique = false,
    this.defaultValue,
    this.references,
  }) : primaryKey = false;

  const DwTableColumn._primaryKey(this.name, this.type)
    : primaryKey = true,
      unique = false,
      defaultValue = null,
      references = null;

  /// The `id bigserial primary key` every table has.
  static const DwTableColumn<int> id = DwTableColumn<int>._primaryKey(
    'id',
    DwColumnType.bigint,
  );

  final String name;
  final DwColumnType<T> type;
  final bool primaryKey;
  final bool unique;
  final DwDefaultValue? defaultValue;
  final DwForeignKey? references;

  bool get nullable => null is T;

  DwColumnSchema get schema => DwColumnSchema(
    name,
    type.sqlType,
    nullable: nullable,
    primaryKey: primaryKey,
    unique: unique,
    defaultSql: defaultValue?.sql,
    references: references,
  );

  /// `null` matches rows where the column is null.
  DwWhereCondition equals(T value) => value == null
      ? _DwNullTest(this, isNull: true)
      : _DwComparison(this, '=', value);

  /// Dart semantics: a null cell is not equal to any value, so it matches.
  DwWhereCondition notEquals(T value) => value == null
      ? _DwNullTest(this, isNull: false)
      : _DwComparison(this, nullable ? 'IS DISTINCT FROM' : '<>', value);

  DwWhereCondition isNull() => _DwNullTest(this, isNull: true);

  DwWhereCondition isNotNull() => _DwNullTest(this, isNull: false);

  DwOrderTerm asc() => DwOrderTerm._(this, descending: false);

  DwOrderTerm desc() => DwOrderTerm._(this, descending: true);

  /// An assignment for `updateWhere`.
  DwColumnAssignment<T> set(T value) => DwColumnAssignment._(this, value);

  @internal
  String get sql => dwQuoteIdentifier(name);

  @internal
  String encodeParameter(DwSqlWriter writer, T value) => value == null
      ? writer.parameter(null, type.parameterType)
      : writer.parameter(type.encode(value), type.parameterType);

  @override
  String toString() => 'DwTableColumn<$T>($name)';
}

/// Membership tests. The values are non-null by type: SQL `IN` never matches a
/// null, so accepting one would read as a filter and silently match nothing.
extension DwColumnMembership<T extends Object> on DwTableColumn<T?> {
  /// One array parameter whatever the length, so the statement is prepared
  /// once and reused for every list size.
  DwWhereCondition inList(Iterable<T> values) =>
      _DwMembership(this, values.toList(growable: false), negated: false);

  DwWhereCondition notInList(Iterable<T> values) =>
      _DwMembership(this, values.toList(growable: false), negated: true);
}

/// Ordering comparisons, for types whose Dart ordering matches the SQL one.
extension DwComparableColumn<T extends Comparable<Object?>>
    on DwTableColumn<T?> {
  DwWhereCondition gt(T value) => _DwComparison(this, '>', value);

  DwWhereCondition gte(T value) => _DwComparison(this, '>=', value);

  DwWhereCondition lt(T value) => _DwComparison(this, '<', value);

  DwWhereCondition lte(T value) => _DwComparison(this, '<=', value);

  /// Inclusive on both ends, as SQL `BETWEEN`.
  DwWhereCondition between(T low, T high) => _DwBetween(this, low, high);
}

extension DwStringColumn on DwTableColumn<String?> {
  DwWhereCondition like(String pattern) => _DwComparison(this, 'LIKE', pattern);

  DwWhereCondition ilike(String pattern) =>
      _DwComparison(this, 'ILIKE', pattern);
}

/// A boolean condition over one table's columns.
///
/// Values are always bound parameters; nothing a caller passes is ever spliced
/// into SQL text.
///
/// Null follows Dart, not SQL three-valued logic: a comparison against a null
/// cell is false, and [not] of it is true. `NOT` is therefore written as
/// `IS NOT TRUE`, which is exactly that.
sealed class DwWhereCondition {
  const DwWhereCondition();

  DwWhereCondition operator &(DwWhereCondition other) =>
      _DwJunction(this, 'AND', other);

  DwWhereCondition operator |(DwWhereCondition other) =>
      _DwJunction(this, 'OR', other);

  DwWhereCondition not() => _DwNot(this);

  @internal
  void write(DwSqlWriter writer);
}

final class _DwComparison<T> extends DwWhereCondition {
  const _DwComparison(this.column, this.operator, this.value);

  final DwTableColumn<T> column;
  final String operator;
  final T value;

  @override
  void write(DwSqlWriter writer) => writer.write(
    '${column.sql} $operator ${column.encodeParameter(writer, value)}',
  );
}

final class _DwBetween<T> extends DwWhereCondition {
  const _DwBetween(this.column, this.low, this.high);

  final DwTableColumn<T> column;
  final T low;
  final T high;

  @override
  void write(DwSqlWriter writer) {
    final low = column.encodeParameter(writer, this.low);
    final high = column.encodeParameter(writer, this.high);
    writer.write('${column.sql} BETWEEN $low AND $high');
  }
}

final class _DwNullTest extends DwWhereCondition {
  const _DwNullTest(this.column, {required this.isNull});

  final DwTableColumn<Object?> column;
  final bool isNull;

  @override
  void write(DwSqlWriter writer) =>
      writer.write('${column.sql} ${isNull ? 'IS NULL' : 'IS NOT NULL'}');
}

final class _DwMembership<T extends Object> extends DwWhereCondition {
  const _DwMembership(this.column, this.values, {required this.negated});

  final DwTableColumn<T?> column;
  final List<T> values;
  final bool negated;

  @override
  void write(DwSqlWriter writer) {
    final type = column.type;
    final parameter = writer.parameter([
      for (final value in values) type.encodeArrayElement(value),
    ], type.arrayParameterType);
    final cast = type.arrayElementCast;
    final array = cast == null ? parameter : 'CAST($parameter AS $cast[])';
    final test = '${column.sql} = ANY($array)';
    writer.write(negated ? '($test) IS NOT TRUE' : test);
  }
}

final class _DwJunction extends DwWhereCondition {
  const _DwJunction(this.left, this.operator, this.right);

  final DwWhereCondition left;
  final String operator;
  final DwWhereCondition right;

  @override
  void write(DwSqlWriter writer) {
    writer.write('(');
    left.write(writer);
    writer.write(' $operator ');
    right.write(writer);
    writer.write(')');
  }
}

final class _DwNot extends DwWhereCondition {
  const _DwNot(this.inner);

  final DwWhereCondition inner;

  @override
  void write(DwSqlWriter writer) {
    writer.write('(');
    inner.write(writer);
    writer.write(') IS NOT TRUE');
  }
}

/// One `ORDER BY` term.
final class DwOrderTerm {
  const DwOrderTerm._(this.column, {required this.descending});

  final DwTableColumn<Object?> column;
  final bool descending;

  @internal
  String get sql => descending ? '${column.sql} DESC' : column.sql;
}

/// One `SET` of `updateWhere`: a value ([DwTableColumn.set]) or an amount
/// added to the column's current value ([DwNumberColumn.increment]).
final class DwColumnAssignment<T> {
  const DwColumnAssignment._(this.column, this.value) : _adds = false;

  const DwColumnAssignment._adding(this.column, this.value) : _adds = true;

  final DwTableColumn<T> column;

  /// The value set, or the amount added.
  final T value;

  /// Whether [value] is added to the current value rather than replacing it.
  final bool _adds;

  @internal
  void write(DwSqlWriter writer) {
    final parameter = column.encodeParameter(writer, value);
    writer.write(
      _adds
          ? '${column.sql} = ${column.sql} + $parameter'
          : '${column.sql} = $parameter',
    );
  }
}

/// Arithmetic assignments on a non-null number column.
///
/// Computed by the database in the `UPDATE` itself, so concurrent increments
/// all count: reading a counter, adding one and writing it back loses the
/// increments another transaction made in between, and a raw
/// `SET n = n + 1` was the only way around that. Not offered on a nullable
/// column, where `NULL + 1` is `NULL` and "treat null as zero" would be a
/// decision hidden in the ORM.
extension DwNumberColumn<N extends num> on DwTableColumn<N> {
  /// `column = column + amount` — a negative amount decrements.
  DwColumnAssignment<N> increment(N amount) =>
      DwColumnAssignment._adding(this, amount);
}

/// Accumulates a statement's text with its positional parameters and their
/// types.
///
/// Types travel with the statement, so the server never infers them and a
/// prepared statement stays valid for every later value of the same shape.
@internal
final class DwSqlWriter {
  final StringBuffer _sql = StringBuffer();
  final List<Object?> values = [];
  final List<pg.Type<Object>> types = [];

  void write(String text) => _sql.write(text);

  /// Registers a parameter and returns its placeholder.
  String parameter(Object? value, pg.Type<Object> type) {
    values.add(value);
    types.add(type);
    return '\$${values.length}';
  }

  String get sql => _sql.toString();
}

/// Quotes an SQL identifier. Every identifier the ORM writes is quoted, so a
/// column called `key`, `order` or `user` needs no special handling.
@internal
String dwQuoteIdentifier(String identifier) =>
    '"${identifier.replaceAll('"', '""')}"';
