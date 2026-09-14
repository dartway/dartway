import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../client/dw_app_client.dart';
import '../dw_client_options.dart';
import '../session/dw_token_store.dart';
import '../transport/dw_http_transport.dart';
import '../transport/dw_live_connection.dart';
import '../transport/dw_storage_transport.dart';

/// A handler of the fake server: the outcome of one call.
///
/// The value of a [DwCallOk] must have the call's result type exactly —
/// `DwCallOk(<RoomView>[])`, not `DwCallOk([])` — because it is encoded by the
/// call's class, as on a real server. Throwing [DwRefusalException] refuses;
/// throwing anything else fails the call and is recorded in
/// [DwFakeServer.errors].
typedef DwFakeHandler<C> =
    FutureOr<DwCallResult<Object?>> Function(C call, DwFakeCall context);

/// What a fake handler knows about the call, and how it publishes.
final class DwFakeCall {
  DwFakeCall._(
    this._server,
    this.accountId,
    this.token,
    this.page,
    this.idempotencyKey,
    this.liveConnection,
    this.appVersion,
    this.headers,
  );

  final DwFakeServer _server;

  /// The caller's account; `null` for an anonymous call.
  final int? accountId;

  final String? token;

  /// The page a paginated request asked for.
  final DwPageQuery? page;

  /// The key of a command.
  final String? idempotencyKey;

  /// The live connection the call named in `Dw-Live-Connection`, when it is
  /// open.
  final DwFakeConnection? liveConnection;

  final DwAppVersion appVersion;

  /// Every header as it arrived, names in lower case.
  final Map<String, String> headers;

  final List<(DwLiveChannel, List<DwWireObject>)> _published = [];

  /// Publishes [objects] to [channel] when the call ends, as a real server
  /// does.
  ///
  /// When the call succeeds, every subscribed connection receives them over
  /// the socket except the one the call named, and the response carries them
  /// under [channel] (D-036):
  /// all of them when the call named no connection, those of channels the
  /// named connection is subscribed to otherwise. When it does not, the
  /// response carries nothing and every subscriber — the named connection
  /// included — receives them over the socket.
  ///
  /// An unresolved `DwLiveChannel.ofCaller` throws [ArgumentError], as on a
  /// real server: publish to `DwLiveChannel.forAccount(kind, accountId)`.
  void publish(DwLiveChannel channel, List<DwWireObject> objects) {
    if (channel.isOfCaller) {
      throw ArgumentError.value(
        channel,
        'channel',
        'A caller channel is resolved by the client for whoever watches. '
            'Name the account: DwLiveChannel.forAccount('
            '${channel.kind.channelName}, accountId)',
      );
    }
    _published.add((channel, objects));
  }

  /// Whether the caller's account is [accountId].
  bool isAccount(int accountId) => this.accountId == accountId;

  DwFakeServer get server => _server;
}

/// One live connection as the fake server sees it.
final class DwFakeConnection {
  DwFakeConnection._(this._server, this._end, this.url, this.id);

  final DwFakeServer _server;
  final DwLiveConnection _end;

  /// The upgrade URL, query included.
  final Uri url;

  /// The id sent in `hello`.
  final String id;

  int? accountId;
  String? token;
  bool isOpen = true;

  /// Wire names of the channels this connection is subscribed to.
  final Set<String> subscriptions = {};

  /// Sends [message] to the client as the server would.
  void send(DwServerMessage message) {
    if (!isOpen) return;
    try {
      _end.send(jsonEncode(message.toJson()));
      _server.sent.add(message);
    } on StateError {
      // Closed and not yet noticed: the frame is lost, as on a socket.
    }
  }

  /// Sends a raw frame — for tests of what a client does with a message it
  /// cannot read.
  void sendFrame(String frame) {
    try {
      if (isOpen) _end.send(frame);
    } on StateError {
      // Closed: lost.
    }
  }

  /// Drops the connection from the server side, with a WebSocket close
  /// [code] and [reason] when given.
  Future<void> close({int? code, String? reason}) => _end.close(code, reason);
}

/// One call the fake server answered.
final class DwFakeRecordedCall {
  const DwFakeRecordedCall._({
    required this.wireName,
    required this.call,
    required this.headers,
    required this.query,
    required this.status,
    required this.response,
  });

  final String wireName;

  /// The decoded DTO; `null` when the body did not decode.
  final DwServerCall<Object?>? call;

  /// Header names in lower case.
  final Map<String, String> headers;
  final Map<String, String> query;
  final int status;
  final DwApiResponse response;

  String? get idempotencyKey =>
      headers[DwHttpContract.idempotencyKeyHeader.toLowerCase()];

  String? get liveConnectionId =>
      headers[DwHttpContract.liveConnectionHeader.toLowerCase()];

  String? get authorization =>
      headers[DwHttpContract.authorizationHeader.toLowerCase()];

  @override
  String toString() => 'DwFakeRecordedCall($wireName, $status)';
}

/// The network failure the fake transport throws while
/// [DwFakeServer.reachable] is false.
final class DwFakeNetworkException implements Exception {
  const DwFakeNetworkException();

  @override
  String toString() => 'DwFakeNetworkException(the fake server is unreachable)';
}

/// An in-memory DartWay server for tests of the client and of the screens on
/// top of it: the HTTP contract through [httpTransport] and the live socket
/// through [liveConnector].
///
/// Not the real server: handlers are closures registered per DTO type, there
/// is no database and no access rule beyond what a test declares. What it
/// reproduces is the protocol as `dartway_core_server` speaks it — headers and
/// their checks, honest statuses, `426` for an incompatible build,
/// idempotent commands, the response transport filtered by
/// `Dw-Live-Connection`, hello and authentication on the socket, a changed
/// account closing subscriptions, key revocation, subscriptions and their
/// accounting — so a client talks to it exactly as to a real one.
///
/// ```dart
/// final server = DwFakeServer(protocol: appProtocol)
///   ..onRequest<ListRooms>((request, call) => DwCallOk(rooms));
/// final client = server.newClient();
/// await client.start();
/// ```
final class DwFakeServer {
  DwFakeServer({required this.protocol, this.minAppBuild = 0});

  final DwWireProtocol protocol;

  /// Builds below this answer `426` with `dw.updateRequired`, on calls and on
  /// the live upgrade.
  int minAppBuild;

  /// The protocol version this server speaks.
  int protocolVersion = dwProtocolVersion;

  /// The address clients of this server use. Informational: [httpTransport]
  /// and [liveConnector] are what reach it.
  final Uri baseUrl = Uri.parse('http://dartway.test');

  /// Carries calls to this server in memory.
  late final DwMemoryHttpTransport httpTransport = DwMemoryHttpTransport(
    _onPost,
  );

  /// Connects live sockets to this server in memory.
  late final DwMemoryLiveConnector liveConnector = DwMemoryLiveConnector(
    _accept,
  );

  /// While false, every call fails on the network.
  bool reachable = true;

  /// While false, live connection attempts fail as against an unreachable
  /// server.
  bool acceptsConnections = true;

  /// Answers a call before the server does — a proxy's error page, say. A
  /// `null` answer lets the server handle it.
  FutureOr<DwHttpReply?> Function(DwHttpPost post)? interceptPost;

  /// Every live connection ever accepted, open or not.
  final List<DwFakeConnection> connections = [];

  Iterable<DwFakeConnection> get openConnections =>
      connections.where((connection) => connection.isOpen);

  /// Every call answered, in arrival order.
  final List<DwFakeRecordedCall> calls = [];

  /// Every live message received from any client, in arrival order.
  final List<DwClientMessage> received = [];

  /// Every live message sent to any client.
  final List<DwServerMessage> sent = [];

  /// Handler exceptions, calls nobody registered a handler for, and messages
  /// that do not decode. A test that expects none asserts this is empty: a
  /// fake that swallowed them would let a broken test pass.
  final List<Object> errors = [];

  /// Decides a subscription of a signed-in connection: `null` allows it, a
  /// refusal refuses it.
  DwCallRefusal? Function(String channel, DwFakeConnection connection)?
  subscriptionRule;

  /// Every subscription needs a signed-in connection, as on a real server
  /// (D-020).
  bool subscriptionsRequireAccount = true;

  /// Channels whose subscription check fails, as a throwing rule does on a
  /// real server: answered as a failure with [subscriptionIncident].
  final Set<String> failingChannels = {};

  static const String subscriptionIncident = 'fake-subscription-failed';

  final Map<String, int> _tokens = {};
  final Map<Type, DwFakeHandler<DwServerCall<Object?>>> _requests = {};
  final Map<Type, DwFakeHandler<DwServerCall<Object?>>> _commands = {};
  final Map<String, DwApiResponse> _outcomes = {};
  final Map<String, int> _executions = {};
  final Map<String, int> _subscribes = {};
  final Map<String, int> _unsubscribes = {};
  int _nextConnection = 1;

  /// A client of this server — not started, with timings short enough for
  /// tests unless [options] says otherwise.
  DwAppClient newClient({
    DwTokenStore? tokenStore,
    String appVersion = '1.0.0+1',
    DwClientOptions options = dwFakeClientOptions,
    void Function(Object error, StackTrace stackTrace)? onError,
    DwStorageTransport? storageTransport,
  }) => DwAppClient(
    protocol: protocol,
    baseUrl: baseUrl,
    appVersion: appVersion,
    httpTransport: httpTransport,
    liveConnector: liveConnector,
    storageTransport: storageTransport,
    tokenStore: tokenStore,
    options: options,
    onError: onError,
    // Keys and jitter in a test need no secure source, and not every test
    // platform has one (Node under dart2js does not).
    random: Random(),
  );

  // --- handlers -------------------------------------------------------------

  /// Answers requests of type [Q].
  void onRequest<Q extends DwDataRequest<Object?>>(DwFakeHandler<Q> handle) {
    _requests[Q] = (request, call) => handle(request as Q, call);
  }

  /// Answers commands of type [C]. A command runs once per idempotency key;
  /// a repeat answers the stored outcome unless it failed.
  void onCommand<C extends DwActionCommand<Object?>>(DwFakeHandler<C> handle) {
    _commands[C] = (command, call) => handle(command as C, call);
  }

  // --- auth -----------------------------------------------------------------

  /// Makes [token] valid for [accountId].
  void registerToken(String token, int accountId) => _tokens[token] = accountId;

  /// Makes [token] invalid, as revoking a key does on a real server: every
  /// open connection bound to it loses its subscriptions (`closed` for each)
  /// and its session (`authed` with `rejected`, unasked).
  void revokeToken(String token) {
    _tokens.remove(token);
    for (final connection in openConnections.toList()) {
      if (connection.token != token) continue;
      _bind(connection, null, null);
      connection.send(const DwAuthenticatedMessage.rejected());
    }
  }

  bool isTokenValid(String token) => _tokens.containsKey(token);

  /// Binds [connection] to an account, or to none. A changed account closes
  /// every subscription — access was checked for the previous one — and says
  /// so with `closed`.
  void _bind(DwFakeConnection connection, int? accountId, String? token) {
    if (connection.accountId != accountId) {
      for (final channel in connection.subscriptions.toList()) {
        connection.subscriptions.remove(channel);
        connection.send(DwChannelClosedMessage(channel));
      }
    }
    connection
      ..accountId = accountId
      ..token = token;
  }

  // --- channels -------------------------------------------------------------

  /// How many `sub` messages arrived for [channel], from any connection.
  int subscribeCount(DwLiveChannel channel) =>
      _subscribes[channel.wireName] ?? 0;

  /// How many `unsub` messages arrived for [channel].
  int unsubscribeCount(DwLiveChannel channel) =>
      _unsubscribes[channel.wireName] ?? 0;

  /// How many open connections are subscribed to [channel].
  int subscriberCount(DwLiveChannel channel) => openConnections
      .where((c) => c.subscriptions.contains(channel.wireName))
      .length;

  /// Publishes [objects] to every open connection subscribed to [channel]:
  /// an update from someone else, outside any call of the client under test.
  void publish(DwLiveChannel channel, List<DwWireObject> objects) =>
      _broadcast(channel.wireName, objects, except: null);

  void _broadcast(
    String channel,
    List<DwWireObject> objects, {
    required DwFakeConnection? except,
  }) {
    final updates = DwChannelUpdates(objects);
    if (updates.isEmpty) return;
    for (final connection in openConnections.toList()) {
      if (identical(connection, except)) continue;
      if (!connection.subscriptions.contains(channel)) continue;
      connection.send(DwUpdateMessage(channel: channel, updates: updates));
    }
  }

  /// Closes [channel] for every subscribed connection, or only for those of
  /// [accountId] — what revoking access does.
  void closeChannel(DwLiveChannel channel, {int? accountId}) {
    for (final connection in openConnections.toList()) {
      if (accountId != null && connection.accountId != accountId) continue;
      if (!connection.subscriptions.remove(channel.wireName)) continue;
      connection.send(DwChannelClosedMessage(channel.wireName));
    }
  }

  // --- accounting -----------------------------------------------------------

  /// Received live messages of type [M].
  List<M> receivedOf<M extends DwClientMessage>() =>
      received.whereType<M>().toList();

  /// Calls whose DTO is a [C], in arrival order.
  List<DwFakeRecordedCall> callsOf<C extends DwServerCall<Object?>>() => [
    for (final call in calls)
      if (call.call is C) call,
  ];

  /// Requests of type [Q] that arrived, in arrival order.
  List<Q> requestsOf<Q extends DwDataRequest<Object?>>() => [
    for (final call in calls)
      if (call.call case final Q request) request,
  ];

  /// How many times the handler ran for the command with [idempotencyKey].
  int executions(String idempotencyKey) => _executions[idempotencyKey] ?? 0;

  /// Drops every open live connection from the server side.
  Future<void> dropConnections({int? code, String? reason}) async {
    for (final connection in openConnections.toList()) {
      await connection.close(code: code, reason: reason);
    }
  }

  // --- HTTP -----------------------------------------------------------------

  Future<DwHttpReply> _onPost(DwHttpPost post) async {
    if (!reachable) throw const DwFakeNetworkException();
    final intercepted = await interceptPost?.call(post);
    if (intercepted != null) return intercepted;

    final headers = {
      for (final MapEntry(:key, :value) in post.headers.entries)
        key.toLowerCase(): value,
    };
    final query = post.url.queryParameters;
    final wireName = DwHttpContract.wireNameOf(
      post.url.path.substring(baseUrl.path.length),
    );
    DwServerCall<Object?>? dto;

    DwHttpReply answer(DwApiResponse response) {
      calls.add(
        DwFakeRecordedCall._(
          wireName: wireName ?? post.url.path,
          call: dto,
          headers: headers,
          query: query,
          status: response.httpStatus,
          response: response,
        ),
      );
      return _reply(response);
    }

    DwApiResponse malformed(String why) {
      errors.add(StateError('Malformed call to ${post.url}: $why'));
      return const DwApiResponse.failed(
        'fake-malformed',
        failure: DwFailureKind.malformedCall,
      );
    }

    // Versions first: a build that cannot talk to this server learns that
    // before anything else about its call.
    final protocolHeader = headers[DwHttpContract.protocolHeader.toLowerCase()];
    if (protocolHeader == null) {
      return answer(malformed('no ${DwHttpContract.protocolHeader}'));
    }
    if (protocolHeader != '$protocolVersion') {
      return answer(
        DwApiResponse.incompatible(
          DwCallRefusal(DwCoreRefusal.protocolUnsupported),
        ),
      );
    }
    final versionHeader =
        headers[DwHttpContract.appVersionHeader.toLowerCase()];
    final DwAppVersion appVersion;
    try {
      appVersion = DwAppVersion.parse(versionHeader ?? '');
    } on FormatException {
      return answer(malformed('no valid ${DwHttpContract.appVersionHeader}'));
    }
    if (appVersion.build < minAppBuild) {
      return answer(
        DwApiResponse.incompatible(DwCallRefusal(DwCoreRefusal.updateRequired)),
      );
    }

    final entry = wireName == null ? null : protocol.entryNamed(wireName);
    if (entry == null ||
        (entry.kind != DwWireObjectKind.request &&
            entry.kind != DwWireObjectKind.command)) {
      errors.add(StateError('Unknown call ${post.url.path}'));
      return answer(
        const DwApiResponse.failed(
          'fake-unknown-call',
          failure: DwFailureKind.unknownCall,
        ),
      );
    }
    try {
      dto =
          entry.fromJson(jsonDecode(post.body) as Map<String, Object?>)
              as DwServerCall<Object?>;
    } catch (error) {
      return answer(malformed('the body does not decode: $error'));
    }
    final call = dto;

    final key = headers[DwHttpContract.idempotencyKeyHeader.toLowerCase()];
    DwPageQuery? page;
    switch (call) {
      case DwActionCommand():
        if (key == null) return answer(malformed('a command without a key'));
        if (query.isNotEmpty) {
          return answer(malformed('a command with page parameters'));
        }
      case DwDataRequest():
        if (key != null) return answer(malformed('a request with a key'));
        try {
          page = DwPageQuery.parse(call, query);
        } on FormatException catch (error) {
          return answer(malformed('$error'));
        }
    }

    final authorization =
        headers[DwHttpContract.authorizationHeader.toLowerCase()];
    String? token;
    int? accountId;
    if (authorization != null) {
      if (!authorization.startsWith(DwHttpContract.bearerPrefix)) {
        return answer(malformed('an Authorization that is not a bearer'));
      }
      token = authorization.substring(DwHttpContract.bearerPrefix.length);
      accountId = _tokens[token];
      // A key that is not (or no longer) valid is not an anonymous caller.
      if (accountId == null) {
        return answer(const DwApiResponse.unauthenticated());
      }
    }

    if (key != null) {
      final stored = _outcomes[key];
      if (stored != null) {
        // The stored outcome, answered again without executing: an ok is marked
        // replayed and carries no updates — they went out when it ran.
        return answer(switch (stored) {
          DwApiOk(:final result) => DwApiResponse.ok(result, replayed: true),
          _ => stored,
        });
      }
    }

    final liveId = headers[DwHttpContract.liveConnectionHeader.toLowerCase()];
    final named = liveId == null
        ? null
        : openConnections.where((c) => c.id == liveId).firstOrNull;
    final context = DwFakeCall._(
      this,
      accountId,
      token,
      page,
      key,
      named,
      appVersion,
      headers,
    );

    final response = await _handle(call, context);
    if (key != null && (response is DwApiOk || response is DwApiRefused)) {
      _outcomes[key] = response;
    }
    return answer(response);
  }

  Future<DwApiResponse> _handle(
    DwServerCall<Object?> call,
    DwFakeCall context,
  ) async {
    if (call is DwTableRequest) {
      final refusal = call.checkPage();
      if (refusal != null) return DwApiResponse.refused(refusal);
    }
    if (call case final DwSelfValidating validating) {
      final refusals = validating.validate();
      if (refusals.isNotEmpty) return DwApiResponse.refused(refusals.first);
    }
    final DwFakeHandler<DwServerCall<Object?>>? handler = switch (call) {
      DwDataRequest() => _requests[call.runtimeType],
      DwActionCommand() =>
        _commands[call.runtimeType] ?? (call is DwSignOut ? _signOut : null),
    };
    if (handler == null) {
      errors.add(StateError('No fake handler for ${call.runtimeType}'));
      return const DwApiResponse.failed('fake-no-handler');
    }
    if (context.idempotencyKey case final key?) {
      _executions[key] = executions(key) + 1;
    }
    final DwCallResult<Object?> result;
    try {
      result = await handler(call, context);
    } on DwRefusalException catch (exception) {
      return DwApiResponse.refused(exception.refusal);
    } catch (error) {
      errors.add(error);
      return const DwApiResponse.failed('fake-handler-error');
    }
    switch (result) {
      case DwCallOk(:final value):
        final Object? encoded;
        try {
          encoded = call.encodeResult(value, protocol);
        } catch (error) {
          errors.add(error);
          return const DwApiResponse.failed('fake-result-does-not-encode');
        }
        // Looked up after the handler, and only for the caller's own account,
        // as a real server does: the connection may have closed or signed in
        // as someone else while the call ran, and a connection of another
        // account must not filter or suppress this one's updates.
        final liveId =
            context.headers[DwHttpContract.liveConnectionHeader.toLowerCase()];
        final named = openConnections
            .where((c) => c.id == liveId && c.accountId == context.accountId)
            .firstOrNull;
        final carried = <(String, DwWireObject)>[];
        for (final (channel, objects) in context._published) {
          final name = channel.wireName;
          _broadcast(name, objects, except: named);
          if (named == null || named.subscriptions.contains(name)) {
            carried.addAll([for (final object in objects) (name, object)]);
          }
        }
        return DwApiResponse.ok(encoded, updates: DwUpdateTransport(carried));
      case DwCallRefused() || DwNotAuthenticated() || DwCallFailed():
        // Not ok: the response carries no updates, and whatever the handler
        // published before it gave up reaches every subscriber over the
        // socket — the caller's named connection included.
        for (final (channel, objects) in context._published) {
          _broadcast(channel.wireName, objects, except: null);
        }
    }
    switch (result) {
      case DwCallOk():
        throw StateError('unreachable: answered above');
      case DwCallRefused(:final refusal):
        return refusal.isIncompatibility
            ? DwApiResponse.incompatible(refusal)
            : DwApiResponse.refused(refusal);
      case DwNotAuthenticated():
        return const DwApiResponse.unauthenticated();
      case DwCallFailed(:final incidentId):
        return DwApiResponse.failed(incidentId);
    }
  }

  DwHttpReply _reply(DwApiResponse response) => DwHttpReply(
    status: response.httpStatus,
    body: jsonEncode(response.toJson()),
    headers: {
      DwHttpContract.contentTypeHeader.toLowerCase():
          DwHttpContract.jsonContentType,
      for (final MapEntry(:key, :value) in dwHttpHeadersFor(response).entries)
        key.toLowerCase(): value,
    },
  );

  /// The built-in sign-out, as a real server does it: revokes the key; the
  /// caller's named live connection loses its subscriptions and becomes
  /// anonymous without being told (it asked), every other connection bound
  /// to the key is rejected.
  DwCallResult<Object?> _signOut(Object command, DwFakeCall call) {
    final token = call.token;
    if (token == null) return const DwNotAuthenticated<void>();
    final named = call.liveConnection;
    if (named != null && named.token == token) _bind(named, null, null);
    revokeToken(token);
    return const DwCallOk<void>(null);
  }

  // --- live -----------------------------------------------------------------

  void _accept(DwLiveConnection end, Uri url) {
    if (!acceptsConnections) {
      throw StateError('The fake server does not accept connections.');
    }
    final connection = DwFakeConnection._(
      this,
      end,
      url,
      'fake-${_nextConnection++}',
    );
    connections.add(connection);
    end.messages.listen(
      (frame) => _onFrame(connection, frame),
      onDone: () {
        connection.isOpen = false;
        connection.subscriptions.clear();
      },
    );
    final refusal = _upgradeRefusal(url);
    if (refusal != null) {
      // Upgraded and closed at once: a browser cannot read the status of a
      // refused upgrade, so the close code carries the answer.
      unawaited(
        connection.close(code: DwCloseCode.incompatible, reason: refusal.code),
      );
      return;
    }
    connection.send(DwHelloMessage(connection.id));
  }

  DwCallRefusal? _upgradeRefusal(Uri url) {
    final parameters = url.queryParameters;
    if (parameters[DwHttpContract.liveProtocolParameter] !=
        '$protocolVersion') {
      return DwCallRefusal(DwCoreRefusal.protocolUnsupported);
    }
    final app = parameters[DwHttpContract.liveAppVersionParameter];
    try {
      if (DwAppVersion.parse(app ?? '').build < minAppBuild) {
        return DwCallRefusal(DwCoreRefusal.updateRequired);
      }
    } on FormatException {
      return DwCallRefusal(DwCoreRefusal.updateRequired);
    }
    return null;
  }

  void _onFrame(DwFakeConnection connection, String frame) {
    final DwClientMessage message;
    try {
      message = DwClientMessage.fromJson(jsonDecode(frame));
    } catch (error) {
      errors.add(error);
      return;
    }
    received.add(message);
    switch (message) {
      case DwAuthenticateMessage(:final token):
        final account = token == null ? null : _tokens[token];
        _bind(connection, account, account == null ? null : token);
        connection.send(
          token == null
              ? const DwAuthenticatedMessage.anonymous()
              : account == null
              ? const DwAuthenticatedMessage.rejected()
              : DwAuthenticatedMessage.account(account),
        );
      case DwSubscribeMessage(:final channel):
        _subscribes[channel] = (_subscribes[channel] ?? 0) + 1;
        if (failingChannels.contains(channel)) {
          connection.send(
            DwSubscriptionRefusedMessage.failed(channel, subscriptionIncident),
          );
        } else if (subscriptionsRequireAccount &&
            connection.accountId == null) {
          connection.send(
            DwSubscriptionRefusedMessage.unauthenticated(channel),
          );
        } else if (subscriptionRule?.call(channel, connection)
            case final refusal?) {
          connection.send(
            DwSubscriptionRefusedMessage.refused(channel, refusal),
          );
        } else {
          connection.subscriptions.add(channel);
          connection.send(DwSubscribedMessage(channel));
        }
      case DwUnsubscribeMessage(:final channel):
        _unsubscribes[channel] = (_unsubscribes[channel] ?? 0) + 1;
        connection.subscriptions.remove(channel);
    }
  }
}

/// Client timings for tests against the fake server: short retries and no
/// release or idle delay, so a test sees the effects of what it did at once.
const DwClientOptions dwFakeClientOptions = DwClientOptions(
  retryDelay: Duration(milliseconds: 1),
  maxRetryDelay: Duration(milliseconds: 10),
  releaseDelay: Duration.zero,
  liveIdleDelay: Duration.zero,
  liveSettleTimeout: Duration(milliseconds: 200),
  callTimeout: Duration(seconds: 2),
);
