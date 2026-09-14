import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart'
    hide DwNotAuthenticatedException;
import 'package:dartway_orm/dartway_orm.dart';

import '../server/dw_app_server.dart';

/// A throwaway database for one test file: created empty, dropped after.
final class DwTestDatabase {
  DwTestDatabase._(this._admin, this.config);

  final DwDatabaseConfig _admin;

  /// Points at the new database; pass it to `DwAppServer(database: …)`.
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
    final database = await DwPostgresDatabase.open(
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
    final database = await DwPostgresDatabase.open(
      _admin.copyWith(maxConnections: 1),
    );
    try {
      await database.db.execute(
        'DROP DATABASE IF EXISTS "${config.name}" WITH (FORCE)',
      );
    } finally {
      await database.close();
    }
  }
}

/// A server started inside a test, on a free loopback port. Tests speak the
/// wire through [caller] and [openLive], or use the app's own client through
/// [connectClient].
final class DwTestServer {
  DwTestServer._(this.server);

  final DwAppServer server;

  final List<DwAppClient> _clients = [];

  /// Starts [server] on port 0 of the loopback interface, without signal
  /// handling (the test runner owns the process).
  static Future<DwTestServer> start(DwAppServer server) async {
    await server.startOn(
      port: 0,
      address: InternetAddress.loopbackIPv4,
      handleSignals: false,
    );
    return DwTestServer._(server);
  }

  int get port => server.boundPort;

  /// The base of every HTTP path: calls, `/health` and project routes.
  Uri get httpBase => Uri.parse('http://127.0.0.1:$port');

  /// The live socket, with the protocol and app version a current client
  /// sends.
  Uri get liveEndpoint => liveEndpointWith();

  /// The live socket with the given query; a `null` value leaves the
  /// parameter out.
  Uri liveEndpointWith({
    String? protocol = '$dwProtocolVersion',
    String? app = DwTestCaller.defaultAppVersion,
  }) => Uri(
    scheme: 'ws',
    host: '127.0.0.1',
    port: port,
    path: DwHttpContract.livePath,
    queryParameters: {
      DwHttpContract.liveProtocolParameter: ?protocol,
      DwHttpContract.liveAppVersionParameter: ?app,
    },
  );

  DwDatabaseHandle get db => server.db;

  DwWireProtocol get protocol => server.protocol;

  /// Wakes the job executor now.
  void wakeJobs() => server.wakeJobs();

  /// A raw HTTP caller of this server, optionally signed in with [token].
  DwTestCaller caller({String? token}) =>
      DwTestCaller(httpBase, protocol, token: token);

  /// Opens a raw live socket. With [awaitHello] (the default) the returned
  /// socket has read its `hello` and knows its [DwTestLiveSocket.connectionId].
  Future<DwTestLiveSocket> openLive({
    Uri? endpoint,
    Map<String, Object>? headers,
    bool awaitHello = true,
  }) async {
    final socket = await WebSocket.connect(
      (endpoint ?? liveEndpoint).toString(),
      headers: headers,
    );
    final live = DwTestLiveSocket._(socket, protocol);
    if (awaitHello) await live._readHello();
    return live;
  }

  /// A real `DwAppClient` of this server, started: calls over real HTTP and
  /// the real live socket, nothing in between — what an app does, against
  /// this server. Stopped by [stop], or by the test earlier.
  ///
  /// [options] defaults to [dwTestClientOptions]: short retries and no
  /// release or idle delay, so a test sees the effects of what it did at
  /// once. [httpTransport], [liveConnector] and [storageTransport] wrap the
  /// real ones when a test needs to lose an answer or watch the frames; [onError] receives what the
  /// client reports (by default the zone's uncaught-error handler, which
  /// fails the test).
  Future<DwAppClient> connectClient({
    DwTokenStore? tokenStore,
    DwClientOptions options = dwTestClientOptions,
    String appVersion = DwTestCaller.defaultAppVersion,
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
    DwStorageTransport? storageTransport,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final client = DwAppClient(
      protocol: protocol,
      baseUrl: httpBase,
      appVersion: appVersion,
      tokenStore: tokenStore,
      httpTransport: httpTransport,
      liveConnector: liveConnector,
      storageTransport: storageTransport,
      options: options,
      onError: onError,
    );
    _clients.add(client);
    await client.start();
    return client;
  }

  /// Stops every client from [connectClient], then the server: a client
  /// stopped after its server would spend its last moments reconnecting.
  Future<void> stop() async {
    for (final client in _clients) {
      await client.stop();
    }
    _clients.clear();
    await server.stop();
  }
}

/// Client timings for tests against a real test server: retries within
/// milliseconds, entries and the socket released at once, and a call
/// deadline long enough for a database under a loaded test run.
const DwClientOptions dwTestClientOptions = DwClientOptions(
  retryDelay: Duration(milliseconds: 20),
  maxRetryDelay: Duration(milliseconds: 200),
  releaseDelay: Duration.zero,
  liveIdleDelay: Duration.zero,
  liveSettleTimeout: Duration(seconds: 2),
  callTimeout: Duration(seconds: 10),
);

/// What a raw call came back with: the HTTP status and headers, the body,
/// and the body read as a `DwApiResponse`.
final class DwTestAnswer {
  DwTestAnswer._(this.status, this.headers, this.text, this._protocol);

  final int status;
  final HttpHeaders headers;
  final String text;
  final DwWireProtocol _protocol;

  /// The body as JSON; throws [FormatException] when it is not.
  Object? get json => jsonDecode(text);

  /// The body as the response it must be for its status: throws
  /// [FormatException] when the body and the status disagree.
  DwApiResponse get response => DwApiResponse.fromHttp(status, json, _protocol);

  /// The result of an ok answer, decoded by [call]; throws [StateError] for
  /// any other answer.
  R value<R>(DwServerCall<R> call) => switch (response) {
    DwApiOk(:final result) => call.decodeResult(result, _protocol),
    final other => throw StateError('expected ok, got $other ($status)'),
  };

  /// The updates of an ok answer.
  DwUpdateTransport get updates => switch (response) {
    DwApiOk(:final updates) => updates,
    final other => throw StateError('expected ok, got $other ($status)'),
  };

  /// The refusal of a refused or incompatible answer.
  DwCallRefusal get refusal => switch (response) {
    DwApiRefused(:final refusal) ||
    DwApiIncompatible(:final refusal) => refusal,
    final other => throw StateError('expected a refusal, got $other'),
  };

  @override
  String toString() => 'DwTestAnswer($status, $text)';
}

/// Sends calls to a server as a DartWay client would — the path, the headers
/// and the body of R2.2 — and reads what comes back, without a client
/// library: the tests check the wire itself.
final class DwTestCaller {
  DwTestCaller(this.base, this.protocol, {this.token, this.liveConnection});

  /// The app version a current client sends.
  static const String defaultAppVersion = '1.0.0+1';

  final Uri base;
  final DwWireProtocol protocol;

  /// The bearer token sent with every call; `null` calls anonymously.
  String? token;

  /// The live connection id sent with every call; `null` sends none.
  String? liveConnection;

  final HttpClient _client = HttpClient();

  static int _keys = 0;

  /// A unique idempotency key.
  static String newKey() =>
      'k${DateTime.now().microsecondsSinceEpoch}-${++_keys}';

  /// Sends [call]. A command gets a fresh idempotency key unless [key] names
  /// one. [headers] overrides the headers a client sends, a `null` value
  /// leaving one out; [body] replaces the call's JSON with raw bytes.
  Future<DwTestAnswer> call(
    DwServerCall<Object?> call, {
    String? key,
    Map<String, String> query = const {},
    Map<String, String?> headers = const {},
    List<int>? body,
    String? path,
  }) => raw(
    DwHttpContract.callMethod,
    path ?? DwHttpContract.callPath(call.dwTypeName),
    query: query,
    headers: {
      DwHttpContract.protocolHeader: '$dwProtocolVersion',
      DwHttpContract.appVersionHeader: defaultAppVersion,
      DwHttpContract.contentTypeHeader: DwHttpContract.jsonContentType,
      if (token != null)
        DwHttpContract.authorizationHeader:
            '${DwHttpContract.bearerPrefix}$token',
      if (call is DwActionCommand<Object?>)
        DwHttpContract.idempotencyKeyHeader: key ?? newKey(),
      DwHttpContract.liveConnectionHeader: ?liveConnection,
      ...headers,
    },
    body: body ?? utf8.encode(jsonEncode(call.toJson())),
  );

  /// Sends any request; a `null` header value is left out.
  Future<DwTestAnswer> raw(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, String?> headers = const {},
    List<int>? body,
  }) async {
    final uri = base.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    final request = await _client.openUrl(method, uri);
    for (final MapEntry(:key, :value) in headers.entries) {
      if (value != null) request.headers.set(key, value);
    }
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return DwTestAnswer._(
      response.statusCode,
      response.headers,
      text,
      protocol,
    );
  }

  void close() => _client.close(force: true);
}

/// One raw live socket speaking the live messages, for tests that check
/// exactly what crosses it.
///
/// Incoming messages are buffered; the `expect…`/`waitFor` calls take the
/// first matching one, so messages can be awaited in any order.
final class DwTestLiveSocket {
  DwTestLiveSocket._(this._socket, this.protocol) {
    _subscription = _socket.listen(
      (frame) {
        frames.add(frame as String);
        _inbox.add(DwServerMessage.fromJson(jsonDecode(frame), protocol));
        _notify();
      },
      onDone: () {
        _closed.complete(_socket.closeCode);
        _notify();
      },
    );
  }

  final WebSocket _socket;
  final DwWireProtocol protocol;
  late final StreamSubscription<Object?> _subscription;
  final Queue<DwServerMessage> _inbox = Queue();
  final Completer<int?> _closed = Completer();
  Completer<void>? _arrival;

  /// The id from the server's `hello`; set once it has been read.
  late final String connectionId;

  /// Every frame received, as text, in order.
  final List<String> frames = [];

  /// Completes with the close code when the socket closes.
  Future<int?> get closeCode => _closed.future;

  String? get closeReason => _socket.closeReason;

  bool get isClosed => _closed.isCompleted;

  void _notify() {
    _arrival?.complete();
    _arrival = null;
  }

  Future<void> _readHello() async {
    connectionId = (await expect<DwHelloMessage>()).connectionId;
  }

  /// Sends a live message.
  void send(DwClientMessage message) =>
      _socket.add(jsonEncode(message.toJson()));

  /// Sends a raw text or binary frame.
  void sendRaw(Object frame) => _socket.add(frame);

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
          'the socket closed (${_socket.closeCode} ${_socket.closeReason}) '
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

  Future<void> close([int code = 1000]) => _socket.close(code);
}
