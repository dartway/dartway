import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../db/dw_database_handle.dart';
import '../db/dw_errors.dart';
import '../entity/dw_table_row.dart';
import '../entity/dw_table_def.dart';
import 'dw_table_column.dart';
import 'dw_row_lock.dart';

/// Typed access to the table of one row class through a [DwDatabaseHandle].
///
/// Every method is one statement and one round trip (two inside a transaction,
/// where the driver closes the portal). Statement text depends only on the
/// *shape* of a call — which columns, which operators — never on the
/// values, so each shape is prepared once per connection: limits, offsets and
/// `inList` values are all parameters.
final class DwTableRepository<R extends DwTableRow, T extends DwTableDef<R>> {
  @internal
  DwTableRepository.internal(this._db, this.table);

  final DwDatabaseHandle _db;
  final T table;

  _DwTableSql get _sql => _DwTableSql.of(table);

  /// Rows matching [where], in [orderBy] order.
  ///
  /// Without [orderBy] the order is whatever the database returns; paging
  /// with [limit] and [offset] needs an order to be stable.
  Future<List<R>> find({
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    int? limit,
    int? offset,
    DwRowLock? lock,
  }) async {
    _checkLock(lock);
    final writer = DwSqlWriter()..write(_sql.select);
    _writeWhere(writer, where);
    if (orderBy != null) {
      final terms = orderBy(table);
      if (terms.isNotEmpty) {
        writer.write(' ORDER BY ${terms.map((term) => term.sql).join(', ')}');
      }
    }
    if (limit != null) {
      RangeError.checkNotNegative(limit, 'limit');
      writer.write(' LIMIT ${writer.parameter(limit, pg.Type.bigInteger)}');
    }
    if (offset != null) {
      RangeError.checkNotNegative(offset, 'offset');
      writer.write(' OFFSET ${writer.parameter(offset, pg.Type.bigInteger)}');
    }
    if (lock != null) writer.write(lock.sql);
    return _decode(await _run(writer));
  }

  Future<R?> findFirst({
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    DwRowLock? lock,
  }) async {
    final rows = await find(
      where: where,
      orderBy: orderBy,
      limit: 1,
      lock: lock,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<R?> findById(int id, {DwRowLock? lock}) async {
    _checkLock(lock);
    final result = await _db.run(
      lock == null ? _sql.selectById : '${_sql.selectById}${lock.sql}',
      const [pg.Type.bigInteger],
      [id],
    );
    return result.isEmpty ? null : _decode(result).first;
  }

  /// The rows with [ids], in one statement whatever their number. Missing ids
  /// are absent from the result; the order is unspecified — index the result
  /// by id.
  Future<List<R>> findByIds(Iterable<int> ids) async {
    final distinct = ids.toSet();
    if (distinct.isEmpty) return const [];
    final result = await _db.run(
      _sql.selectByIds,
      const [pg.Type.bigIntegerArray],
      [distinct.toList(growable: false)],
    );
    return _decode(result);
  }

  /// The number of rows matching [where] — or, with [distinct], of the
  /// distinct non-null values that column holds among them: members, not
  /// their entries.
  Future<int> count({
    DwWhereCondition Function(T t)? where,
    DwTableColumn<Object?> Function(T t)? distinct,
  }) async {
    final writer = DwSqlWriter()
      ..write(
        distinct == null
            ? _sql.count
            : 'SELECT count(DISTINCT ${distinct(table).sql}) FROM ${_sql.table}',
      );
    _writeWhere(writer, where);
    final result = await _run(writer);
    return result.first.first! as int;
  }

  /// [count] per value of [group]: a group with no rows is absent, not 0.
  Future<Map<K, int>> countBy<K>(
    DwTableColumn<K> Function(T t) group, {
    DwWhereCondition Function(T t)? where,
    DwTableColumn<Object?> Function(T t)? distinct,
  }) => _grouped(
    group(table),
    distinct == null ? 'count(*)' : 'count(DISTINCT ${distinct(table).sql})',
    (raw) => raw! as int,
    where,
  );

  /// The sum of [of] over the rows matching [where]; 0 when there are none,
  /// and null cells count as nothing.
  Future<N> sum<N extends num>(
    DwTableColumn<N?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) async {
    final column = of(table);
    final writer = DwSqlWriter()
      ..write('SELECT ${_sumOf(column)} AS "dw_value" FROM ${_sql.table}');
    _writeWhere(writer, where);
    return column.type.decode((await _run(writer)).first.first!) as N;
  }

  /// [sum] per value of [group].
  Future<Map<K, N>> sumBy<K, N extends num>(
    DwTableColumn<K> Function(T t) group,
    DwTableColumn<N?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) {
    final column = of(table);
    return _grouped(
      group(table),
      _sumOf(column),
      (raw) => column.type.decode(raw!) as N,
      where,
    );
  }

  /// The greatest value of [of] among the rows matching [where]; `null` when
  /// there is none — no rows, or only null cells.
  Future<V?> max<V extends Comparable<Object?>>(
    DwTableColumn<V?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) => _extreme('max', of(table), where);

  /// The least value of [of]; see [max].
  Future<V?> min<V extends Comparable<Object?>>(
    DwTableColumn<V?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) => _extreme('min', of(table), where);

  /// [max] per value of [group]; a group whose cells are all null is absent.
  Future<Map<K, V>> maxBy<K, V extends Comparable<Object?>>(
    DwTableColumn<K> Function(T t) group,
    DwTableColumn<V?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) => _groupedExtreme('max', group(table), of(table), where);

  /// [min] per value of [group]; see [maxBy].
  Future<Map<K, V>> minBy<K, V extends Comparable<Object?>>(
    DwTableColumn<K> Function(T t) group,
    DwTableColumn<V?> Function(T t) of, {
    DwWhereCondition Function(T t)? where,
  }) => _groupedExtreme('min', group(table), of(table), where);

  /// The first row of each value of [group], in [orderBy] order, among the
  /// rows matching [where]: the latest plan of each member, the last message
  /// of each conversation — one statement (`DISTINCT ON`), however many
  /// groups.
  Future<Map<K, R>> findFirstPer<K>(
    DwTableColumn<K> Function(T t) group, {
    required List<DwOrderTerm> Function(T t) orderBy,
    DwWhereCondition Function(T t)? where,
  }) async {
    final key = group(table);
    final terms = orderBy(table);
    final writer = DwSqlWriter()
      ..write(
        _sql.select.replaceFirst('SELECT ', 'SELECT DISTINCT ON (${key.sql}) '),
      );
    _writeWhere(writer, where);
    writer.write(
      ' ORDER BY ${[key.sql, for (final term in terms) term.sql].join(', ')}',
    );
    final result = await _run(writer);
    return {
      for (final row in dwResultRows(result))
        row.decode(key): table.fromRow(row),
    };
  }

  Future<bool> exists({DwWhereCondition Function(T t)? where}) async {
    final writer = DwSqlWriter()
      ..write('SELECT EXISTS (SELECT 1 FROM ${_sql.table}');
    _writeWhere(writer, where);
    writer.write(')');
    final result = await _run(writer);
    return result.first.first! as bool;
  }

  /// Inserts [row] and returns it as stored, with its id and every value
  /// read back from the database.
  Future<R> insert(R row) async {
    final result = await _insert(row, '');
    return _decode(result).first;
  }

  /// Inserts [row] unless it conflicts; returns `null` when the row was
  /// skipped.
  Future<R?> tryInsert(R row, {required DwOnConflict<T> onConflict}) async {
    final result = await _insert(row, onConflict.sql(table));
    return result.isEmpty ? null : _decode(result).first;
  }

  /// Inserts all [rows] in one statement and returns them as stored, in the
  /// same order.
  ///
  /// Either every row has an id or none has: the statement binds one array
  /// per column, and a column cannot be half defaulted.
  Future<List<R>> insertAll(Iterable<R> rows) async {
    final list = rows.toList(growable: false);
    if (list.isEmpty) return const [];
    final withId = list.first.id != null;
    if (list.any((row) => (row.id != null) != withId)) {
      throw ArgumentError('insertAll: either every row has an id or none has');
    }
    final columns = _sql.insertColumns(withId: withId);
    final arrays = [for (final _ in columns) <Object?>[]];
    for (final row in list) {
      final values = _valuesOf(row);
      for (final (position, column) in columns.indexed) {
        final value = values[column.name];
        arrays[position].add(
          value == null ? null : column.type.encodeArrayElement(value),
        );
      }
    }
    final result = await _db.run(_sql.insertAll(withId: withId), [
      for (final column in columns) column.type.arrayParameterType,
    ], arrays);
    return _decode(result);
  }

  /// Writes every column of [row] by its id and returns the stored row.
  ///
  /// Throws [DwRowNotFound] when no row has that id: an update that
  /// changed nothing is a failure, not a quiet success.
  Future<R> update(R row) async {
    final id = row.id;
    if (id == null) {
      throw ArgumentError('update: the row has no id; insert it first');
    }
    final values = _valuesOf(row);
    final columns = _sql.insertColumns(withId: false);
    final result = await _db.run(
      _sql.updateById,
      [
        for (final column in columns) column.type.parameterType,
        pg.Type.bigInteger,
      ],
      [for (final column in columns) _encode(column, values[column.name]), id],
    );
    if (result.isEmpty) throw DwRowNotFound(table.tableName, id);
    return _decode(result).first;
  }

  /// Sets columns on every row matching [where]; returns the number of rows.
  Future<int> updateWhere({
    required DwWhereCondition Function(T t) where,
    required List<DwColumnAssignment<Object?>> Function(T t) set,
  }) async {
    return (await _run(_updateWhere(where, set))).affectedRows;
  }

  /// [updateWhere], answering the rows as they are after it: what changed,
  /// to publish, without reading it back in a second statement.
  Future<List<R>> updateWhereReturning({
    required DwWhereCondition Function(T t) where,
    required List<DwColumnAssignment<Object?>> Function(T t) set,
  }) async {
    final writer = _updateWhere(where, set)..write(_sql.returning);
    return _decode(await _run(writer));
  }

  /// Inserts [row], or — when it conflicts on the unique [conflictOn]
  /// columns — writes every other column of it over the row already there;
  /// returns the stored row either way.
  ///
  /// The single-row settings, the per-member answer written again: one
  /// statement, with no window between "not there" and "insert" for a
  /// concurrent writer to fall into.
  Future<R> upsert(
    R row, {
    required List<DwTableColumn<Object?>> Function(T t) conflictOn,
  }) async {
    final target = conflictOn(table);
    if (target.isEmpty) throw ArgumentError('upsert: no conflict columns');
    final names = {for (final column in target) column.name};
    final written = [
      for (final column in _sql.insertColumns(withId: false))
        if (!names.contains(column.name)) column,
    ];
    // With nothing but the key to write, the key itself is set to what it
    // already is: `DO NOTHING` would return no row to answer with.
    final set = [
      for (final column in written.isEmpty ? target : written)
        '${column.sql} = EXCLUDED.${column.sql}',
    ];
    final result = await _insert(
      row,
      ' ON CONFLICT (${target.map((column) => column.sql).join(', ')}) '
      'DO UPDATE SET ${set.join(', ')}',
    );
    return _decode(result).first;
  }

  /// Deletes the row with [id]; returns 1, or 0 when there was none.
  Future<int> delete(int id) async => (await _db.run(
    _sql.deleteById,
    const [pg.Type.bigInteger],
    [id],
  )).affectedRows;

  Future<int> deleteWhere({
    required DwWhereCondition Function(T t) where,
  }) async {
    final writer = DwSqlWriter()..write('DELETE FROM ${_sql.table}');
    _writeWhere(writer, where);
    return (await _run(writer)).affectedRows;
  }

  DwSqlWriter _updateWhere(
    DwWhereCondition Function(T t) where,
    List<DwColumnAssignment<Object?>> Function(T t) set,
  ) {
    final assignments = set(table);
    if (assignments.isEmpty) {
      throw ArgumentError('updateWhere: nothing to set');
    }
    final writer = DwSqlWriter()..write('UPDATE ${_sql.table} SET ');
    for (final (position, assignment) in assignments.indexed) {
      if (position > 0) writer.write(', ');
      assignment.write(writer);
    }
    _writeWhere(writer, where);
    return writer;
  }

  /// `SUM` in the column's own type — Postgres widens a `bigint` sum to
  /// `numeric` — and 0 rather than null over no rows.
  String _sumOf(DwTableColumn<Object?> column) =>
      'CAST(COALESCE(sum(${column.sql}), 0) AS ${column.type.sqlType})';

  Future<V?> _extreme<V>(
    String function,
    DwTableColumn<V?> column,
    DwWhereCondition Function(T t)? where,
  ) async {
    final writer = DwSqlWriter()
      ..write('SELECT $function(${column.sql}) FROM ${_sql.table}');
    _writeWhere(writer, where);
    final raw = (await _run(writer)).first.first;
    return raw == null ? null : column.type.decode(raw);
  }

  Future<Map<K, V>> _groupedExtreme<K, V extends Object>(
    String function,
    DwTableColumn<K> group,
    DwTableColumn<V?> column,
    DwWhereCondition Function(T t)? where,
  ) async {
    final all = await _grouped<K, V?>(
      group,
      '$function(${column.sql})',
      (raw) => raw == null ? null : column.type.decode(raw),
      where,
    );
    return {for (final MapEntry(:key, :value) in all.entries) key: ?value};
  }

  /// `SELECT group, aggregate … GROUP BY group`, keyed by the group's value.
  Future<Map<K, V>> _grouped<K, V>(
    DwTableColumn<K> group,
    String aggregate,
    V Function(Object? raw) decode,
    DwWhereCondition Function(T t)? where,
  ) async {
    final writer = DwSqlWriter()
      ..write(
        'SELECT ${group.sql}, $aggregate AS "dw_value" FROM ${_sql.table}',
      );
    _writeWhere(writer, where);
    writer.write(' GROUP BY ${group.sql}');
    return {
      for (final row in dwResultRows(await _run(writer)))
        row.decode(group): decode(row['dw_value']),
    };
  }

  Future<pg.Result> _insert(R row, String onConflict) {
    final withId = row.id != null;
    final values = _valuesOf(row);
    final columns = _sql.insertColumns(withId: withId);
    return _db.run(
      '${_sql.insert(withId: withId)}$onConflict${_sql.returning}',
      [for (final column in columns) column.type.parameterType],
      [for (final column in columns) _encode(column, values[column.name])],
    );
  }

  Map<String, Object?> _valuesOf(R row) {
    final values = table.toRow(row);
    for (final column in _sql.insertColumns(withId: row.id != null)) {
      if (!values.containsKey(column.name)) {
        throw StateError(
          '${table.tableName}.toRow has no value for "${column.name}"; regenerate the table',
        );
      }
    }
    return values;
  }

  Object? _encode(DwTableColumn<Object?> column, Object? value) =>
      value == null ? null : column.type.encode(value);

  void _checkLock(DwRowLock? lock) {
    if (lock != null && !_db.inTransaction) {
      throw StateError(
        '${lock.name} on "${table.tableName}" needs a transaction: outside one the '
        'row lock ends with the statement',
      );
    }
  }

  void _writeWhere(DwSqlWriter writer, DwWhereCondition Function(T t)? where) {
    if (where == null) return;
    writer.write(' WHERE ');
    where(table).write(writer);
  }

  Future<pg.Result> _run(DwSqlWriter writer) =>
      _db.run(writer.sql, writer.types, writer.values);

  List<R> _decode(pg.Result result) => [
    for (final row in dwResultRows(result)) table.fromRow(row),
  ];

  @override
  String toString() => 'DwTableRepository(${table.tableName})';
}

/// Statement text of a table that does not depend on a call, built once per
/// table object.
final class _DwTableSql {
  _DwTableSql(DwTableDef table)
    : table = dwQuoteIdentifier(table.tableName),
      columns = List.unmodifiable(table.tableColumns) {
    if (columns.isEmpty || !columns.first.primaryKey) {
      throw StateError(
        '${table.tableName}.tableColumns must start with the id column',
      );
    }
    final list = columns.map((column) => column.sql).join(', ');
    returning = ' RETURNING $list';
    select = 'SELECT $list FROM ${this.table}';
    selectById = '$select WHERE "id" = \$1';
    selectByIds = '$select WHERE "id" = ANY(\$1)';
    count = 'SELECT count(*) FROM ${this.table}';
    deleteById = 'DELETE FROM ${this.table} WHERE "id" = \$1';
    final values = columns.skip(1).toList();
    updateById =
        'UPDATE ${this.table} SET '
        '${[for (final (i, column) in values.indexed) '${column.sql} = \$${i + 1}'].join(', ')} '
        'WHERE "id" = \$${values.length + 1}$returning';
  }

  static final Expando<_DwTableSql> _cache = Expando('DwTableSql');

  static _DwTableSql of(DwTableDef table) =>
      _cache[table] ??= _DwTableSql(table);

  final String table;
  final List<DwTableColumn<Object?>> columns;
  late final String returning;
  late final String select;
  late final String selectById;
  late final String selectByIds;
  late final String count;
  late final String deleteById;
  late final String updateById;

  late final List<DwTableColumn<Object?>> _withoutId = List.unmodifiable(
    columns.skip(1),
  );

  List<DwTableColumn<Object?>> insertColumns({required bool withId}) =>
      withId ? columns : _withoutId;

  late final String _insertWithId = _insertInto(columns);
  late final String _insertWithoutId = _insertInto(_withoutId);

  String insert({required bool withId}) =>
      withId ? _insertWithId : _insertWithoutId;

  String _insertInto(List<DwTableColumn<Object?>> columns) =>
      'INSERT INTO $table (${columns.map((column) => column.sql).join(', ')}) '
      'VALUES (${[for (var i = 1; i <= columns.length; i++) '\$$i'].join(', ')})';

  late final String _insertAllWithId = _insertAllInto(columns);
  late final String _insertAllWithoutId = _insertAllInto(_withoutId);

  String insertAll({required bool withId}) =>
      withId ? _insertAllWithId : _insertAllWithoutId;

  /// One array per column, zipped by `unnest` and kept in input order by
  /// its ordinality, so the returned rows line up with the rows given.
  String _insertAllInto(List<DwTableColumn<Object?>> columns) {
    final names = columns.map((column) => column.sql).join(', ');
    final aliases = [for (var i = 1; i <= columns.length; i++) 'c$i'];
    final arrays = [for (var i = 1; i <= columns.length; i++) '\$$i'];
    final selected = [
      for (final (i, column) in columns.indexed)
        switch (column.type.arrayElementCast) {
          null => aliases[i],
          final cast => 'CAST(${aliases[i]} AS $cast)',
        },
    ];
    return 'INSERT INTO $table ($names) '
        'SELECT ${selected.join(', ')} FROM unnest(${arrays.join(', ')}) '
        'WITH ORDINALITY AS input(${aliases.join(', ')}, position) '
        'ORDER BY position$returning';
  }
}
