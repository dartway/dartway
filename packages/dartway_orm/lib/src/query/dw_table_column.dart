import 'package:meta/meta.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:postgres/postgres.dart' as pg;

import '../entity/dw_annotations.dart';
import 'dw_table_relation.dart';
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
    this.transitions,
    this.relationPath,
  }) : primaryKey = false;

  const DwTableColumn._primaryKey(this.name, this.type)
    : primaryKey = true,
      unique = false,
      defaultValue = null,
      references = null,
      transitions = null,
      relationPath = null;

  /// The `id bigserial primary key` every table has.
  static const DwTableColumn<int> id = DwTableColumn<int>._primaryKey(
    'id',
    DwColumnType.bigint,
  );

  final DwRelationPath? relationPath;

  /// Used by generated table definitions; leaves schema and codecs unchanged.
  DwTableColumn<T> atPath(DwRelationPath? path) => path == null
      ? this
      : DwTableColumn<T>(
          name,
          type,
          unique: unique,
          defaultValue: defaultValue,
          references: references,
          transitions: transitions,
          relationPath: path,
        );

  final String name;
  final DwColumnType<T> type;
  final bool primaryKey;
  final bool unique;
  final DwDefaultValue? defaultValue;
  final DwForeignKey? references;

  /// Legal state writes, generated from `@DwStateColumn`.
  final DwStateTransitions<T>? transitions;

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
      : _DwComparison(
          this,
          nullable || relationPath != null ? 'IS DISTINCT FROM' : '<>',
          value,
        );

  DwWhereCondition isNull() => _DwNullTest(this, isNull: true);

  DwWhereCondition isNotNull() => _DwNullTest(this, isNull: false);

  DwOrderTerm asc() => DwOrderTerm._(this, descending: false);

  DwOrderTerm desc() => DwOrderTerm._(this, descending: true);

  /// An assignment for `updateWhere`.
  DwColumnAssignment<T> set(T value) => DwColumnAssignment._(this, value);

  @internal
  String get sql => dwQuoteIdentifier(name);

  @internal
  String sqlIn(DwSqlWriter writer) => writer.column(name, relationPath);

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

/// Conditions on a list column stored as a `jsonb` array (`List<int>` of
/// file ids, `List<E>` of an enum): what used to need raw SQL over
/// `jsonb_array_length` and `jsonb_array_elements`.
extension DwListColumn<E> on DwTableColumn<List<E>?> {
  /// The list holds no element. A null cell is neither empty nor not.
  DwWhereCondition isEmptyList() => _DwListLength(this, empty: true);

  /// The list holds at least one element.
  DwWhereCondition isNotEmptyList() => _DwListLength(this, empty: false);

  /// The list holds [value].
  DwWhereCondition contains(E value) => containsAny([value]);

  /// The list holds at least one of [values]; never true for no values.
  DwWhereCondition containsAny(Iterable<E> values) =>
      _DwListOverlap(this, values.toList(growable: false));
}

final class _DwListLength extends DwWhereCondition {
  const _DwListLength(this.column, {required this.empty});

  final DwTableColumn<Object?> column;
  final bool empty;

  @override
  void write(DwSqlWriter writer) => writer.write(
    'jsonb_array_length(${column.sqlIn(writer)}) ${empty ? '= 0' : '> 0'}',
  );
}

final class _DwListOverlap<E> extends DwWhereCondition {
  const _DwListOverlap(this.column, this.values);

  final DwTableColumn<List<E>?> column;
  final List<E> values;

  @override
  void write(DwSqlWriter writer) {
    // The values travel as one jsonb array, encoded by the column's own type
    // (an enum list stores names), and match element by element.
    final parameter = writer.parameter(
      column.type.encode(values),
      pg.Type.jsonb,
    );
    writer.write(
      'EXISTS (SELECT 1 FROM jsonb_array_elements(${column.sqlIn(writer)}) AS dw_held '
      'JOIN jsonb_array_elements($parameter) AS dw_wanted '
      'ON dw_held.value = dw_wanted.value)',
    );
  }
}

/// A boolean condition over one table's columns.
///
/// Values are always bound parameters; nothing a caller passes is ever spliced
/// into SQL text.
///
/// Null follows Dart, not SQL three-valued logic: a comparison against a null
/// cell is false, and [not] of it is true. `NOT` is therefore written as
/// `IS NOT TRUE`, which is exactly that.
abstract class DwWhereCondition {
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
    '${column.sqlIn(writer)} $operator ${column.encodeParameter(writer, value)}',
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
    writer.write('${column.sqlIn(writer)} BETWEEN $low AND $high');
  }
}

final class _DwNullTest extends DwWhereCondition {
  const _DwNullTest(this.column, {required this.isNull});

  final DwTableColumn<Object?> column;
  final bool isNull;

  @override
  void write(DwSqlWriter writer) => writer.write(
    '${column.sqlIn(writer)} ${isNull ? 'IS NULL' : 'IS NOT NULL'}',
  );
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
    final test = '${column.sqlIn(writer)} = ANY($array)';
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
  String sqlIn(DwSqlWriter writer) =>
      descending ? '${column.sqlIn(writer)} DESC' : column.sqlIn(writer);
}

/// One `SET` of `updateWhere`: a value ([DwTableColumn.set]) or an amount
/// added to the column's current value ([DwNumberColumn.increment]).
final class DwColumnAssignment<T> {
  const DwColumnAssignment._(this.column, this.value) : _kind = _Assign.set;

  const DwColumnAssignment._adding(this.column, this.value)
    : _kind = _Assign.add;

  const DwColumnAssignment._ifNull(this.column, this.value)
    : _kind = _Assign.ifNull;

  final DwTableColumn<T> column;

  /// The value set, the amount added, or the value a null cell takes.
  final T value;

  final _Assign _kind;

  @internal
  void write(DwSqlWriter writer) {
    final parameter = column.encodeParameter(writer, value);
    final name = column.sql;
    writer.write(switch (_kind) {
      _Assign.set => '$name = $parameter',
      _Assign.add => '$name = $name + $parameter',
      _Assign.ifNull => '$name = COALESCE($name, $parameter)',
    });
  }
}

enum _Assign { set, add, ifNull }

/// Assignments on a nullable column.
extension DwNullableColumn<V extends Object> on DwTableColumn<V?> {
  /// `column = COALESCE(column, value)`: sets [value] where the cell is null
  /// and leaves a value that is there — in the same statement as the rest of
  /// the update, rather than a second `updateWhere` limited to null cells.
  DwColumnAssignment<V?> setIfNull(V value) =>
      DwColumnAssignment._ifNull(this, value);
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
  DwSqlWriter({
    this.rootTable,
    String? rootAlias,
    List<Object?>? values,
    List<pg.Type<Object>>? types,
    Set<String>? aliases,
    DwSqlWriter? joinOwner,
    DwRelationPath? basePath,
  }) : rootAlias = rootAlias ?? rootTable,
       values = values ?? [],
       types = types ?? [],
       _usedAliases = aliases ?? {?rootTable},
       _joinOwner = joinOwner,
       _basePath = basePath;

  final Set<String> _usedAliases;
  final DwSqlWriter? _joinOwner;
  final DwRelationPath? _basePath;
  final String? rootTable;
  final String? rootAlias;
  final StringBuffer _sql = StringBuffer();
  final List<Object?> values;
  final List<pg.Type<Object>> types;
  final Map<String, String> _aliases = {};
  final List<String> joins = [];

  void write(String text) => _sql.write(text);

  DwSqlWriter scope(String table, String alias) => DwSqlWriter(
    rootTable: table,
    rootAlias: alias,
    values: values,
    types: types,
    aliases: _usedAliases,
  );

  DwSqlWriter relatedScope(DwRelationPath path) => DwSqlWriter(
    rootTable: path.targetTable,
    rootAlias: relationAlias(path),
    values: values,
    types: types,
    aliases: _usedAliases,
    joinOwner: this,
    basePath: path,
  );

  String nextAlias() {
    var i = _usedAliases.length;
    while (!_usedAliases.add('dw_rel_$i')) {
      i++;
    }
    return 'dw_rel_$i';
  }

  String column(String name, DwRelationPath? path) {
    final alias = path == null ? rootAlias : relationAlias(path);
    return alias == null
        ? dwQuoteIdentifier(name)
        : '${dwQuoteIdentifier(alias)}.${dwQuoteIdentifier(name)}';
  }

  String relationAlias(DwRelationPath path) {
    if (path.many) {
      throw ArgumentError('a to-many path needs any/none/every/count');
    }
    final owner = _joinOwner;
    if (owner != null) {
      return owner.relationAlias(_prependPath(path, _basePath!));
    }
    return _aliases.putIfAbsent(path.key, () {
      final parent = path.parent == null
          ? rootAlias!
          : relationAlias(path.parent!);
      final alias = nextAlias();
      joins.add(
        'LEFT JOIN ${dwQuoteIdentifier(path.targetTable)} '
        '${dwQuoteIdentifier(alias)} ON ${dwQuoteIdentifier(parent)}.'
        '${dwQuoteIdentifier(path.foreignKey)} = ${dwQuoteIdentifier(alias)}."id"',
      );
      return alias;
    });
  }

  static DwRelationPath _prependPath(
    DwRelationPath path,
    DwRelationPath base,
  ) => DwRelationPath(
    path.sourceTable,
    path.targetTable,
    path.foreignKey,
    many: path.many,
    parent: path.parent == null ? base : _prependPath(path.parent!, base),
  );

  String parameter(Object? value, pg.Type<Object> type) {
    values.add(value);
    types.add(type);
    return '\$${values.length}';
  }

  String get sql {
    var text = _sql.toString();
    if (joins.isNotEmpty) {
      final from =
          'FROM ${dwQuoteIdentifier(rootTable!)}'
          '${rootAlias == rootTable ? '' : ' ${dwQuoteIdentifier(rootAlias!)}'}';
      text = text.replaceFirst(from, '$from ${joins.join(' ')}');
    }
    return text;
  }
}

/// Quotes an SQL identifier. Every identifier the ORM writes is quoted, so a
/// column called `key`, `order` or `user` needs no special handling.
@internal
String dwQuoteIdentifier(String identifier) =>
    '"${identifier.replaceAll('"', '""')}"';
