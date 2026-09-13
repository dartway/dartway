import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_orm/dartway_orm.dart';

import '../server/dw_server.dart';

/// A throwaway database for one test file: created empty, dropped after.
final class DwTestDatabase {
  DwTestDatabase._(this._admin, this.config);

  final DwDatabaseConfig _admin;

  /// Points at the new database; pass it to `DwServer(database: …)`.
  final DwDatabaseConfig config;

  /// Creates a database named `<prefix>_<random>` on the server described by
  /// [admin] (by default `DW_DATABASE_*` from the environment, whose `NAME`
  /// is the maintenance database the statement runs in).
  static Future<DwTestDatabase> create({
    DwDatabaseConfig? admin,
    String prefix = 'dw_test',
  }) async {
    final adminConfig =
        admin ?? DwDatabaseConfig.fromEnvironment(Platform.environment);
    final random = Random.secure();
    final suffix = List.generate(
      10,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)],
    ).join();
    final name = '${prefix}_$suffix';
    final database = await DwDatabase.open(
      adminConfig.copyWith(maxConnections: 1),
    );
    try {
      await database.db.execute('CREATE DATABASE "$name"');
    } finally {
      await database.close();
    }
    return DwTestDatabase._(adminConfig, adminConfig.copyWith(name: name));
  }

  /// Drops the database, disconnecting whatever still holds it.
  Future<void> drop() async {
    final database = await DwDatabase.open(_admin.copyWith(maxConnections: 1));
    try {
      await database.db.execute(
        'DROP DATABASE IF EXISTS "${config.name}" WITH (FORCE)',
      );
    } finally {
      await database.close();
    }
  }
}

/// A server started inside a test, on a free loopback port.
final class DwTestServer {
  DwTestServer._(this.server);

  final DwServer server;

  /// Starts [server] on port 0 of the loopback interface, without signal
  /// handling (the test runner owns the process).
  static Future<DwTestServer> start(DwServer server) async {
    await server.startOn(
      port: 0,
      address: InternetAddress.loopbackIPv4,
      handleSignals: false,
    );
    return DwTestServer._(server);
  }

  int get port => server.boundPort;

  /// The app WebSocket, with the wire version.
  Uri get endpoint => Uri.parse('ws://127.0.0.1:$port/dw?v=$dwWireVersion');

  /// The base of the HTTP routes.
  Uri get httpBase => Uri.parse('http://127.0.0.1:$port');

  DwDb get db => server.db;

  DwProtocol get protocol => server.protocol;

  /// Wakes the job executor now.
  void wakeJobs() => server.wakeJobs();

  /// Opens a raw wire connection. [version] `null` omits it.
  Future<DwTestConnection> connect({
    int? version = dwWireVersion,
    Map<String, Object>? headers,
  }) async {
    final uri = Uri.parse(
      'ws://127.0.0.1:$port/dw${version == null ? '' : '?v=$version'}',
    );
    final socket = await WebSocket.connect(uri.toString(), headers: headers);
    return DwTestConnection._(socket, protocol);
  }

  /// A started `DwClient` on this server over a real socket. Stop it before
  /// the server.
  Future<DwClient> connectClient({
    DwTokenStore? tokenStore,
    DwClientOptions options = const DwClientOptions(),
  }) async {
    final client = DwClient(
      protocol: protocol,
      endpoint: endpoint,
      tokenStore: tokenStore,
      options: options,
    );
    await client.start();
    return client;
  }

  Future<void> stop() => server.stop();
}

/// One raw app WebSocket speaking `dartway_core` wire messages, for tests
/// that check exactly what crosses the wire.
///
/// Incoming messages are buffered; the `expect…`/`waitFor` calls take the
/// first matching one, so a result and an update can be awaited in either
/// order.
final class DwTestConnection {
  DwTestConnection._(this._socket, this.protocol) {
    _subscription = _socket.listen(
      (frame) {
        final message = DwServerMessage.fromJson(
          jsonDecode(frame as String) as Map<String, Object?>,
          protocol,
        );
        frames.add(frame);
        _inbox.add(message);
        _notify();
      },
      onDone: () {
        _closed.complete(_socket.closeCode);
        _notify();
      },
    );
  }

  final WebSocket _socket;
  final DwProtocol protocol;
  late final StreamSubscription<Object?> _subscription;
  final Queue<DwServerMessage> _inbox = Queue();
  final Completer<int?> _closed = Completer();
  Completer<void>? _arrival;
  int _nextId = 0;

  /// Every frame received, as text, in order (for byte-level assertions).
  final List<String> frames = [];

  /// Completes with the close code when the server closes the socket.
  Future<int?> get closeCode => _closed.future;

  String? get closeReason => _socket.closeReason;

  bool get isClosed => _closed.isCompleted;

  void _notify() {
    _arrival?.complete();
    _arrival = null;
  }

  /// Sends a wire message.
  void send(DwClientMessage message) =>
      _socket.add(jsonEncode(message.toJson(protocol)));

  /// Sends raw text (protocol violation tests).
  void sendRaw(String text) => _socket.add(text);

  /// The first buffered or arriving message that satisfies [test].
  Future<DwServerMessage> waitFor(
    bool Function(DwServerMessage message) test, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      for (final message in _inbox) {
        if (test(message)) {
          _inbox.remove(message);
          return message;
        }
      }
      if (_closed.isCompleted) {
        throw StateError(
          'connection closed (${_socket.closeCode} ${_socket.closeReason}) '
          'while waiting; buffered: ${_inbox.length}',
        );
      }
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        throw TimeoutException('no matching message; buffered: $_inbox');
      }
      await (_arrival ??= Completer<void>()).future.timeout(
        left,
        onTimeout: () {},
      );
    }
  }

  Future<T> expect<T extends DwServerMessage>({
    bool Function(T message)? where,
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      await waitFor(
            (m) => m is T && (where == null || where(m)),
            timeout: timeout,
          )
          as T;

  /// Asserts that nothing arrives within [period] (and nothing is buffered).
  Future<void> expectSilence([
    Duration period = const Duration(milliseconds: 300),
  ]) async {
    await Future<void>.delayed(period);
    if (_inbox.isNotEmpty) {
      throw StateError('expected silence, got ${_inbox.toList()}');
    }
  }

  /// Messages buffered and not yet taken.
  List<DwServerMessage> get buffered => List.unmodifiable(_inbox);

  Future<DwAuthenticatedMessage> authenticate(String? token) {
    send(DwAuthenticateMessage(token));
    return expect<DwAuthenticatedMessage>();
  }

  /// Runs [request] and returns its raw result message.
  Future<DwResultMessage> request(
    DwRequest<Object?> request, {
    DwPageParams? page,
  }) {
    final id = ++_nextId;
    send(DwRequestMessage(id: id, request: request, page: page));
    return expect<DwResultMessage>(where: (m) => m.id == id);
  }

  /// Runs [command] with [key] (a fresh one when omitted).
  Future<DwResultMessage> command(DwCommand<Object?> command, {String? key}) {
    final id = ++_nextId;
    send(
      DwCommandMessage(
        id: id,
        idempotencyKey: key ?? newKey(),
        command: command,
      ),
    );
    return expect<DwResultMessage>(where: (m) => m.id == id);
  }

  /// Subscribes and returns the answer (`DwSubscribedMessage` or
  /// `DwSubscriptionRefusedMessage`).
  Future<DwServerMessage> subscribe(String channel) {
    send(DwSubscribeMessage(channel));
    return waitFor(
      (m) =>
          (m is DwSubscribedMessage && m.channel == channel) ||
          (m is DwSubscriptionRefusedMessage && m.channel == channel),
    );
  }

  void unsubscribe(String channel) => send(DwUnsubscribeMessage(channel));

  /// Stops reading from the socket (a slow consumer).
  void pause() => _subscription.pause();

  void resume() => _subscription.resume();

  Future<void> close([int code = 1000]) async {
    await _socket.close(code);
  }

  static int _keys = 0;

  /// A unique idempotency key.
  static String newKey() =>
      'k${DateTime.now().microsecondsSinceEpoch}-${++_keys}';
}

/// The value of an ok result, decoded by the call's class.
extension DwTestResults on DwResultMessage {
  R okValue<R>(DwRequest<R> request, DwProtocol protocol) {
    if (status != DwResultStatus.ok) {
      throw StateError(
        'expected ok, got $status ${refusal ?? incidentId ?? ''}',
      );
    }
    return request.decodeResult(value, protocol);
  }

  R okCommandValue<R>(DwCommand<R> command, DwProtocol protocol) {
    if (status != DwResultStatus.ok) {
      throw StateError(
        'expected ok, got $status ${refusal ?? incidentId ?? ''}',
      );
    }
    return command.decodeResult(value, protocol);
  }
}
