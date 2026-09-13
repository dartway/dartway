import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_core/dartway_core.dart';

import '../client/dw_client.dart';
import '../dw_client_options.dart';
import '../session/dw_token_store.dart';
import '../transport/dw_connection.dart';

/// A request handler of the fake server. Returns the result the server
/// answers; throwing [DwRefusalException] refuses, anything else fails.
///
/// The value of a [DwOk] must have the request's result type exactly —
/// `DwOk(<RoomView>[])`, not `DwOk([])` — because it is encoded by the
/// request class, as on a real server.
typedef DwFakeHandler<M> =
    FutureOr<DwResult<Object?>> Function(M message, DwFakeCall call);

/// What a fake handler knows about the call.
final class DwFakeCall {
  const DwFakeCall._(
    this.connection,
    this.accountId,
    this.page,
    this.idempotencyKey,
  );

  final DwFakeConnection connection;

  /// The account the connection acted for when the call arrived.
  final int? accountId;

  /// The page a paginated request asked for.
  final DwPageParams? page;

  /// The key of a command.
  final String? idempotencyKey;
}

/// One client connection as the fake server sees it.
final class DwFakeConnection {
  DwFakeConnection._(this._server, this._end, this.endpoint);

  final DwFakeServer _server;
  final DwConnection _end;
  final Uri endpoint;

  int? accountId;
  String? token;
  bool isOpen = true;

  /// Wire names of the channels this connection is subscribed to.
  final Set<String> subscriptions = {};

  /// Sends [message] to the client as the server would.
  void send(DwServerMessage message) {
    if (!isOpen) return;
    final encoded = message.toJson(_server.protocol);
    try {
      _end.send(jsonEncode(encoded));
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
  /// [code] and [reason] when given (`DwCloseCode.slowConsumer`, say).
  Future<void> close({int? code, String? reason}) => _end.close(code, reason);
}

/// An in-memory DartWay server that speaks the wire protocol, for tests of
/// the client and of the screens on top of it.
///
/// Not the real server: handlers are closures registered per DTO type, there
/// is no database and no access rule beyond what a test declares (a real
/// server refuses every subscription of an anonymous connection; this one
/// allows what [subscriptionRule] allows). What it does reproduce is the
/// protocol as `dartway_server` speaks it — authentication answers, a changed
/// account closing subscriptions, key revocation, results by id, idempotent
/// commands, subscriptions and their accounting, publishing and closing
/// channels — so a client talks to it exactly as to a real one.
///
/// ```dart
/// final server = DwFakeServer(protocol: appProtocol)
///   ..onRequest<ListRooms>((request, call) => DwOk(rooms));
/// final client = server.newClient();
/// await client.start();
/// ```
final class DwFakeServer {
  DwFakeServer({required this.protocol});

  final DwProtocol protocol;

  /// The address clients of this server use. Informational: [connector] is
  /// what reaches it.
  final Uri endpoint = Uri.parse('memory://dartway/dw');

  /// Connects clients to this server in memory.
  late final DwMemoryConnector connector = DwMemoryConnector(_accept);

  /// While false, connection attempts fail as against an unreachable server.
  bool acceptsConnections = true;

  /// The wire version this server speaks. A client connecting with another
  /// `v=` is closed with `DwCloseCode.unsupportedVersion`, as by a real
  /// server — set it to test what an outdated app does.
  int wireVersion = dwWireVersion;

  /// Every connection ever accepted, open or not.
  final List<DwFakeConnection> connections = [];

  Iterable<DwFakeConnection> get openConnections =>
      connections.where((connection) => connection.isOpen);

  /// Every message received from any client, in arrival order.
  final List<DwClientMessage> received = [];

  /// Every message sent to any client.
  final List<DwServerMessage> sent = [];

  /// Handler exceptions and calls nobody registered a handler for. A test
  /// that expects none asserts this is empty: a fake that swallowed them
  /// would let a broken test pass.
  final List<Object> errors = [];

  /// Decides a subscription: `null` allows it, a refusal refuses it.
  DwRefusal? Function(String channel, DwFakeConnection connection)?
  subscriptionRule;

  /// Channels whose subscription check fails, as a throwing rule does on a
  /// real server: answered as a failure with the incident
  /// [subscriptionIncident], not as a refusal.
  final Set<String> failingChannels = {};

  static const String subscriptionIncident = 'fake-subscription-failed';

  final Map<String, int> _tokens = {};
  final Map<Type, DwFakeHandler<DwRequest<Object?>>> _requests = {};
  final Map<Type, DwFakeHandler<DwCommand<Object?>>> _commands = {};
  final Map<String, DwResultMessage> _outcomes = {};
  final Map<String, int> _executions = {};
  final Map<String, int> _subscribes = {};
  final Map<String, int> _unsubscribes = {};

  /// A client of this server — not started, with timings short enough for
  /// tests unless [options] says otherwise.
  DwClient newClient({
    DwTokenStore? tokenStore,
    DwClientOptions options = const DwClientOptions(
      reconnectDelay: Duration(milliseconds: 1),
      maxReconnectDelay: Duration(milliseconds: 10),
      releaseDelay: Duration.zero,
    ),
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => DwClient(
    protocol: protocol,
    endpoint: endpoint,
    connector: connector,
    tokenStore: tokenStore,
    options: options,
    onError: onError,
    // Keys and jitter in a test need no secure source, and not every test
    // platform has one (Node under dart2js does not).
    random: Random(),
  );

  // --- handlers -------------------------------------------------------------

  /// Answers requests of type [Q].
  void onRequest<Q extends DwRequest<Object?>>(DwFakeHandler<Q> handle) {
    _requests[Q] = (request, call) => handle(request as Q, call);
  }

  /// Answers commands of type [C]. A command is run once per idempotency key;
  /// a repeat answers the stored outcome unless it failed.
  void onCommand<C extends DwCommand<Object?>>(DwFakeHandler<C> handle) {
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
      connection.send(const DwAuthenticatedMessage(rejected: true));
    }
  }

  /// Binds [connection] to an account, or to none. As on a real server, a
  /// changed account closes every subscription — access was checked for the
  /// previous one — and says so with `closed`.
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

  bool isTokenValid(String token) => _tokens.containsKey(token);

  // --- channels -------------------------------------------------------------

  /// How many `sub` messages arrived for [channel], from any connection.
  int subscribeCount(DwChannel channel) => _subscribes[channel.wireName] ?? 0;

  /// How many `unsub` messages arrived for [channel].
  int unsubscribeCount(DwChannel channel) =>
      _unsubscribes[channel.wireName] ?? 0;

  /// How many open connections are subscribed to [channel].
  int subscriberCount(DwChannel channel) => openConnections
      .where((c) => c.subscriptions.contains(channel.wireName))
      .length;

  /// Publishes [items] to every open connection subscribed to [channel] —
  /// the author of a command included, as a real server does (D-018).
  void publish(DwChannel channel, List<DwDto> items) {
    for (final connection in openConnections.toList()) {
      if (!connection.subscriptions.contains(channel.wireName)) continue;
      connection.send(DwUpdateMessage(channel: channel.wireName, items: items));
    }
  }

  /// Closes [channel] for every subscribed connection, or only for those of
  /// [accountId] — what revoking access does.
  void closeChannel(DwChannel channel, {int? accountId}) {
    for (final connection in openConnections.toList()) {
      if (accountId != null && connection.accountId != accountId) continue;
      if (!connection.subscriptions.remove(channel.wireName)) continue;
      connection.send(DwChannelClosedMessage(channel.wireName));
    }
  }

  // --- accounting -----------------------------------------------------------

  /// Received messages of type [M].
  List<M> receivedOf<M extends DwClientMessage>() =>
      received.whereType<M>().toList();

  /// Received requests of type [Q], in arrival order.
  List<Q> requestsOf<Q extends DwRequest<Object?>>() => [
    for (final message in received)
      if (message is DwRequestMessage && message.request is Q)
        message.request as Q,
  ];

  /// Received command messages carrying a command of type [C].
  List<DwCommandMessage> commandsOf<C extends DwCommand<Object?>>() => [
    for (final message in received)
      if (message is DwCommandMessage && message.command is C) message,
  ];

  /// How many times the handler ran for the command with [idempotencyKey].
  int executions(String idempotencyKey) => _executions[idempotencyKey] ?? 0;

  /// Drops every open connection from the server side.
  Future<void> dropConnections() async {
    for (final connection in openConnections.toList()) {
      await connection.close();
    }
  }

  // --- the protocol ---------------------------------------------------------

  void _accept(DwConnection end, Uri endpoint) {
    if (!acceptsConnections) {
      throw StateError('The fake server does not accept connections.');
    }
    final connection = DwFakeConnection._(this, end, endpoint);
    connections.add(connection);
    end.messages.listen(
      (frame) => _onFrame(connection, frame),
      onDone: () {
        connection.isOpen = false;
        connection.subscriptions.clear();
      },
    );
    if (endpoint.queryParameters['v'] != '$wireVersion') {
      // Accepted and closed at once, as the real server upgrades and then
      // closes: the client learns why from the close code.
      unawaited(
        connection.close(
          code: DwCloseCode.unsupportedVersion,
          reason: '${DwCloseCode.wireVersionReason}$wireVersion',
        ),
      );
    }
  }

  void _onFrame(DwFakeConnection connection, String frame) {
    final DwClientMessage message;
    try {
      message = DwClientMessage.fromJson(
        jsonDecode(frame) as Map<String, Object?>,
        protocol,
      );
    } catch (error) {
      errors.add(error);
      return;
    }
    received.add(message);
    switch (message) {
      case DwAuthenticateMessage(:final token):
        _authenticate(connection, token);
      case DwRequestMessage():
        unawaited(_request(connection, message));
      case DwCommandMessage():
        unawaited(_command(connection, message));
      case DwSubscribeMessage(:final channel):
        _subscribes[channel] = (_subscribes[channel] ?? 0) + 1;
        final refusal = subscriptionRule?.call(channel, connection);
        if (failingChannels.contains(channel)) {
          connection.send(
            DwSubscriptionRefusedMessage.failed(channel, subscriptionIncident),
          );
        } else if (refusal != null) {
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

  void _authenticate(DwFakeConnection connection, String? token) {
    if (token == null) {
      _bind(connection, null, null);
      connection.send(const DwAuthenticatedMessage());
      return;
    }
    final account = _tokens[token];
    _bind(connection, account, account == null ? null : token);
    connection.send(
      account == null
          ? const DwAuthenticatedMessage(rejected: true)
          : DwAuthenticatedMessage(accountId: account),
    );
  }

  Future<void> _request(
    DwFakeConnection connection,
    DwRequestMessage message,
  ) async {
    final call = DwFakeCall._(
      connection,
      connection.accountId,
      message.page,
      null,
    );
    final handler = _requests[message.request.runtimeType];
    final DwResultMessage answer;
    if (_invalid(message.id, message.request) case final refused?) {
      answer = refused;
    } else if (handler == null) {
      errors.add(
        StateError('No fake handler for ${message.request.runtimeType}'),
      );
      answer = DwResultMessage(
        id: message.id,
        status: DwResultStatus.failed,
        incidentId: 'fake-no-handler',
      );
    } else {
      answer = await _run(
        message.id,
        () => handler(message.request, call),
        (value) => message.request.encodeResult(value, protocol),
      );
    }
    connection.send(answer);
  }

  Future<void> _command(
    DwFakeConnection connection,
    DwCommandMessage message,
  ) async {
    final stored = _outcomes[message.idempotencyKey];
    if (stored != null) {
      connection.send(
        DwResultMessage(
          id: message.id,
          status: stored.status,
          value: stored.value,
          refusal: stored.refusal,
        ),
      );
      return;
    }
    final call = DwFakeCall._(
      connection,
      connection.accountId,
      null,
      message.idempotencyKey,
    );
    final command = message.command;
    final handler =
        _commands[command.runtimeType] ??
        (command is DwSignOut ? _signOut : null);
    final DwResultMessage answer;
    if (_invalid(message.id, command) case final refused?) {
      answer = refused;
    } else if (handler == null) {
      errors.add(StateError('No fake handler for ${command.runtimeType}'));
      answer = DwResultMessage(
        id: message.id,
        status: DwResultStatus.failed,
        incidentId: 'fake-no-handler',
      );
    } else {
      _executions[message.idempotencyKey] =
          executions(message.idempotencyKey) + 1;
      answer = await _run(
        message.id,
        () => handler(command, call),
        (value) => command.encodeResult(value, protocol),
      );
      if (answer.status == DwResultStatus.ok ||
          answer.status == DwResultStatus.refused) {
        _outcomes[message.idempotencyKey] = answer;
      }
    }
    connection.send(answer);
  }

  /// The built-in sign-out, as a real server does it: revokes the key; the
  /// author connection becomes anonymous (its subscriptions closed, no
  /// `authed` — it asked), every other connection on the key is rejected.
  DwResult<Object?> _signOut(DwCommand<Object?> command, DwFakeCall call) {
    final author = call.connection;
    final token = author.token;
    if (token == null) return const DwNotAuthenticated<void>();
    _bind(author, null, null);
    revokeToken(token);
    return const DwOk<void>(null);
  }

  /// The refusal a real server answers before the handler for a DTO that
  /// does not validate — reachable only by a client that skipped its own
  /// check.
  DwResultMessage? _invalid(int id, DwDto dto) {
    if (dto case final DwValidatable validatable) {
      final refusals = validatable.validate();
      if (refusals.isNotEmpty) {
        return DwResultMessage(
          id: id,
          status: DwResultStatus.refused,
          refusal: refusals.first,
        );
      }
    }
    return null;
  }

  Future<DwResultMessage> _run(
    int id,
    FutureOr<DwResult<Object?>> Function() handle,
    Object? Function(Object? value) encode,
  ) async {
    try {
      final result = await handle();
      return switch (result) {
        DwOk(:final value) => DwResultMessage(
          id: id,
          status: DwResultStatus.ok,
          value: encode(value),
        ),
        DwRefused(:final refusal) => DwResultMessage(
          id: id,
          status: DwResultStatus.refused,
          refusal: refusal,
        ),
        DwNotAuthenticated() => DwResultMessage(
          id: id,
          status: DwResultStatus.unauthenticated,
        ),
        DwFailed(:final incidentId) => DwResultMessage(
          id: id,
          status: DwResultStatus.failed,
          incidentId: incidentId,
        ),
      };
    } on DwRefusalException catch (exception) {
      return DwResultMessage(
        id: id,
        status: DwResultStatus.refused,
        refusal: exception.refusal,
      );
    } catch (error) {
      errors.add(error);
      return DwResultMessage(
        id: id,
        status: DwResultStatus.failed,
        incidentId: 'fake-handler-error',
      );
    }
  }
}

/// One page of [ordered] for [page], as a DartWay server would answer a
/// paginated request: offset pages by position; cursor pages hold the objects
/// after the one with id [DwCursorParams.before] (the list is newest first,
/// ids descending). Reads one object past the page to learn [DwPage.hasMore].
DwPage<T> dwFakePage<T extends DwDataObject>(
  List<T> ordered,
  DwPageParams? page, {
  required int pageSize,
}) {
  final start = switch (page) {
    null => 0,
    DwOffsetParams(:final offset) => offset,
    DwCursorParams(before: null) => 0,
    DwCursorParams(:final before) => () {
      final index = ordered.indexWhere(
        (item) => (item.id as Comparable).compareTo(before) < 0,
      );
      return index < 0 ? ordered.length : index;
    }(),
  };
  final window = ordered.skip(start).take(pageSize + 1).toList();
  return DwPage<T>(
    window.take(pageSize).toList(),
    hasMore: window.length > pageSize,
  );
}
