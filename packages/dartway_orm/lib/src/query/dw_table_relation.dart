part of 'dw_table_column.dart';

/// A generated foreign-key path. Values never enter its SQL identifiers.
final class DwRelationPath {
  const DwRelationPath(
    this.sourceTable,
    this.targetTable,
    this.foreignKey, {
    this.parent,
    this.many = false,
  });

  final String sourceTable;
  final String targetTable;
  final String foreignKey;
  final DwRelationPath? parent;
  final bool many;

  @internal
  String get key =>
      '${parent?.key ?? sourceTable}/$targetTable/$foreignKey/$many';
}

/// An explicitly selected relation; no relation ever loads lazily.
abstract interface class DwRelationInclude {
  @internal
  DwIncludeSpec get includeSpec;
}

/// A generated table token, typed by its nullable or non-null row result.
abstract interface class DwToOneRelation<R extends DwTableRow?>
    implements DwRelationInclude {}

/// The reverse side of a foreign key. Quantifiers do not multiply root rows.
final class DwToManyRelation<R extends DwTableRow, T extends DwTableDef<R>>
    implements DwRelationInclude {
  const DwToManyRelation(this._table, this.path);

  final T _table;
  final DwRelationPath path;

  DwWhereCondition any(DwWhereCondition Function(T t) where) =>
      _DwRelationTest(_table, path, where(_table), _Quantifier.any);
  DwWhereCondition none(DwWhereCondition Function(T t) where) =>
      _DwRelationTest(_table, path, where(_table), _Quantifier.none);

  /// True for no children, and when every child satisfies [where]. A null
  /// comparison is false, exactly as for ordinary ORM conditions.
  DwWhereCondition every(DwWhereCondition Function(T t) where) =>
      _DwRelationTest(_table, path, where(_table), _Quantifier.every);

  DwRelationCount count({DwWhereCondition Function(T t)? where}) =>
      DwRelationCount._(_table, path, where?.call(_table));

  DwRelationInclude take(
    int limit, {
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    List<DwRelationInclude> Function(T t)? include,
  }) {
    RangeError.checkNotNegative(limit, 'limit');
    return DwIncludeSpec(
      _table,
      path,
      limit: limit,
      where: where?.call(_table),
      orderBy: orderBy?.call(_table) ?? const [],
      nested: include?.call(_table) ?? const [],
    );
  }

  DwRelationInclude unbounded(
    String reason, {
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    List<DwRelationInclude> Function(T t)? include,
  }) {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    return DwIncludeSpec(
      _table,
      path,
      unbounded: reason,
      where: where?.call(_table),
      orderBy: orderBy?.call(_table) ?? const [],
      nested: include?.call(_table) ?? const [],
    );
  }

  /// A bare to-many include is refused: choose [take] or [unbounded].
  @override
  DwIncludeSpec get includeSpec => throw ArgumentError(
    '${path.targetTable}: to-many include needs take(n) or unbounded(reason)',
  );
}

/// A correlated count, comparable without exposing an order term.
final class DwRelationCount {
  const DwRelationCount._(this._table, this.path, this.where);
  final DwTableDef<DwTableRow> _table;
  final DwRelationPath path;
  final DwWhereCondition? where;

  DwWhereCondition equals(int value) => _compare('=', value);
  DwWhereCondition gt(int value) => _compare('>', value);
  DwWhereCondition gte(int value) => _compare('>=', value);
  DwWhereCondition lt(int value) => _compare('<', value);
  DwWhereCondition lte(int value) => _compare('<=', value);
  DwWhereCondition _compare(String op, int value) => _DwRelationTest(
    _table,
    path,
    where,
    _Quantifier.count,
    op: op,
    count: value,
  );
}

enum _Quantifier { any, none, every, count }

final class _DwRelationTest extends DwWhereCondition {
  const _DwRelationTest(
    this.table,
    this.path,
    this.where,
    this.quantifier, {
    this.op,
    this.count,
  });
  final DwTableDef<DwTableRow> table;
  final DwRelationPath path;
  final DwWhereCondition? where;
  final _Quantifier quantifier;
  final String? op;
  final int? count;

  @override
  void write(DwSqlWriter writer) {
    final parent = path.parent == null
        ? writer.rootAlias!
        : writer.relationAlias(path.parent!);
    final alias = writer.nextAlias();
    final child = writer.scope(table.tableName, alias);
    child.write(
      'SELECT ${quantifier == _Quantifier.count ? 'count(*)' : '1'} '
      'FROM ${dwQuoteIdentifier(table.tableName)} ${dwQuoteIdentifier(alias)} '
      'WHERE ${dwQuoteIdentifier(alias)}.${dwQuoteIdentifier(path.foreignKey)} = '
      '${dwQuoteIdentifier(parent)}."id"',
    );
    if (where != null) {
      child.write(' AND (');
      where!.write(child);
      child.write(quantifier == _Quantifier.every ? ') IS NOT TRUE' : ')');
    }
    writer.write(switch (quantifier) {
      _Quantifier.any => 'EXISTS (${child.sql})',
      _Quantifier.none || _Quantifier.every => 'NOT EXISTS (${child.sql})',
      _Quantifier.count =>
        '(${child.sql}) $op ${writer.parameter(count, pg.Type.bigInteger)}',
    });
  }
}

/// Generated include metadata. Application code selects generated tokens.
final class DwIncludeSpec implements DwRelationInclude {
  const DwIncludeSpec(
    this.table,
    this.path, {
    this.nested = const [],
    this.limit,
    this.unbounded,
    this.where,
    this.orderBy = const [],
  });
  final DwTableDef<DwTableRow> table;
  final DwRelationPath path;
  final List<DwRelationInclude> nested;
  final int? limit;
  final String? unbounded;
  final DwWhereCondition? where;
  final List<DwOrderTerm> orderBy;

  @override
  DwIncludeSpec get includeSpec {
    if (path.many) {
      if (limit == null && (unbounded == null || unbounded!.trim().isEmpty)) {
        throw ArgumentError(
          'to-many include needs take(n) or unbounded(reason)',
        );
      }
      if (limit != null) {
        RangeError.checkNotNegative(limit!, 'limit');
        if (unbounded != null) {
          throw ArgumentError('an include with a limit is bounded');
        }
      }
    }
    final keys = <String>{};
    for (final child in nested) {
      if (!keys.add(child.includeSpec.path.key)) {
        throw ArgumentError('a relation may only be included once per row');
      }
    }
    return this;
  }
}

final _loaded = Expando<Map<String, Object?>>('included relations');

@internal
void dwRememberIncludes(DwTableRow row, Map<String, Object?> values) =>
    _loaded[row] = Map.unmodifiable(values);

/// Explicit, typed reads of the relations selected by a repository call.
/// Reading a relation that was not selected throws, even for an empty relation.
extension DwIncludedRelations on DwTableRow {
  R one<R extends DwTableRow?>(DwToOneRelation<R> relation) =>
      _readIncluded(this, relation.includeSpec.path.key) as R;

  List<R> many<R extends DwTableRow, T extends DwTableDef<R>>(
    DwToManyRelation<R, T> relation,
  ) => (_readIncluded(this, relation.path.key)! as List).cast<R>();
}

Object? _readIncluded(DwTableRow row, String key) {
  final values = _loaded[row];
  if (values == null || !values.containsKey(key)) {
    throw StateError('relation $key was not included');
  }
  return values[key];
}

/// Projection of one included row. Each cell uses its column's JSON carrier;
/// jsonb collections remain JSON, dates and bytes get their exact adapters.
String _rowJson(
  DwSqlWriter writer,
  DwTableDef<DwTableRow> table,
  List<DwRelationInclude> nested,
) {
  final cells = [
    for (final c in table.tableColumns)
      c.type.jsonSql(writer.column(c.name, null)),
  ];
  cells.addAll([
    for (final include in nested)
      dwIncludeProjection(writer, include.includeSpec),
  ]);
  return 'json_build_array(${cells.join(', ')})';
}

@internal
String dwIncludeProjection(
  DwSqlWriter writer,
  DwIncludeSpec spec, {
  bool grouped = false,
}) {
  if (!spec.path.many) {
    final alias = writer.relationAlias(spec.path);
    final child = writer.relatedScope(spec.path);
    final json = _rowJson(child, spec.table, spec.nested);
    // Nested joins belong to the enclosing SELECT, not to a second query.
    writer.joins.addAll(child.joins);
    return 'CASE WHEN ${dwQuoteIdentifier(alias)}."id" IS NULL THEN NULL '
        'ELSE $json END';
  }
  final parent = spec.path.parent == null
      ? writer.rootAlias!
      : writer.relationAlias(spec.path.parent!);
  final alias = writer.nextAlias();
  final child = writer.scope(spec.table.tableName, alias);
  final terms = spec.orderBy.isEmpty && spec.limit != null
      ? [spec.table.id.asc()]
      : spec.orderBy;
  final json = _rowJson(child, spec.table, spec.nested);
  if (grouped && spec.limit == null) {
    final fk =
        '${dwQuoteIdentifier(alias)}.${dwQuoteIdentifier(spec.path.foreignKey)}';
    final order = spec.orderBy.isEmpty
        ? ''
        : ' ORDER BY ${terms.map((t) => t.sqlIn(child)).join(', ')}';
    child.write(
      'SELECT $fk AS "dw_parent", json_agg($json$order) AS "dw_rows" '
      'FROM ${dwQuoteIdentifier(spec.table.tableName)} ${dwQuoteIdentifier(alias)}',
    );
    if (spec.where != null) {
      child.write(' WHERE ');
      spec.where!.write(child);
    }
    child.write(' GROUP BY $fk');
    final groupedAlias = '${alias}_group';
    writer.joins.add(
      'LEFT JOIN (${child.sql}) ${dwQuoteIdentifier(groupedAlias)} '
      'ON ${dwQuoteIdentifier(groupedAlias)}."dw_parent" = ${dwQuoteIdentifier(parent)}."id"',
    );
    return "COALESCE(${dwQuoteIdentifier(groupedAlias)}.\"dw_rows\", '[]'::json)";
  }
  final orderColumns = [
    for (final (i, term) in terms.indexed)
      '${term.column.sqlIn(child)} AS "dw_order_$i"',
  ];
  child.write(
    'SELECT $json AS "dw_row"${orderColumns.isEmpty ? '' : ', ${orderColumns.join(', ')}'} '
    'FROM ${dwQuoteIdentifier(spec.table.tableName)} ${dwQuoteIdentifier(alias)} '
    'WHERE ${dwQuoteIdentifier(alias)}.${dwQuoteIdentifier(spec.path.foreignKey)} = '
    '${dwQuoteIdentifier(parent)}."id"',
  );
  if (spec.where != null) {
    child.write(' AND (');
    spec.where!.write(child);
    child.write(')');
  }
  if (terms.isNotEmpty && spec.limit != null) {
    child.write(' ORDER BY ${terms.map((t) => t.sqlIn(child)).join(', ')}');
  }
  if (spec.limit != null) {
    child.write(' LIMIT ${writer.parameter(spec.limit, pg.Type.bigInteger)}');
  }
  final aggregateOrder = terms.isEmpty
      ? ''
      : ' ORDER BY ${[for (final (i, term) in terms.indexed) '"dw_order_$i"${term.descending ? ' DESC' : ''}'].join(', ')}';
  final lateral = '${alias}_rows';
  writer.joins.add(
    'LEFT JOIN LATERAL (SELECT '
    "COALESCE(json_agg(\"dw_row\"$aggregateOrder), '[]'::json) AS \"dw_rows\" "
    'FROM (${child.sql}) ${dwQuoteIdentifier('${alias}_page')}) '
    '${dwQuoteIdentifier(lateral)} ON TRUE',
  );
  return '${dwQuoteIdentifier(lateral)}."dw_rows"';
}

DwTableRow _decodeJsonRow(DwIncludeSpec spec, Object raw) {
  final cells = raw as List;
  final columns = spec.table.tableColumns;
  final row = spec.table.fromRow(
    DwResultRow(
      {for (final (i, c) in columns.indexed) c.name: i},
      [
        for (final (i, c) in columns.indexed)
          cells[i] == null ? null : c.type.jsonCarrier(cells[i]!),
      ],
    ),
  );
  dwRememberIncludes(row, {
    for (final (i, child) in spec.nested.indexed)
      child.includeSpec.path.key: _decodeInclude(
        child.includeSpec,
        cells[columns.length + i],
      ),
  });
  return row;
}

Object? _decodeInclude(DwIncludeSpec spec, Object? raw) => spec.path.many
    ? List<DwTableRow>.unmodifiable([
        for (final child in raw! as List) _decodeJsonRow(spec, child!),
      ])
    : raw == null
    ? null
    : _decodeJsonRow(spec, raw);

@internal
void dwDecodeIncludes(
  DwTableRow row,
  List<DwIncludeSpec> specs,
  DwResultRow result,
) {
  dwRememberIncludes(row, {
    for (final (i, spec) in specs.indexed)
      spec.path.key: _decodeInclude(spec, result['dw_include_$i']),
  });
}
