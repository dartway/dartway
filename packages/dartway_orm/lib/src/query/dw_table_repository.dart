import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../db/dw_database_handle.dart';
import '../db/dw_errors.dart';
import '../db/dw_result_row.dart';
import '../entity/dw_table_row.dart';
import '../entity/dw_annotations.dart';
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
  ///
  /// [unbounded] is why a read without [limit] stays small — `'a club's
  /// coaches'` — said where the read is. `dartway check` warns about a read
  /// in a request handler with neither (`unboundedRead`); the database never
  /// sees it. It is refused beside a [limit], and blank.
  Future<List<R>> find({
    List<DwRelationInclude> Function(T t)? include,
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    int? limit,
    int? offset,
    DwRowLock? lock,
    String? unbounded,
  }) async {
    if (unbounded != null && (limit != null || unbounded.trim().isEmpty)) {
      throw ArgumentError.value(
        unbounded,
        'unbounded',
        limit != null ? 'a read with a limit is bounded' : 'says no reason',
      );
    }
    _checkLock(lock);
    if (include != null && lock != null) {
      throw ArgumentError('include cannot be combined with a row lock');
    }
    final specs =
        include?.call(table).map((i) => i.includeSpec).toList() ??
        const <DwIncludeSpec>[];
    if (specs.map((s) => s.path.key).toSet().length != specs.length) {
      throw ArgumentError('a relation may only be included once per row');
    }
    final writer = DwSqlWriter(rootTable: table.tableName);
    final projections = [
      for (final (i, spec) in specs.indexed)
        '${dwIncludeProjection(writer, spec, grouped: limit == null && offset == null && where == null)} AS "dw_include_$i"',
    ];
    writer.write(
      projections.isEmpty
          ? _sql.select
          : _sql.select.replaceFirst(
              ' FROM ',
              ', ${projections.join(', ')} FROM ',
            ),
    );
    _writeWhere(writer, where);
    if (orderBy != null) {
      final terms = orderBy(table);
      if (terms.isNotEmpty) {
        writer.write(
          ' ORDER BY ${terms.map((term) => term.sqlIn(writer)).join(', ')}',
        );
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
    if (lock != null) {
      writer.write(
        writer.joins.isEmpty
            ? lock.sql
            : lock.sql.replaceFirst(
                'FOR UPDATE',
                'FOR UPDATE OF ${_sql.table}',
              ),
      );
    }
    final result = await _run(writer);
    if (specs.isEmpty) return _decode(result);
    return [
      for (final raw in dwResultRows(result)) _decodeIncluded(raw, specs),
    ];
  }

  Future<R?> findFirst({
    List<DwRelationInclude> Function(T t)? include,
    DwWhereCondition Function(T t)? where,
    List<DwOrderTerm> Function(T t)? orderBy,
    DwRowLock? lock,
  }) async {
    final rows = await find(
      include: include,
      where: where,
      orderBy: orderBy,
      limit: 1,
      lock: lock,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<R?> findById(
    int id, {
    DwRowLock? lock,
    List<DwRelationInclude> Function(T t)? include,
  }) async {
    if (include != null) {
      return findFirst(
        where: (t) => t.id.equals(id),
        include: include,
        lock: lock,
      );
    }
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
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write(
      distinct == null
          ? _sql.count
          : 'SELECT count(DISTINCT ${distinct(table).sqlIn(writer)}) FROM ${_sql.table}',
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
    (writer) => distinct == null
        ? 'count(*)'
        : 'count(DISTINCT ${distinct(table).sqlIn(writer)})',
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
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write(
      'SELECT ${_sumOf(column, writer)} AS "dw_value" FROM ${_sql.table}',
    );
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
      (writer) => _sumOf(column, writer),
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
    final keyAlias = _sql.keyAlias;
    final terms = orderBy(table);
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write(
      _sql.select.replaceFirst(
        'SELECT ',
        'SELECT DISTINCT ON (${key.sqlIn(writer)}) ${key.sqlIn(writer)} AS ${dwQuoteIdentifier(keyAlias)}, ',
      ),
    );
    _writeWhere(writer, where);
    writer.write(
      ' ORDER BY ${[key.sqlIn(writer), for (final term in terms) term.sqlIn(writer)].join(', ')}',
    );
    final result = await _run(writer);
    return {
      for (final row in dwResultRows(result))
        row.decode(key, name: keyAlias): table.fromRow(row),
    };
  }

  Future<bool> exists({DwWhereCondition Function(T t)? where}) async {
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write('SELECT EXISTS (SELECT 1 FROM ${_sql.table}');
    _writeWhere(writer, where);
    writer.write(')');
    final result = await _run(writer);
    return result.first.first! as bool;
  }

  /// Inserts [draft] and returns the row as stored, with the id the database
  /// assigned and every value read back.
  Future<R> insert(DwRowDraft<R> draft) async {
    final result = await _insert(draft, '');
    return _decode(result).first;
  }

  /// Inserts [draft] unless it conflicts; returns `null` when it was skipped.
  Future<R?> tryInsert(
    DwRowDraft<R> draft, {
    required DwOnConflict<T> onConflict,
  }) async {
    final result = await _insert(draft, onConflict.sql(table));
    return result.isEmpty ? null : _decode(result).first;
  }

  /// Inserts all [drafts] in one statement and returns the rows as stored, in
  /// the same order.
  Future<List<R>> insertAll(Iterable<DwRowDraft<R>> drafts) async {
    final list = drafts.toList(growable: false);
    if (list.isEmpty) return const [];
    final columns = _sql.valueColumns;
    final arrays = [for (final _ in columns) <Object?>[]];
    for (final draft in list) {
      final values = _initial(table.toDraftRow(draft));
      for (final (position, column) in columns.indexed) {
        final value = values[column.name];
        arrays[position].add(
          value == null ? null : column.type.encodeArrayElement(value),
        );
      }
    }
    final result = await _db.run(_sql.insertAll, [
      for (final column in columns) column.type.arrayParameterType,
    ], arrays);
    return _decode(result);
  }

  /// Writes ordinary columns of [row] by id, retaining its stored state.
  /// Throws [DwRowNotFound] for a missing id, or [DwStaleState] when the
  /// stored state no longer matches [row]. Generated `copyWith` refuses an
  /// intentional state change with [DwStateWriteException].
  Future<R> update(R row) async {
    final values = _checked(table.toRow(row));
    if (_sql.updateColumns.isEmpty) {
      throw DwStateWriteException(
        table.tableName,
        'update: no ordinary columns',
      );
    }
    final result = await _db.run(
      _sql.updateById,
      [
        for (final column in _sql.updateColumns) column.type.parameterType,
        pg.Type.bigInteger,
        for (final column in _sql.stateColumns) column.type.parameterType,
      ],
      [
        for (final column in _sql.updateColumns)
          _encode(column, values[column.name]),
        row.id,
        for (final column in _sql.stateColumns)
          _encode(column, values[column.name]),
      ],
    );
    if (result.isEmpty) {
      // Only the failed guard needs a read; successful writes remain one SQL
      // statement. No write is retried after inspecting the current row.
      if (_stateColumns.isNotEmpty &&
          await exists(where: (t) => t.id.equals(row.id))) {
        throw DwStaleState(table.tableName, row.id);
      }
      throw DwRowNotFound(table.tableName, row.id);
    }
    return _decode(result).first;
  }

  /// Atomically moves [id] if its stored state permits [to]. Returns the
  /// changed row, or null for a missing row or a refused move.
  Future<R?> transition<S>(
    int id, {
    required DwTableColumn<S> Function(T t) column,
    required S to,
  }) async {
    final rows = await transitionWhere(
      where: (t) => t.id.equals(id),
      column: column,
      to: to,
    );
    return rows.isEmpty ? null : rows.single;
  }

  /// One guarded UPDATE, returning only rows that moved. Compare returned ids
  /// with requested ids to learn which did not move. No pre-read is made;
  /// concurrent writers recheck the guard against the locked stored row.
  Future<List<R>> transitionWhere<S>({
    required DwWhereCondition Function(T t) where,
    required DwTableColumn<S> Function(T t) column,
    required S to,
  }) async {
    final selected = column(table);
    final declared = _stateColumns
        .where((c) => c.name == selected.name)
        .firstOrNull;
    if (selected.relationPath != null ||
        declared == null ||
        declared.type != selected.type) {
      throw ArgumentError(
        'transition: select a state column of ${table.tableName}',
      );
    }
    final sources = declared.transitions!.sourcesFor(to);
    if (sources.isEmpty) return const [];
    final writer = DwSqlWriter(rootTable: table.tableName)
      ..write('UPDATE ${_sql.table} SET ');
    declared.set(to).write(writer);
    _writeWhere(
      writer,
      (t) => where(t) & declared.inList(sources.cast<Object>()),
    );
    writer.write(_sql.returning);
    return _decode(await _run(writer));
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

  /// Inserts [draft], or — when it conflicts on the unique [conflictOn]
  /// columns — writes every other column of it over the row already there;
  /// returns the stored row either way.
  ///
  /// The single-row settings, the per-member answer written again: one
  /// statement, with no window between "not there" and "insert" for a
  /// concurrent writer to fall into.
  Future<R> upsert(
    DwRowDraft<R> draft, {
    required List<DwTableColumn<Object?>> Function(T t) conflictOn,
  }) async {
    _refuseStateUpsert();
    final target = conflictOn(table);
    if (target.isEmpty) throw ArgumentError('upsert: no conflict columns');
    final names = {for (final column in target) column.name};
    final written = [
      for (final column in _sql.valueColumns)
        if (!names.contains(column.name)) column,
    ];
    // With nothing but the key to write, the key itself is set to what it
    // already is: `DO NOTHING` would return no row to answer with.
    final set = [
      for (final column in written.isEmpty ? target : written)
        '${column.sql} = EXCLUDED.${column.sql}',
    ];
    final result = await _insert(
      draft,
      ' ON CONFLICT (${target.map((column) => column.sql).join(', ')}) '
      'DO UPDATE SET ${set.join(', ')}',
    );
    return _decode(result).first;
  }

  /// Writes [drafts] in one statement: each is inserted, or — when a row
  /// with the same [conflictOn] values exists — written over it, unless that
  /// row already holds exactly these values. Returns how many rows were
  /// inserted or changed, so a second run with the same drafts writes nothing
  /// and answers `0`.
  ///
  /// Rows the table holds that [drafts] does not name are left alone. The
  /// rows the code declares and a database converges on at every start — a
  /// catalogue, the reasons a project refuses something — which is what
  /// `DwSeedRows` runs it for.
  ///
  /// Throws [ArgumentError] for a nullable [conflictOn] column (a conflict
  /// never matches a null, so every run would insert again), and for two
  /// drafts with the same [conflictOn] values: one statement cannot write a
  /// row twice.
  Future<int> upsertAll(
    Iterable<DwRowDraft<R>> drafts, {
    required List<DwTableColumn<Object?>> Function(T t) conflictOn,
  }) async {
    final list = drafts.toList(growable: false);
    if (list.isEmpty) return 0;
    _refuseStateUpsert();
    final target = conflictOn(table);
    if (target.isEmpty) throw ArgumentError('upsertAll: no conflict columns');
    for (final column in target) {
      if (column.nullable) {
        // A conflict never matches a null: every run would insert again.
        throw ArgumentError(
          'upsertAll: conflict column "${column.name}" is nullable',
        );
      }
    }
    final columns = _sql.valueColumns;
    final arrays = [for (final _ in columns) <Object?>[]];
    final seen = LinkedHashSet<List<Object?>>(
      equals: const ListEquality<Object?>().equals,
      hashCode: const ListEquality<Object?>().hash,
    );
    for (final draft in list) {
      final values = _initial(table.toDraftRow(draft));
      final key = [for (final column in target) values[column.name]];
      if (!seen.add(key)) {
        throw ArgumentError(
          'upsertAll: two rows share ${target.map((c) => c.name).join(', ')} '
          '= ${key.join(', ')}',
        );
      }
      for (final (position, column) in columns.indexed) {
        final value = values[column.name];
        arrays[position].add(
          value == null ? null : column.type.encodeArrayElement(value),
        );
      }
    }
    final names = {for (final column in target) column.name};
    final written = [
      for (final column in columns)
        if (!names.contains(column.name)) column,
    ];
    // Only a row whose values differ is written: an unchanged one would
    // still be rewritten by `DO UPDATE`, and a start that converges on what
    // is already there must leave the table as it found it.
    final onConflict = written.isEmpty
        ? 'DO NOTHING'
        : 'DO UPDATE SET '
              '${[for (final column in written) '${column.sql} = EXCLUDED.${column.sql}'].join(', ')} '
              'WHERE ROW(${[for (final column in written) '${_sql.table}.${column.sql}'].join(', ')}) '
              'IS DISTINCT FROM '
              'ROW(${[for (final column in written) 'EXCLUDED.${column.sql}'].join(', ')})';
    final result = await _db.run(
      '${_sql.insertAllSelect} '
      'ON CONFLICT (${target.map((column) => column.sql).join(', ')}) '
      '$onConflict',
      [for (final column in columns) column.type.arrayParameterType],
      arrays,
    );
    return result.affectedRows;
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
    final writer = DwSqlWriter(rootTable: table.tableName)
      ..write('DELETE FROM ${_sql.table}');
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
    if (assignments.any((a) => a.column.relationPath != null)) {
      throw ArgumentError('updateWhere: assignments must select this table');
    }
    final stateNames = {for (final column in _stateColumns) column.name};
    if (assignments.any((a) => stateNames.contains(a.column.name))) {
      throw DwStateWriteException(table.tableName, 'updateWhere');
    }
    final writer = DwSqlWriter(rootTable: table.tableName)
      ..write('UPDATE ${_sql.table} SET ');
    for (final (position, assignment) in assignments.indexed) {
      if (position > 0) writer.write(', ');
      assignment.write(writer);
    }
    _writeWhere(writer, where);
    return writer;
  }

  /// `SUM` in the column's own type — Postgres widens a `bigint` sum to
  /// `numeric` — and 0 rather than null over no rows.
  String _sumOf(DwTableColumn<Object?> column, DwSqlWriter writer) =>
      'CAST(COALESCE(sum(${column.sqlIn(writer)}), 0) AS ${column.type.sqlType})';

  Future<V?> _extreme<V>(
    String function,
    DwTableColumn<V?> column,
    DwWhereCondition Function(T t)? where,
  ) async {
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write(
      'SELECT $function(${column.sqlIn(writer)}) FROM ${_sql.table}',
    );
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
      (writer) => '$function(${column.sqlIn(writer)})',
      (raw) => raw == null ? null : column.type.decode(raw),
      where,
    );
    return {for (final MapEntry(:key, :value) in all.entries) key: ?value};
  }

  /// `SELECT group, aggregate … GROUP BY group`, keyed by the group's value.
  Future<Map<K, V>> _grouped<K, V>(
    DwTableColumn<K> group,
    String Function(DwSqlWriter writer) aggregate,
    V Function(Object? raw) decode,
    DwWhereCondition Function(T t)? where,
  ) async {
    final writer = DwSqlWriter(rootTable: table.tableName);
    writer.write(
      'SELECT ${group.sqlIn(writer)} AS "dw_key", ${aggregate(writer)} AS "dw_value" FROM ${_sql.table}',
    );
    _writeWhere(writer, where);
    writer.write(' GROUP BY ${group.sqlIn(writer)}');
    return {
      for (final row in dwResultRows(await _run(writer)))
        row.decode(group, name: 'dw_key'): decode(row['dw_value']),
    };
  }

  Future<pg.Result> _insert(DwRowDraft<R> draft, String onConflict) {
    final values = _initial(table.toDraftRow(draft));
    final columns = _sql.valueColumns;
    return _db.run(
      '${_sql.insert}$onConflict${_sql.returning}',
      [for (final column in columns) column.type.parameterType],
      [for (final column in columns) _encode(column, values[column.name])],
    );
  }

  Iterable<DwTableColumn<Object?>> get _stateColumns => _sql.stateColumns;

  void _refuseStateUpsert() {
    if (_stateColumns.isNotEmpty) {
      throw DwStateWriteException(table.tableName, 'upsert');
    }
  }

  Map<String, Object?> _initial(Map<String, Object?> values) {
    _checked(values);
    for (final column in _stateColumns) {
      if (!column.transitions!.initial.contains(values[column.name])) {
        throw DwStateWriteException(table.tableName, 'insert: ${column.name}');
      }
    }
    return values;
  }

  Map<String, Object?> _checked(Map<String, Object?> values) {
    for (final column in _sql.valueColumns) {
      if (!values.containsKey(column.name)) {
        throw StateError(
          '${table.tableName} has no value for "${column.name}"; regenerate the table',
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
    if (writer.sql.startsWith('UPDATE ') || writer.sql.startsWith('DELETE ')) {
      writer.write(' WHERE ');
      where(table).writeMutation(writer);
    } else {
      writer.write(' WHERE ');
      where(table).write(writer);
    }
  }

  Future<pg.Result> _run(DwSqlWriter writer) =>
      _db.run(writer.sql, writer.types, writer.values);

  R _decodeIncluded(DwResultRow raw, List<DwIncludeSpec> specs) {
    final row = table.fromRow(raw);
    dwDecodeIncludes(row, specs, raw);
    return row;
  }

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
    select =
        'SELECT ${columns.map((c) => '${this.table}.${c.sql}').join(', ')} FROM ${this.table}';
    selectById = '$select WHERE "id" = \$1';
    selectByIds = '$select WHERE "id" = ANY(\$1)';
    count = 'SELECT count(*) FROM ${this.table}';
    deleteById = 'DELETE FROM ${this.table} WHERE "id" = \$1';
    final values = updateColumns;
    updateById =
        'UPDATE ${this.table} SET '
        '${[for (final (i, column) in values.indexed) '${column.sql} = \$${i + 1}'].join(', ')} '
        'WHERE "id" = \$${values.length + 1}'
        '${[for (final (i, column) in stateColumns.indexed) ' AND ${column.sql} = \$${values.length + 2 + i}'].join()}'
        '$returning';
  }

  static final Expando<_DwTableSql> _cache = Expando('DwTableSql');

  static _DwTableSql of(DwTableDef table) =>
      _cache[table] ??= _DwTableSql(table);

  final String table;
  final List<DwTableColumn<Object?>> columns;
  late final String returning;
  late final String keyAlias = () {
    final names = columns.map((c) => c.name).toSet();
    var alias = 'dw_key';
    while (names.contains(alias)) {
      alias = '${alias}_';
    }
    return alias;
  }();

  late final String select;
  late final String selectById;
  late final String selectByIds;
  late final String count;
  late final String deleteById;
  late final String updateById;

  /// Every column but the id: what an insert and an update write.
  late final List<DwTableColumn<Object?>> valueColumns = List.unmodifiable(
    columns.skip(1),
  );

  late final List<DwTableColumn<Object?>> stateColumns = List.unmodifiable(
    valueColumns.where((c) => c.transitions != null),
  );

  late final List<DwTableColumn<Object?>> updateColumns = List.unmodifiable(
    valueColumns.where((c) => c.transitions == null),
  );

  late final String insert =
      'INSERT INTO $table (${valueColumns.map((column) => column.sql).join(', ')}) '
      'VALUES (${[for (var i = 1; i <= valueColumns.length; i++) '\$$i'].join(', ')})';

  late final String insertAll = _insertAllInto(valueColumns) + returning;

  /// The insert of every draft, from one array per column, with no
  /// `RETURNING`: what `upsertAll` completes with its conflict clause.
  late final String insertAllSelect = _insertAllInto(valueColumns);

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
        'ORDER BY position';
  }
}
