import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:postgres/messages.dart' as pgm;
import 'package:postgres/postgres.dart' as pg;
import 'package:stream_channel/stream_channel.dart';

import 'dw_database_config.dart';
import 'dw_errors.dart';

/// One server connection with its own cache of prepared statements.
///
/// The driver re-parses every parameterised `execute` and closes the
/// statement afterwards: three round trips per query. A statement prepared
/// once and kept costs one round trip per run outside a transaction and two
/// inside one (the driver closes the portal). The cache is per connection
/// because a prepared statement lives in the server session that parsed it.
@internal
final class DwPooledConnection {
  DwPooledConnection._(this._connection, this._cacheSize);

  static Future<DwPooledConnection> open(
    DwDatabaseConfig config, {
    DwRoundTripCounter? counter,
  }) async {
    try {
      final connection = await pg.Connection.open(
        pg.Endpoint(
          host: config.host,
          port: config.port,
          database: config.name,
          username: config.user,
          password: config.password,
        ),
        settings: pg.ConnectionSettings(
          sslMode: config.ssl ? pg.SslMode.require : pg.SslMode.disable,
          applicationName: config.applicationName,
          timeZone: 'UTC',
          connectTimeout: config.connectTimeout,
          queryTimeout: config.queryTimeout,
          transformer: dwWireTap(counter),
        ),
      );
      return DwPooledConnection._(connection, config.statementCacheSize);
    } on pg.PgException catch (error, stackTrace) {
      Error.throwWithStackTrace(dwMapError(error), stackTrace);
    } on Exception catch (error, stackTrace) {
      // Socket and TLS failures come from dart:io, not from the driver.
      Error.throwWithStackTrace(
        DwDatabaseException(
          null,
          'cannot connect to ${config.host}:${config.port}/${config.name}: $error',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Whether [error] means a cached statement no longer fits the schema — a
  /// DDL change altered the shape of its result — or is gone from the
  /// session. Such a statement was evicted, and running it again parses it
  /// afresh.
  static bool isStale(DwDatabaseException error) =>
      error.code == '26000' ||
      (error.code == '0A000' && error.message.contains('cached plan'));

  final pg.Connection _connection;
  final int _cacheSize;

  /// Futures, not statements: two concurrent callers of one new statement
  /// share a single `Parse` instead of racing to prepare it twice.
  final LinkedHashMap<String, Future<pg.Statement>> _statements =
      LinkedHashMap();

  bool get isOpen => _connection.isOpen;

  int get cachedStatements => _statements.length;

  /// Runs a statement whose parameter types are known.
  Future<pg.Result> run(
    String sql,
    List<pg.Type<Object>> types,
    List<Object?> values,
  ) => _run(sql, () => pg.Sql(sql, types: types), values);

  /// Runs a statement with `@name` parameters, types inferred by the server.
  Future<pg.Result> runNamed(String sql, Map<String, Object?> parameters) =>
      _run('named:$sql', () => pg.Sql.named(sql), parameters);

  /// Runs one or more statements without parameters over the simple
  /// protocol: one round trip, nothing to prepare or cache.
  Future<int> runScript(String sql) async {
    try {
      final result = await _connection.execute(
        sql,
        queryMode: pg.QueryMode.simple,
        ignoreRows: true,
      );
      return result.affectedRows;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(dwMapError(error), stackTrace);
    }
  }

  Future<pg.Result> _run(
    String key,
    pg.Sql Function() describe,
    Object parameters,
  ) async {
    try {
      final statement = await _statement(key, describe);
      return await statement.run(parameters);
    } on pg.ServerException catch (error, stackTrace) {
      final mapped = dwMapError(error) as DwDatabaseException;
      if (isStale(mapped)) _evict(key);
      Error.throwWithStackTrace(mapped, stackTrace);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(dwMapError(error), stackTrace);
    }
  }

  Future<pg.Statement> _statement(String key, pg.Sql Function() describe) {
    final cached = _statements.remove(key);
    if (cached != null) {
      _statements[key] = cached;
      return cached;
    }
    final prepared = _connection.prepare(describe());
    _statements[key] = prepared;
    prepared.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_statements[key], prepared)) _statements.remove(key);
      },
    );
    if (_statements.length > _cacheSize) _evict(_statements.keys.first);
    return prepared;
  }

  void _evict(String key) {
    final statement = _statements.remove(key);
    // Closing is queued behind the running statement by the driver; its
    // failure only means the session is gone, which frees it anyway.
    statement?.then((s) => s.dispose()).ignore();
  }

  Future<void> close() async {
    _statements.clear();
    try {
      await _connection.close();
    } catch (_) {
      // Closing a connection that already failed has nothing left to report.
    }
  }
}

/// Counts completed server round trips — `ReadyForQuery` messages — across
/// the connections of one database, so a test can assert that a call costs
/// exactly what it should.
@internal
final class DwRoundTripCounter {
  int count = 0;
}

/// The tap every connection's protocol stream passes through.
///
/// Besides counting round trips it works around a driver defect: a
/// simple-protocol script with more than one row-returning statement
/// (`SELECT 1; SELECT 2`) completes a result future twice inside the
/// driver's message handler, an uncaught error. Scripts are run for their
/// effects only, so their row messages are dropped before the driver sees
/// them. The simple protocol is used on a DartWay connection for scripts and
/// nothing else, so an outgoing `Query` message marks one precisely.
@internal
StreamChannelTransformer<pgm.Message, pgm.Message> dwWireTap(
  DwRoundTripCounter? counter,
) => _DwWireTap(counter);

final class _DwWireTap
    implements StreamChannelTransformer<pgm.Message, pgm.Message> {
  _DwWireTap(this._counter);

  final DwRoundTripCounter? _counter;
  bool _inScript = false;

  @override
  StreamChannel<pgm.Message> bind(StreamChannel<pgm.Message> channel) => channel
      .changeSink(
        (sink) => _DwObservedSink(sink, (message) {
          if (message is pgm.QueryMessage) _inScript = true;
        }),
      )
      .changeStream(
        (messages) => messages.where((message) {
          if (message is pgm.ReadyForQueryMessage) {
            _counter?.count++;
            _inScript = false;
            return true;
          }
          return !(_inScript &&
              (message is pgm.RowDescriptionMessage ||
                  message is pgm.DataRowMessage));
        }),
      );
}

final class _DwObservedSink implements StreamSink<pgm.Message> {
  _DwObservedSink(this._inner, this._observe);

  final StreamSink<pgm.Message> _inner;
  final void Function(pgm.Message message) _observe;

  @override
  void add(pgm.Message event) {
    _observe(event);
    _inner.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<pgm.Message> stream) => _inner.addStream(
    stream.map((message) {
      _observe(message);
      return message;
    }),
  );

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> get done => _inner.done;
}

/// A bounded set of connections.
///
/// The driver's own pool disposes a connection whenever an exception leaves its
/// callback — every unique violation would cost a reconnect — and cannot
/// keep prepared statements across borrows. This one keeps connections (and
/// their statement caches) until they are actually broken, and hands the most
/// recently used one out first so its cache stays warm.
@internal
final class DwConnectionPool {
  DwConnectionPool(this._config, {DwRoundTripCounter? counter})
    : _counter = counter;

  final DwDatabaseConfig _config;
  final DwRoundTripCounter? _counter;
  final List<DwPooledConnection> _idle = [];
  final Queue<_Waiter> _waiters = Queue();
  int _open = 0;
  bool _closed = false;

  Future<DwPooledConnection> acquire() async {
    if (_closed) throw StateError('the database is closed');
    while (_idle.isNotEmpty) {
      final connection = _idle.removeLast();
      if (connection.isOpen) return connection;
      _open--;
    }
    if (_open < _config.maxConnections) return _connect();

    final waiter = _Waiter();
    waiter.timer = Timer(_config.connectTimeout, () {
      if (_waiters.remove(waiter)) {
        waiter.completer.completeError(
          DwDatabaseException(
            null,
            'no database connection became free within '
            '${_config.connectTimeout} (maxConnections: ${_config.maxConnections})',
          ),
        );
      }
    });
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  /// Returns [connection]. A connection whose session state is unknown — a
  /// failed `ROLLBACK`, a lost socket — must be released with [discard].
  void release(DwPooledConnection connection, {bool discard = false}) {
    if (_closed || discard || !connection.isOpen) {
      _open--;
      connection.close().ignore();
      _connectForWaiter();
      return;
    }
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst()..timer.cancel();
      waiter.completer.complete(connection);
    } else {
      _idle.add(connection);
    }
  }

  Future<DwPooledConnection> _connect() async {
    _open++;
    try {
      return await DwPooledConnection.open(_config, counter: _counter);
    } catch (_) {
      _open--;
      // The slot this attempt held is free again; a caller queued behind it
      // must not wait out its timeout for capacity that exists.
      _connectForWaiter();
      rethrow;
    }
  }

  /// Opens a connection for the first waiter when a slot became free.
  void _connectForWaiter() {
    if (_closed || _waiters.isEmpty || _open >= _config.maxConnections) return;
    final waiter = _waiters.removeFirst()..timer.cancel();
    _connect().then(
      waiter.completer.complete,
      onError: waiter.completer.completeError,
    );
  }

  Future<void> close() async {
    _closed = true;
    for (final waiter in _waiters) {
      waiter.timer.cancel();
      waiter.completer.completeError(StateError('the database is closed'));
    }
    _waiters.clear();
    final idle = [..._idle];
    _idle.clear();
    _open -= idle.length;
    await Future.wait([for (final connection in idle) connection.close()]);
  }
}

final class _Waiter {
  final Completer<DwPooledConnection> completer = Completer();
  late final Timer timer;
}
