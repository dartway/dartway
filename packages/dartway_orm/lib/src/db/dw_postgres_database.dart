import 'dart:async';

import 'package:postgres/postgres.dart' as pg;

import 'dw_connection_pool.dart';
import 'dw_database_config.dart';
import 'dw_database_handle.dart';
import 'dw_errors.dart';

/// An open database: the connection pool and the handle bound to it.
final class DwPostgresDatabase {
  DwPostgresDatabase._(this.config, this._pool, this._counter)
    : db = DwPoolDb(_pool);

  /// Opens the pool and proves the database is reachable with one real
  /// connection, so a wrong password fails at startup rather than at the
  /// first request.
  ///
  /// [countRoundTrips] makes [roundTrips] available — for tests asserting
  /// that an operation costs no more than it should.
  static Future<DwPostgresDatabase> open(
    DwDatabaseConfig config, {
    bool countRoundTrips = false,
  }) async {
    // The constructor is const and can only assert; a release build must not
    // open a pool that never hands out a connection.
    if (config.maxConnections < 1 || config.statementCacheSize < 1) {
      throw ArgumentError(
        'maxConnections and statementCacheSize must be positive: $config',
      );
    }
    final counter = countRoundTrips ? DwRoundTripCounter() : null;
    final pool = DwConnectionPool(config, counter: counter);
    pool.release(await pool.acquire());
    return DwPostgresDatabase._(config, pool, counter);
  }

  final DwDatabaseConfig config;
  final DwConnectionPool _pool;
  final DwRoundTripCounter? _counter;

  /// The pool-bound handle.
  final DwDatabaseHandle db;

  final List<_DwListener> _listeners = [];

  /// Server round trips completed since [open].
  int get roundTrips {
    final counter = _counter;
    if (counter == null) {
      throw StateError('open the database with countRoundTrips: true');
    }
    return counter.count;
  }

  /// Notifications on [channel], received on a dedicated connection.
  ///
  /// Pooled connections cannot listen: a `LISTEN` belongs to one session.
  /// The future completes once the server has registered the `LISTEN`, so a
  /// notification sent after that is never missed — and fails when the first
  /// connection cannot be made. Later, when the connection drops, it is
  /// reopened and the stream goes on; notifications sent meanwhile are lost,
  /// so a consumer must also poll what it waits for. A failed reconnect is
  /// added to the stream as an error and retried with backoff.
  ///
  /// Cancelling the subscription closes the connection.
  Future<Stream<String>> listen(String channel) async {
    final listener = _DwListener(config, channel);
    _listeners.add(listener);
    try {
      await listener.connect();
    } catch (_) {
      _listeners.remove(listener);
      await listener.stop();
      rethrow;
    }
    listener.onStop = () => _listeners.remove(listener);
    return listener.stream;
  }

  Future<void> close() async {
    await Future.wait([
      for (final listener in [..._listeners]) listener.stop(),
      _pool.close(),
    ]);
    _listeners.clear();
  }
}

final class _DwListener {
  _DwListener(this._config, this._channel) {
    _controller = StreamController<String>(onCancel: stop);
  }

  final DwDatabaseConfig _config;
  final String _channel;
  late final StreamController<String> _controller;
  pg.Connection? _connection;
  bool _stopped = false;
  void Function()? onStop;

  Stream<String> get stream => _controller.stream;

  Future<void> connect() async {
    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: _config.host,
        port: _config.port,
        database: _config.name,
        username: _config.user,
        password: _config.password,
      ),
      settings: pg.ConnectionSettings(
        // The same choice the pool makes (`dwSslMode`/`dwSecurityContext` in
        // dw_connection_pool.dart) — not a second copy of it. A `LISTEN`
        // session cannot be pooled, but it must still verify a configured CA
        // exactly as every pooled connection does; a session that skipped it
        // would authenticate unverified while the rest of the database did
        // not.
        sslMode: dwSslMode(_config),
        securityContext: dwSecurityContext(_config),
        applicationName: '${_config.applicationName}-listen',
        connectTimeout: _config.connectTimeout,
      ),
    );
    if (_stopped) {
      await connection.close();
      return;
    }
    _connection = connection;
    // A raw LISTEN rather than `channels[...]`: the driver sends that one
    // lazily, and the caller is promised the registration is done.
    connection.channels.all
        .where((notification) => notification.channel == _channel)
        .listen((notification) => _controller.add(notification.payload));
    await connection.execute('LISTEN "${_channel.replaceAll('"', '""')}"');
    connection.closed.then((_) => _reconnect()).ignore();
  }

  Future<void> _reconnect() async {
    _connection = null;
    var delay = const Duration(milliseconds: 200);
    while (!_stopped) {
      await Future<void>.delayed(delay);
      if (_stopped) return;
      try {
        await connect();
        return;
      } catch (error, stackTrace) {
        if (!_stopped) _controller.addError(dwMapError(error), stackTrace);
      }
      if (delay < const Duration(seconds: 30)) delay *= 2;
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    onStop?.call();
    await _connection?.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
