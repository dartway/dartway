import 'dart:async';

import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../entity/dw_table_row.dart';
import '../entity/dw_table_def.dart';
import '../query/dw_lock.dart';
import '../query/dw_repository.dart';
import 'dw_connection.dart';
import 'dw_errors.dart';
import 'dw_result_row.dart';

/// A handle to run statements: bound to the pool, or to one connection inside
/// a transaction.
///
/// Code that receives a `DwDb` does not know which, and should not: the same
/// repository call works in both. What differs is checked, not assumed —
/// row locks and advisory locks need a transaction and throw [StateError]
/// without one.
///
/// Sealed: the transaction guarantees below hold only for the handles this
/// library creates.
sealed class DwDb {
  DwDb();

  /// Whether statements run inside a transaction.
  bool get inTransaction;

  /// Runs [body] in a transaction and commits when it completes.
  ///
  /// When [body] throws, the transaction rolls back and the error propagates.
  /// When a statement failed inside [body] and [body] caught the error, the
  /// transaction is still rolled back and that error is rethrown: Postgres
  /// would silently turn the `COMMIT` of an aborted transaction into a
  /// rollback, and a commit that did not happen must not look like one.
  ///
  /// Inside a transaction this opens a `SAVEPOINT`: a failure rolls back only
  /// the nested part. The enclosing handle must not be used while the nested
  /// one is open. [isolation] can be chosen only by the outermost transaction.
  Future<R> transaction<R>(
    Future<R> Function(DwDb tx) body, {
    DwIsolation? isolation,
  });

  /// The typed repository of [table].
  DwRepository<R, T> repository<R extends DwTableRow, T extends DwTableDef<R>>(
    T table,
  ) => DwRepository.internal(this, table);

  /// Runs a statement with `@name` parameters and returns its rows.
  Future<List<DwResultRow>> query(
    String sql, {
    Map<String, Object?> params = const {},
  }) async {
    final result = await runNamed(sql, params);
    return dwRows(result);
  }

  /// Runs statements and returns the number of affected rows.
  ///
  /// Without [params] the text may hold several statements separated by `;`
  /// and travels in one round trip.
  Future<int> execute(String sql, {Map<String, Object?> params = const {}});

  /// Takes a transaction-scoped advisory lock, waiting for it. Released at
  /// commit or rollback.
  Future<void> advisoryLock(int namespace, int key) async {
    _checkAdvisoryKeys(namespace, key);
    await run(
      'SELECT pg_advisory_xact_lock(\$1, \$2)',
      const [pg.Type.integer, pg.Type.integer],
      [namespace, key],
    );
  }

  /// Takes a transaction-scoped advisory lock if it is free.
  Future<bool> tryAdvisoryLock(int namespace, int key) async {
    _checkAdvisoryKeys(namespace, key);
    final result = await run(
      'SELECT pg_try_advisory_xact_lock(\$1, \$2)',
      const [pg.Type.integer, pg.Type.integer],
      [namespace, key],
    );
    return result.first.first! as bool;
  }

  /// Sends a notification on [channel]. Inside a transaction it is delivered
  /// at commit, and not at all on rollback.
  Future<void> notify(String channel, String payload) async {
    await run(
      'SELECT pg_notify(\$1, \$2)',
      const [pg.Type.text, pg.Type.text],
      [channel, payload],
    );
  }

  void _checkAdvisoryKeys(int namespace, int key) {
    if (!inTransaction) {
      throw StateError(
        'an advisory lock needs a transaction: the lock is transaction-scoped',
      );
    }
    const min = -0x80000000;
    const max = 0x7fffffff;
    if (namespace < min || namespace > max || key < min || key > max) {
      throw ArgumentError(
        'advisory lock keys are 32-bit integers: ($namespace, $key)',
      );
    }
  }

  /// Runs a statement whose parameter types are known.
  @internal
  Future<pg.Result> run(
    String sql,
    List<pg.Type<Object>> types,
    List<Object?> values,
  );

  @internal
  Future<pg.Result> runNamed(String sql, Map<String, Object?> params);

  /// Runs [body] with a handle bound to one connection for its whole
  /// duration, outside any transaction — for session-level state such as a
  /// session advisory lock.
  @internal
  Future<R> pinned<R>(Future<R> Function(DwDb db) body);
}

/// Wraps result rows, sharing one column index across the rows.
@internal
List<DwResultRow> dwRows(pg.Result result) {
  if (result.isEmpty) return const [];
  final index = <String, int>{};
  for (final (position, column) in result.schema.columns.indexed) {
    index[column.columnName ?? '?column?'] = position;
  }
  return [for (final row in result) DwResultRow(index, row)];
}

/// The pool-bound handle: every statement borrows a connection for exactly
/// its own duration.
@internal
final class DwPoolDb extends DwDb {
  DwPoolDb(this._pool);

  final DwPool _pool;

  @override
  bool get inTransaction => false;

  @override
  Future<pg.Result> run(
    String sql,
    List<pg.Type<Object>> types,
    List<Object?> values,
  ) => _withConnection((connection) => connection.run(sql, types, values));

  @override
  Future<pg.Result> runNamed(String sql, Map<String, Object?> params) =>
      _withConnection((connection) => connection.runNamed(sql, params));

  @override
  Future<int> execute(String sql, {Map<String, Object?> params = const {}}) =>
      _withConnection(
        (connection) async => params.isEmpty
            ? connection.runScript(sql)
            : (await connection.runNamed(sql, params)).affectedRows,
      );

  @override
  Future<R> transaction<R>(
    Future<R> Function(DwDb tx) body, {
    DwIsolation? isolation,
  }) async {
    final connection = await _pool.acquire();
    var broken = false;
    try {
      return await dwRunTransaction(
        connection,
        body,
        isolation,
        onBroken: () => broken = true,
      );
    } finally {
      _pool.release(connection, discard: broken);
    }
  }

  /// The connection is closed afterwards instead of returning to the pool:
  /// session-level state (a session advisory lock, a `SET`) must never leak
  /// into someone else's borrow, and one reconnect per pinned use is cheap.
  @override
  Future<R> pinned<R>(Future<R> Function(DwDb db) body) async {
    final connection = await _pool.acquire();
    final db = DwConnectionDb(connection);
    try {
      return await body(db);
    } finally {
      db.close();
      _pool.release(connection, discard: true);
    }
  }

  Future<R> _withConnection<R>(
    Future<R> Function(DwConnection connection) action,
  ) async {
    final connection = await _pool.acquire();
    try {
      return await dwRetryStale(() => action(connection));
    } finally {
      _pool.release(connection);
    }
  }
}

/// Runs [action] again once when it failed on a stale prepared statement.
///
/// Only outside a transaction: there a failed statement changed nothing, so
/// running it again is exactly the call the caller made. Inside one the
/// failure has already aborted the transaction, and must surface.
@internal
Future<R> dwRetryStale<R>(Future<R> Function() action) async {
  try {
    return await action();
  } on DwDatabaseException catch (error) {
    if (!DwConnection.isStale(error)) rethrow;
    return action();
  }
}

/// A handle bound to one connection, outside a transaction.
@internal
final class DwConnectionDb extends DwDb {
  DwConnectionDb(this._connection);

  final DwConnection _connection;
  bool _inTransaction = false;
  bool _closed = false;

  void close() => _closed = true;

  @override
  bool get inTransaction => false;

  void _check() {
    if (_closed) {
      throw StateError(
        'a pinned DwDb must not escape the callback it was given to',
      );
    }
    if (_inTransaction) {
      throw StateError(
        'this handle is used while a transaction on its connection is open; '
        'use the transaction handle',
      );
    }
  }

  @override
  Future<pg.Result> run(
    String sql,
    List<pg.Type<Object>> types,
    List<Object?> values,
  ) {
    _check();
    return dwRetryStale(() => _connection.run(sql, types, values));
  }

  @override
  Future<pg.Result> runNamed(String sql, Map<String, Object?> params) {
    _check();
    return dwRetryStale(() => _connection.runNamed(sql, params));
  }

  @override
  Future<int> execute(
    String sql, {
    Map<String, Object?> params = const {},
  }) async {
    _check();
    return params.isEmpty
        ? _connection.runScript(sql)
        : (await runNamed(sql, params)).affectedRows;
  }

  @override
  Future<R> transaction<R>(
    Future<R> Function(DwDb tx) body, {
    DwIsolation? isolation,
  }) async {
    _check();
    _inTransaction = true;
    try {
      // Broken or not, this connection is closed when the pinned use ends.
      return await dwRunTransaction(
        _connection,
        body,
        isolation,
        onBroken: () {},
      );
    } finally {
      _inTransaction = false;
    }
  }

  @override
  Future<R> pinned<R>(Future<R> Function(DwDb db) body) {
    _check();
    return body(this);
  }
}

/// Runs a top-level transaction on [connection].
///
/// [onBroken] is called when the session state of the connection became
/// unknown; the caller must then close the connection instead of reusing it.
@internal
Future<R> dwRunTransaction<R>(
  DwConnection connection,
  Future<R> Function(DwDb tx) body,
  DwIsolation? isolation, {
  required void Function() onBroken,
}) async {
  await connection.runScript(
    isolation == null ? 'BEGIN' : 'BEGIN ISOLATION LEVEL ${isolation.sql}',
  );
  return _completeScope(
    connection,
    _DwTxScope(depth: 0),
    body,
    end: 'COMMIT',
    rollback: 'ROLLBACK',
    onBroken: onBroken,
    onEndFailed: (error, stackTrace) {
      // A server error at commit (a serialization failure, a deferred
      // constraint) ends the transaction cleanly; anything else leaves the
      // session unknown.
      if (error is! DwDatabaseException || error.code == null) onBroken();
    },
  );
}

Future<R> _completeScope<R>(
  DwConnection connection,
  _DwTxScope scope,
  Future<R> Function(DwDb tx) body, {
  required String end,
  required String rollback,
  required void Function() onBroken,
  required void Function(Object error, StackTrace stackTrace) onEndFailed,
}) async {
  Future<void> finish(String sql) async {
    try {
      await connection.runScript(sql);
    } catch (error, stackTrace) {
      onEndFailed(error, stackTrace);
      rethrow;
    }
  }

  Future<void> rollBack() async {
    try {
      await finish(rollback);
    } catch (_) {
      // The error of the body is the one to report; the failed rollback has
      // already marked the connection.
      onBroken();
    }
  }

  final R result;
  try {
    result = await body(_DwTxDb(connection, scope, onBroken));
  } catch (_) {
    if (await _close(scope)) onBroken();
    await rollBack();
    rethrow;
  }
  if (await _close(scope)) {
    // Work of this transaction was still queued on the connection; nothing
    // sent after the rollback may run on a connection someone else borrows.
    onBroken();
    await rollBack();
    throw StateError(
      'the transaction body returned while its statements or a nested '
      'transaction were still running; await them. Rolled back.',
    );
  }
  if (scope.failure case (final error, final stackTrace)) {
    await rollBack();
    Error.throwWithStackTrace(error, stackTrace);
  }
  await finish(end);
  return result;
}

/// Closes [scope] and everything nested in it, waits for their running
/// statements, and tells whether anything was still running.
Future<bool> _close(_DwTxScope scope) async {
  var leaked = false;
  for (_DwTxScope? current = scope; current != null; current = current.child) {
    current.open = false;
    if (current != scope) leaked = true;
    if (current.running) {
      leaked = true;
      await current.settled;
    }
  }
  return leaked;
}

final class _DwTxScope {
  _DwTxScope({required this.depth});

  final int depth;
  bool open = true;
  _DwTxScope? child;

  /// The first statement error in this scope, with its stack trace.
  (Object, StackTrace)? failure;

  int _running = 0;
  Completer<void>? _settled;

  bool get running => _running > 0;

  void started() => _running++;

  void finished() {
    if (--_running == 0) {
      _settled?.complete();
      _settled = null;
    }
  }

  Future<void> get settled =>
      _running == 0 ? Future.value() : (_settled ??= Completer()).future;
}

final class _DwTxDb extends DwDb {
  _DwTxDb(this._connection, this._scope, this._onBroken);

  final DwConnection _connection;
  final _DwTxScope _scope;
  final void Function() _onBroken;

  @override
  bool get inTransaction => true;

  void _check() {
    if (!_scope.open) {
      throw StateError(
        'the transaction has finished; its DwDb must not escape the body',
      );
    }
    if (_scope.child != null) {
      throw StateError(
        'the enclosing transaction is used while a nested transaction is open',
      );
    }
  }

  Future<T> _statement<T>(Future<T> Function() action) async {
    _check();
    _scope.started();
    try {
      return await action();
    } on DwDatabaseException catch (error, stackTrace) {
      // Any statement error aborts the whole Postgres transaction; remember
      // it so a body that swallows it cannot commit.
      _scope.failure ??= (error, stackTrace);
      rethrow;
    } finally {
      _scope.finished();
    }
  }

  @override
  Future<pg.Result> run(
    String sql,
    List<pg.Type<Object>> types,
    List<Object?> values,
  ) => _statement(() => _connection.run(sql, types, values));

  @override
  Future<pg.Result> runNamed(String sql, Map<String, Object?> params) =>
      _statement(() => _connection.runNamed(sql, params));

  @override
  Future<int> execute(String sql, {Map<String, Object?> params = const {}}) =>
      _statement(
        () async => params.isEmpty
            ? _connection.runScript(sql)
            : (await _connection.runNamed(sql, params)).affectedRows,
      );

  @override
  Future<R> transaction<R>(
    Future<R> Function(DwDb tx) body, {
    DwIsolation? isolation,
  }) async {
    if (isolation != null) {
      throw ArgumentError(
        'isolation is chosen by the outermost transaction; a nested one is a savepoint',
      );
    }
    _check();
    final savepoint = 'dw_savepoint_${_scope.depth + 1}';
    final child = _DwTxScope(depth: _scope.depth + 1);
    // The enclosing handle is closed before SAVEPOINT is even sent: a
    // statement slipping in between would land inside the savepoint and be
    // undone by its rollback.
    _scope.child = child;
    try {
      try {
        await _connection.runScript('SAVEPOINT $savepoint');
      } on DwDatabaseException catch (error, stackTrace) {
        _scope.failure ??= (error, stackTrace);
        rethrow;
      }
      return await _completeScope(
        _connection,
        child,
        body,
        end: 'RELEASE SAVEPOINT $savepoint',
        rollback:
            'ROLLBACK TO SAVEPOINT $savepoint; RELEASE SAVEPOINT $savepoint',
        onBroken: _onBroken,
        onEndFailed: (error, stackTrace) {
          // A savepoint that cannot be released or rolled back leaves the
          // enclosing transaction aborted as well.
          _scope.failure ??= (error, stackTrace);
          if (error is! DwDatabaseException || error.code == null) _onBroken();
        },
      );
    } finally {
      _scope.child = null;
    }
  }

  @override
  Future<R> pinned<R>(Future<R> Function(DwDb db) body) =>
      throw StateError('session-level work cannot run inside a transaction');
}
