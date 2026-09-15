import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../auth/dw_auth_service.dart';
import '../channels/dw_channel_rules.dart';
import '../http/dw_reason_phrase.dart';
import '../context/dw_call_context.dart';
import '../server/dw_runtime.dart';
import '../server/dw_server_settings.dart';
import 'dw_live_connection.dart';
import 'dw_live_hub.dart';
import 'dw_web_origin.dart';

/// Serves `GET /dw/live`: the upgrade, the connection's identity and
/// authentication, and its subscriptions.
@internal
final class DwLiveEndpoint {
  DwLiveEndpoint({
    required this.runtime,
    required this.authService,
    required this.settings,
  });

  final DwRuntime runtime;
  final DwAuthService authService;
  final DwServerSettings settings;

  DwLiveHub get _hub => runtime.hub;
  DwServerLogger get _log => runtime.log;

  static const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  static final Random _random = Random.secure();

  /// Upgrades [request] and serves the socket until it closes. Refusals that
  /// happen before the upgrade are answered as plain HTTP.
  ///
  /// The handshake is written here rather than by `WebSocketTransformer`: the
  /// transformer keeps the raw socket to itself, and a peer that stops
  /// reading can only be cut off by destroying that socket.
  Future<void> upgrade(HttpRequest request, {required bool stopping}) async {
    final response = request.response;
    Future<void> refuse(int status, String text, [Map<String, String>? h]) {
      dwSetStatus(response, status);
      h?.forEach(response.headers.set);
      response.headers.contentType = ContentType.text;
      response.write(text);
      return response.close();
    }

    if (stopping) return refuse(503, 'server stopping');
    final key = request.headers.value('sec-websocket-key');
    if (request.method != 'GET' ||
        !WebSocketTransformer.isUpgradeRequest(request) ||
        key == null ||
        _decodedLength(key) != 16) {
      if (request.headers.value('sec-websocket-version') case final version?
          when version != '13') {
        return refuse(426, 'WebSocket version 13 is required', {
          'sec-websocket-version': '13',
        });
      }
      return refuse(400, 'a WebSocket upgrade is expected');
    }
    final origin = request.headers.value('origin');
    if (origin != null && !_originAllowed(origin, request)) {
      return refuse(403, 'origin not allowed');
    }
    dwSetStatus(response, HttpStatus.switchingProtocols);
    response
      ..headers.set(HttpHeaders.connectionHeader, 'Upgrade')
      ..headers.set(HttpHeaders.upgradeHeader, 'websocket')
      ..headers.set(
        'Sec-WebSocket-Accept',
        base64.encode(sha1.convert(utf8.encode('$key$_webSocketGuid')).bytes),
      )
      ..headers.contentLength = 0;
    final socket = await response.detachSocket();
    final webSocket = WebSocket.fromUpgradedSocket(socket, serverSide: true);
    final connection = DwLiveConnection(
      id: _newConnectionId(),
      socket: socket,
      webSocket: webSocket,
      log: _log,
      outboundLimitBytes: settings.outboundLimitBytes,
      closeGrace: settings.closeGrace,
    );

    // Compatibility is answered after the upgrade: a browser cannot read the
    // status of a refused upgrade, only the close code of an accepted one.
    final incompatibility = _incompatibility(request.uri.queryParameters);
    if (incompatibility != null) {
      webSocket.listen(null, onDone: connection.markClosed, onError: (_) {});
      final (code, reason) = incompatibility;
      await connection.close(code, reason);
      return;
    }

    webSocket.pingInterval = settings.pingInterval;
    _hub.add(connection);
    webSocket.listen(
      (data) => _onMessage(connection, data),
      onDone: () {
        connection.markClosed();
        _hub.remove(connection);
      },
      onError: (Object error) => _log.debug('live connection: $error'),
    );
    connection.send(DwHelloMessage(connection.id));
  }

  /// The close code and reason for a client this server cannot talk to, or
  /// `null`.
  (int, String)? _incompatibility(Map<String, String> query) {
    if (query[DwHttpContract.liveProtocolParameter] != '$dwProtocolVersion') {
      return (DwCloseCode.incompatible, DwCoreRefusal.protocolUnsupported.code);
    }
    final app = query[DwHttpContract.liveAppVersionParameter];
    final int build;
    if (app == null) {
      build = 0;
    } else {
      try {
        build = DwAppVersion.parse(app).build;
      } on FormatException {
        return (DwCloseCode.protocolError, 'dw.protocol');
      }
    }
    if (build < settings.minAppBuild) {
      return (DwCloseCode.incompatible, DwCoreRefusal.updateRequired.code);
    }
    return null;
  }

  /// 128 random bits: the id is a capability of the connection, and must not
  /// be guessable from another one.
  static String _newConnectionId() => base64Url
      .encode(List.generate(16, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  static int _decodedLength(String base64Key) {
    try {
      return base64.decode(base64Key).length;
    } on FormatException {
      return -1;
    }
  }

  /// Whether a browser page of [origin] may open the live socket: when it is
  /// the origin the request was sent to (the proxied `/dw/` of R2.7 serves the
  /// web app and the socket from one host), or one of
  /// `DwServerSettings.allowedOrigins`. Scheme, host and port are all
  /// compared: another port on the same host is another site. An origin that
  /// does not parse — `null`, sent by sandboxed and `file:` pages — is refused.
  bool _originAllowed(String origin, HttpRequest request) {
    final parsed = DwWebOrigin.parse(origin);
    if (parsed == null) return false;
    return parsed.isHostOf(request.headers.value(HttpHeaders.hostHeader)) ||
        _allowedOrigins.contains(parsed);
  }

  /// [DwServerSettings.allowedOrigins], parsed once. Entries that do not
  /// parse never reach here: the server refuses to start with them.
  late final Set<DwWebOrigin> _allowedOrigins = {
    for (final entry in settings.allowedOrigins) ?DwWebOrigin.parse(entry),
  };

  void _onMessage(DwLiveConnection connection, Object? data) {
    if (connection.isClosing) return;
    if (data is! String) {
      unawaited(connection.close(DwCloseCode.unsupportedData, 'dw.textOnly'));
      return;
    }
    if (data.length > settings.maxLiveMessageBytes) {
      unawaited(connection.close(DwCloseCode.messageTooBig, 'dw.tooBig'));
      return;
    }
    final DwClientMessage message;
    try {
      message = DwClientMessage.fromJson(jsonDecode(data));
    } on FormatException catch (error) {
      _log.warning('live connection: protocol violation: ${error.message}');
      unawaited(connection.close(DwCloseCode.protocolError, 'dw.protocol'));
      return;
    }
    switch (message) {
      case DwAuthenticateMessage(:final token):
        connection.authGate = _authenticate(
          connection,
          connection.authGate,
          token,
        );
      case DwSubscribeMessage(:final channel):
        _channelOperation(connection, channel, subscribe: true);
      case DwUnsubscribeMessage(:final channel):
        _channelOperation(connection, channel, subscribe: false);
    }
  }

  Future<void> _authenticate(
    DwLiveConnection connection,
    Future<void> previous,
    String? token,
  ) async {
    await previous;
    if (connection.isClosing) return;
    if (token == null) {
      _hub.authenticate(connection, null);
      connection.send(const DwAuthenticatedMessage.anonymous());
      return;
    }
    try {
      final session = await authService.resolve(token);
      if (connection.isClosing) return;
      if (session == null) {
        _hub.authenticate(connection, null);
        connection.send(const DwAuthenticatedMessage.rejected());
        return;
      }
      _hub.authenticate(connection, session);
      connection.send(DwAuthenticatedMessage.account(session.accountId));
    } catch (error, stackTrace) {
      // Neither "anonymous" nor "rejected" would be true: the client must try
      // again, so the connection closes and the client reconnects.
      final incident = runtime.alerts.report(
        where: 'live authenticate',
        error: error,
        stackTrace: stackTrace,
      );
      _hub.authenticate(connection, null);
      await connection.close(DwCloseCode.internalError, 'dw.failed:$incident');
    }
  }

  void _channelOperation(
    DwLiveConnection connection,
    String name, {
    required bool subscribe,
  }) {
    final gate = connection.authGate;
    final tail = connection.channelTails[name] ?? Future<void>.value();
    late final Future<void> next;
    next = tail
        .then((_) => gate)
        .then(
          (_) => subscribe
              ? _subscribe(connection, name)
              : _hub.unsubscribe(connection, name),
        )
        .whenComplete(() {
          if (identical(connection.channelTails[name], next)) {
            connection.channelTails.remove(name);
          }
        });
    connection.channelTails[name] = next;
  }

  Future<void> _subscribe(DwLiveConnection connection, String name) async {
    if (connection.isClosing) return;
    void refuse(DwCallRefusal refusal) =>
        connection.send(DwSubscriptionRefusedMessage.refused(name, refusal));
    void unauthenticated() =>
        connection.send(DwSubscriptionRefusedMessage.unauthenticated(name));

    final lookup = runtime.channelRules.lookUp(name);
    if (lookup is DwUnknownChannel) {
      return refuse(DwCallRefusal(DwCoreRefusal.unknownChannel));
    }
    if (connection.accountId == null) return unauthenticated();
    if (connection.subscriptions.contains(name)) {
      return connection.send(DwSubscribedMessage(name));
    }
    if (lookup is! DwKnownChannel) {
      return refuse(DwCallRefusal(DwCoreRefusal.invalid, field: 'channel'));
    }
    final known = lookup;
    final kindName = known.rule.kind.channelName;
    final epoch = connection.authEpoch;
    final ctx = runtime.context(
      scope: 'subscribe $kindName',
      kind: DwContextKind.subscription,
      sessionKey: connection.sessionKey,
    );
    final bool allowed;
    try {
      allowed = await known.allows(ctx);
    } catch (error, stackTrace) {
      final incident = runtime.alerts.report(
        where: 'subscribe $kindName',
        error: error,
        stackTrace: stackTrace,
        accountId: connection.accountId,
      );
      return connection.send(
        DwSubscriptionRefusedMessage.failed(name, incident),
      );
    }
    if (connection.isClosing) return;
    // The session changed while the check ran: it was a check for someone
    // else.
    if (connection.authEpoch != epoch || connection.accountId == null) {
      return unauthenticated();
    }
    if (!allowed) return refuse(DwCallRefusal(DwCoreRefusal.forbidden));
    _hub.subscribe(connection, name);
    connection.send(DwSubscribedMessage(name));
  }
}
