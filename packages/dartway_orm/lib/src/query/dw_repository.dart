import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../db/dw_db.dart';
import '../db/dw_errors.dart';
import '../entity/dw_entity.dart';
import '../entity/dw_table_def.dart';
import 'dw_column.dart';
import 'dw_lock.dart';

/// Typed access to one entity table through a [DwDb].
///
/// Every method is one statement and one round trip (two inside a
/// transaction, where the driver closes the portal). Statement text depends
/// only on the *shape* of a call — which columns, which operators — never on
/// the values, so each shape is prepared once per connection: limits,
/// offsets and `inList` values are all parameters.
final class DwRepository<E extends DwEntity, T extends DwTableDef<E>> {
  @internal
  DwRepository.internal(this._db, this.table);

  final DwDb _db;
  final T table;

  _DwTableSql get _sql => _DwTableSql.of(table);

  /// Rows matching [where], in [orderBy] order.
  ///
  /// Without [orderBy] the order is whatever the database returns; paging
  /// with [limit] and [offset] needs an order to be stable.
  Future<List<E>> find({
    DwExpression Function(T t)? where,
    List<DwOrder> Function(T t)? orderBy,
    int? limit,
    int? offset,
    DwLock? lock,
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

  Future<E?> findFirst({
    DwExpression Function(T t)? where,
    List<DwOrder> Function(T t)? orderBy,
    DwLock? lock,
  }) async {
    final rows = await find(
      where: where,
      orderBy: orderBy,
      limit: 1,
      lock: lock,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<E?> findById(int id, {DwLock? lock}) async {
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
  Future<List<E>> findByIds(Iterable<int> ids) async {
    final distinct = ids.toSet();
    if (distinct.isEmpty) return const [];
    final result = await _db.run(
      _sql.selectByIds,
      const [pg.Type.bigIntegerArray],
      [distinct.toList(growable: false)],
    );
    return _decode(result);
  }

  Future<int> count({DwExpression Function(T t)? where}) async {
    final writer = DwSqlWriter()..write(_sql.count);
    _writeWhere(writer, where);
    final result = await _run(writer);
    return result.first.first! as int;
  }

  Future<bool> exists({DwExpression Function(T t)? where}) async {
    final writer = DwSqlWriter()
      ..write('SELECT EXISTS (SELECT 1 FROM ${_sql.table}');
    _writeWhere(writer, where);
    writer.write(')');
    final result = await _run(writer);
    return result.first.first! as bool;
  }

  /// Inserts [entity] and returns it as stored, with its id and every value
  /// read back from the database.
  Future<E> insert(E entity) async {
    final result = await _insert(entity, '');
    return _decode(result).first;
  }

  /// Inserts [entity] unless it conflicts; returns `null` when the row was
  /// skipped.
  Future<E?> tryInsert(E entity, {required DwOnConflict<T> onConflict}) async {
    final result = await _insert(entity, onConflict.sql(table));
    return result.isEmpty ? null : _decode(result).first;
  }

  /// Inserts all [entities] in one statement and returns them as stored, in
  /// the same order.
  ///
  /// Either every entity has an id or none has: the statement binds one array
  /// per column, and a column cannot be half defaulted.
  Future<List<E>> insertAll(Iterable<E> entities) async {
    final list = entities.toList(growable: false);
    if (list.isEmpty) return const [];
    final withId = list.first.id != null;
    if (list.any((entity) => (entity.id != null) != withId)) {
      throw ArgumentError(
        'insertAll: either every entity has an id or none has',
      );
    }
    final columns = _sql.insertColumns(withId: withId);
    final arrays = [for (final _ in columns) <Object?>[]];
    for (final entity in list) {
      final row = _rowOf(entity);
      for (final (position, column) in columns.indexed) {
        final value = row[column.name];
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

  /// Writes every column of [entity] by its id and returns the stored row.
  ///
  /// Throws [DwEntityNotFound] when no row has that id: an update that
  /// changed nothing is a failure, not a quiet success.
  Future<E> update(E entity) async {
    final id = entity.id;
    if (id == null) {
      throw ArgumentError('update: the entity has no id; insert it first');
    }
    final row = _rowOf(entity);
    final columns = _sql.insertColumns(withId: false);
    final result = await _db.run(
      _sql.updateById,
      [
        for (final column in columns) column.type.parameterType,
        pg.Type.bigInteger,
      ],
      [for (final column in columns) _encode(column, row[column.name]), id],
    );
    if (result.isEmpty) throw DwEntityNotFound(table.name, id);
    return _decode(result).first;
  }

  /// Sets columns on every row matching [where]; returns the number of rows.
  Future<int> updateWhere({
    required DwExpression Function(T t) where,
    required List<DwAssignment<Object?>> Function(T t) set,
  }) async {
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
    return (await _run(writer)).affectedRows;
  }

  /// Deletes the row with [id]; returns 1, or 0 when there was none.
  Future<int> delete(int id) async => (await _db.run(
    _sql.deleteById,
    const [pg.Type.bigInteger],
    [id],
  )).affectedRows;

  Future<int> deleteWhere({required DwExpression Function(T t) where}) async {
    final writer = DwSqlWriter()..write('DELETE FROM ${_sql.table}');
    _writeWhere(writer, where);
    return (await _run(writer)).affectedRows;
  }

  Future<pg.Result> _insert(E entity, String onConflict) {
    final withId = entity.id != null;
    final row = _rowOf(entity);
    final columns = _sql.insertColumns(withId: withId);
    return _db.run(
      '${_sql.insert(withId: withId)}$onConflict${_sql.returning}',
      [for (final column in columns) column.type.parameterType],
      [for (final column in columns) _encode(column, row[column.name])],
    );
  }

  Map<String, Object?> _rowOf(E entity) {
    final row = table.toRow(entity);
    for (final column in _sql.insertColumns(withId: entity.id != null)) {
      if (!row.containsKey(column.name)) {
        throw StateError(
          '${table.name}.toRow has no value for "${column.name}"; regenerate the table',
        );
      }
    }
    return row;
  }

  Object? _encode(DwColumn<Object?> column, Object? value) =>
      value == null ? null : column.type.encode(value);

  void _checkLock(DwLock? lock) {
    if (lock != null && !_db.inTransaction) {
      throw StateError(
        '${lock.name} on "${table.name}" needs a transaction: outside one the '
        'row lock ends with the statement',
      );
    }
  }

  void _writeWhere(DwSqlWriter writer, DwExpression Function(T t)? where) {
    if (where == null) return;
    writer.write(' WHERE ');
    where(table).write(writer);
  }

  Future<pg.Result> _run(DwSqlWriter writer) =>
      _db.run(writer.sql, writer.types, writer.values);

  List<E> _decode(pg.Result result) => [
    for (final row in dwRows(result)) table.fromRow(row),
  ];

  @override
  String toString() => 'DwRepository(${table.name})';
}

/// Statement text of a table that does not depend on a call, built once per
/// table object.
final class _DwTableSql {
  _DwTableSql(DwTableDef table)
    : table = dwQuote(table.name),
      columns = List.unmodifiable(table.columns) {
    if (columns.isEmpty || !columns.first.primaryKey) {
      throw StateError('${table.name}.columns must start with the id column');
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
  final List<DwColumn<Object?>> columns;
  late final String returning;
  late final String select;
  late final String selectById;
  late final String selectByIds;
  late final String count;
  late final String deleteById;
  late final String updateById;

  late final List<DwColumn<Object?>> _withoutId = List.unmodifiable(
    columns.skip(1),
  );

  List<DwColumn<Object?>> insertColumns({required bool withId}) =>
      withId ? columns : _withoutId;

  late final String _insertWithId = _insertInto(columns);
  late final String _insertWithoutId = _insertInto(_withoutId);

  String insert({required bool withId}) =>
      withId ? _insertWithId : _insertWithoutId;

  String _insertInto(List<DwColumn<Object?>> columns) =>
      'INSERT INTO $table (${columns.map((column) => column.sql).join(', ')}) '
      'VALUES (${[for (var i = 1; i <= columns.length; i++) '\$$i'].join(', ')})';

  late final String _insertAllWithId = _insertAllInto(columns);
  late final String _insertAllWithoutId = _insertAllInto(_withoutId);

  String insertAll({required bool withId}) =>
      withId ? _insertAllWithId : _insertAllWithoutId;

  /// One array per column, zipped by `unnest` and kept in input order by
  /// its ordinality, so the returned rows line up with the entities given.
  String _insertAllInto(List<DwColumn<Object?>> columns) {
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
