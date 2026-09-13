import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_core/dartway_core.dart';

import '../dw_client_exceptions.dart';
import '../dw_client_options.dart';
import '../session/dw_token_store.dart';
import '../state/dw_request_state.dart';
import '../transport/dw_connection.dart';
import '../transport/dw_web_socket_connector.dart';

part 'channels.dart';
part 'entries.dart';
part 'paged_entry.dart';
part 'replay.dart';
part 'updates.dart';
part 'watch.dart';

/// Where the client's connection stands.
enum DwConnectionStatus {
  /// No connection; the client waits before the next attempt (or was never
  /// started).
  disconnected,

  /// Opening a connection, or authenticating one. Calls queue meanwhile.
  connecting,

  /// Connected and authenticated: calls go out as they are made.
  connected,
}

enum _Lifecycle { created, started, stopped }

/// The client side of a DartWay app: one connection to the server carrying
/// requests, commands, channel subscriptions and updates; the session; and the
/// live state of every watched request.
///
/// ```dart
/// final client = DwClient(
///   protocol: appProtocol,
///   endpoint: Uri.parse('ws://localhost:8080/dw'),
/// );
/// await client.start();
/// final watch = client.watch(const ListUpcomingSessions());
/// ```
///
/// A client holds no static state: create as many as a test needs and [stop]
/// each. A stopped client is finished — start a new one instead.
final class DwClient {
  DwClient({
    required this.protocol,
    required this.endpoint,
    DwTokenStore? tokenStore,
    DwConnector? connector,
    this.options = const DwClientOptions(),
    void Function(Object error, StackTrace stackTrace)? onError,
    Random? random,
  }) : tokenStore = tokenStore ?? DwMemoryTokenStore(),
       connector = connector ?? const DwWebSocketConnector(),
       _onError = onError,
       _random = random ?? Random.secure(),
       _rules = _UpdateRules(protocol);

  /// The DTOs this client and its server agree on.
  final DwProtocol protocol;

  /// The server's app WebSocket, `…/dw`.
  final Uri endpoint;

  final DwTokenStore tokenStore;
  final DwConnector connector;
  final DwClientOptions options;

  final void Function(Object error, StackTrace stackTrace)? _onError;
  final Random _random;
  final _UpdateRules _rules;

  _Lifecycle _lifecycle = _Lifecycle.created;
  Future<void>? _starting;

  // --- connection -----------------------------------------------------------

  DwConnection? _connection;

  /// Increments with every connection, so a call knows whether it was sent on
  /// the current one.
  int _generation = 0;

  /// The generation on which the handshake last completed.
  int _readyGeneration = 0;

  /// Authenticated on the current connection: calls may be written.
  bool _ready = false;

  final _status = _Replay<DwConnectionStatus>(DwConnectionStatus.disconnected);
  Timer? _sleepTimer;
  Completer<void>? _sleeping;
  Timer? _livenessTimer;
  bool _inboundSinceArmed = false;

  // --- session --------------------------------------------------------------

  DwSession? _session;

  /// Increments with every local session change, so a slow store read at start
  /// cannot overwrite a sign-in that happened meanwhile.
  int _sessionVersion = 0;

  final _account = _Replay<int?>(null);

  /// Tokens sent in `auth` messages on this connection, oldest first, each
  /// awaiting its answer.
  final Queue<String?> _authQueue = Queue();
  final List<Completer<void>> _authWaiters = [];

  /// The account the current connection acts for, as the server confirmed.
  int? _connectionAccount;

  /// The account channels and entries were last reconciled with.
  int? _reconciledAccount;
  bool _signingOut = false;

  // --- calls, channels, entries ----------------------------------------------

  int _nextId = 1;

  /// Calls awaiting an answer, in id order: queued, sent, or sent on a
  /// connection that has since dropped.
  final LinkedHashMap<int, _Call> _pending = LinkedHashMap();

  final Map<String, _ChannelRecord> _channels = {};
  final Map<DwRequest<Object?>, _RequestEntry<Object?>> _entries = {};
  final Map<DwRequest<Object?>, _PagedEntry<DwDataObject>> _pagedEntries = {};

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Reads the stored session and starts connecting; completes once the
  /// session is known, without waiting for the server. Calls and watches made
  /// before or during the connection queue and go out once it is up.
  Future<void> start() {
    _checkNotStopped();
    return _starting ??= _begin();
  }

  /// Ends the client: closes the connection, stops reconnecting, completes
  /// every unanswered call with [DwClientStoppedException] and closes every
  /// watch. Nothing is sent to the server — it drops a closed connection's
  /// subscriptions itself.
  Future<void> stop() async {
    if (_lifecycle == _Lifecycle.stopped) return;
    _lifecycle = _Lifecycle.stopped;
    _sleepTimer?.cancel();
    final sleeping = _sleeping;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
    _livenessTimer?.cancel();
    _livenessTimer = null;

    final calls = _pending.values.toList();
    _pending.clear();
    for (final entry in [..._entries.values, ..._pagedEntries.values]) {
      entry.dispose();
    }
    _entries.clear();
    _pagedEntries.clear();
    _channels.clear();
    for (final call in calls) {
      call.onAbort(const DwClientStoppedException(), StackTrace.current);
    }
    _completeAuthWaiters();

    final connection = _connection;
    if (connection != null) await connection.close();
    _status.value = DwConnectionStatus.disconnected;
    _status.close();
    _account.close();
  }

  /// Where the connection stands now.
  DwConnectionStatus get connectionStatus => _status.value;

  /// The connection status: the current value first, then every change.
  Stream<DwConnectionStatus> get connectionStatuses => _status.stream;

  /// The signed-in account id, or `null`.
  ///
  /// Known from the stored session right after [start] — before the server
  /// has seen the token, so an app can render the signed-in shell offline —
  /// and corrected by the server's answer: a rejected token makes it `null`.
  int? get accountId => _account.value;

  /// [accountId]: the current value first, then every change.
  Stream<int?> get session => _account.stream;

  /// Adopts [session] — the answer of `DwVerifyCode` — stores it and
  /// authenticates the connection with its token. Completes once the server
  /// has answered, or at once while offline (the next connection
  /// authenticates first, before any queued call).
  ///
  /// Every watched request is run again under the new account.
  Future<void> signIn(DwSession session) async {
    _checkNotStopped();
    _setSession(session);
    final stored = tokenStore.write(session);
    if (_connection != null) _authenticate(session.token);
    await stored;
    await _authSettled();
  }

  /// Signs out: sends `DwSignOut` so the server revokes the key, clears the
  /// stored session and continues anonymously; every watched request runs
  /// again.
  ///
  /// A successful `DwSignOut` leaves the connection anonymous with its
  /// subscriptions closed — the server unbinds the key it revoked — so no
  /// second authentication is sent. Any other outcome authenticates
  /// anonymously explicitly, since the connection may still be bound.
  ///
  /// The local session ends whatever the server answers. While offline only
  /// the local session ends — the key stays valid on the server until it
  /// expires, because the next connection has no token left to revoke it with.
  /// A sign-out that reached the server and failed is reported to `onError`
  /// as [DwSignOutException].
  Future<void> signOut() async {
    _checkNotStopped();
    final session = _session;
    if (session == null) return;
    var revoked = false;
    _signingOut = true;
    try {
      if (_ready) {
        try {
          final result = await command(const DwSignOut());
          switch (result) {
            case DwOk():
              revoked = true;
            case DwNotAuthenticated():
            // The server did not know the key either: nothing to revoke, and
            // the answer already made the connection anonymous here.
            case DwRefused() || DwFailed():
              _report(DwSignOutException(result), StackTrace.current);
          }
        } on DwTimeoutException catch (error, stackTrace) {
          _report(error, stackTrace);
        } on DwClientStoppedException {
          return;
        }
      }
      if (_session?.token == session.token) _clearSession();
      if (_connection == null || _connectionAccount == null) return;
      if (revoked) {
        _connectionAccount = null;
        for (final record in _channels.values) {
          record.state = _SubState.idle;
        }
        if (_ready) _reconcile(newConnection: false, flush: false);
      } else {
        _authenticate(null);
        await _authSettled();
      }
    } finally {
      _signingOut = false;
    }
  }

  /// Runs [request] once. [page] selects a page of a paginated request.
  ///
  /// Queued while disconnected and re-sent after a reconnect; completes with
  /// [DwTimeoutException] after `options.callTimeout`.
  Future<DwResult<R>> fetch<R>(DwRequest<R> request, {DwPageParams? page}) =>
      _oneShot<R>(
        label: request.dwTypeName,
        build: (id) => DwRequestMessage(id: id, request: request, page: page),
        decode: (json) => request.decodeResult(json, protocol),
      );

  /// Runs [command] once.
  ///
  /// The command carries an idempotency key generated for this call. A
  /// command re-sent after a reconnect carries the same key, so the server
  /// answers the stored outcome instead of running it twice.
  Future<DwResult<R>> command<R>(DwCommand<R> command) {
    final key = _newIdempotencyKey();
    return _oneShot<R>(
      label: command.dwTypeName,
      build: (id) =>
          DwCommandMessage(id: id, idempotencyKey: key, command: command),
      decode: (json) => command.decodeResult(json, protocol),
    );
  }

  /// Watches [request]: its state now and as it changes.
  ///
  /// All watches of equal requests share one live entry — one fetch, one set
  /// of channel subscriptions (reference-counted across entries as well). The
  /// entry is released `options.releaseDelay` after its last watch closes.
  ///
  /// A paginated request is watched with [watchPages].
  DwWatch<R> watch<R>(DwRequest<R> request) {
    _checkNotStopped();
    if (request is DwPageRequest || request is DwCursorRequest) {
      throw ArgumentError.value(
        request,
        'request',
        'A paginated request is watched with watchPages',
      );
    }
    var entry = _entries[request];
    if (entry == null) {
      final created = _RequestEntry<R>(this, request);
      entry = _entries[request] = created;
      _attachChannels(created);
      created.run();
    }
    _retain(entry);
    final watch = DwWatch<R>._(entry);
    entry.handles.add(watch);
    return watch;
  }

  /// Watches a paginated request ([DwPageRequest] or [DwCursorRequest]): the
  /// first page now, more on [DwPagedWatch.loadMore], updates merged live.
  DwPagedWatch<T> watchPages<T extends DwDataObject>(
    DwRequest<DwPage<T>> request,
  ) {
    _checkNotStopped();
    if (request is! DwPageRequest && request is! DwCursorRequest) {
      throw ArgumentError.value(
        request,
        'request',
        'watchPages takes a DwPageRequest or a DwCursorRequest',
      );
    }
    var entry = _pagedEntries[request];
    if (entry == null) {
      final created = _PagedEntry<T>(this, request);
      entry = _pagedEntries[request] = created;
      _attachChannels(created);
      created.run();
    }
    _retain(entry);
    final watch = DwPagedWatch<T>._(entry);
    entry.handles.add(watch);
    return watch;
  }

  // ===========================================================================
  // Lifecycle and connection
  // ===========================================================================

  void _checkNotStopped() {
    if (_lifecycle == _Lifecycle.stopped) {
      throw StateError('This DwClient is stopped. Create a new one.');
    }
  }

  Future<void> _begin() async {
    _lifecycle = _Lifecycle.started;
    final version = _sessionVersion;
    try {
      final stored = await tokenStore.read();
      if (version == _sessionVersion && stored != null) {
        _session = stored;
        _account.value = stored.id;
      }
    } catch (error, stackTrace) {
      // A store that cannot be read starts the app signed out; a person
      // signing in again is recoverable, a start that never finishes is not.
      _report(error, stackTrace);
    }
    if (_lifecycle != _Lifecycle.started) return;
    unawaited(_connectLoop());
  }

  Future<void> _connectLoop() async {
    var failures = 0;
    while (_lifecycle == _Lifecycle.started) {
      _status.value = DwConnectionStatus.connecting;
      DwConnection? connection;
      try {
        connection = await connector.connect(endpoint);
      } catch (_) {
        // An unreachable server is an ordinary state for a client, visible as
        // the status and retried — not an error to report.
      }
      if (_lifecycle != _Lifecycle.started) {
        await connection?.close();
        return;
      }
      if (connection != null) {
        await _serve(connection);
        // A connection that authenticated was a success; the next outage
        // starts counting from the first delay again.
        if (_readyGeneration == _generation) failures = 0;
      }
      if (_lifecycle != _Lifecycle.started) return;
      _status.value = DwConnectionStatus.disconnected;
      failures++;
      await _sleep(_backoff(failures));
    }
  }

  Duration _backoff(int failures) {
    final max = options.maxReconnectDelay.inMicroseconds;
    var micros = options.reconnectDelay.inMicroseconds;
    for (var i = 1; i < failures && micros < max; i++) {
      micros *= 2;
    }
    micros = min(micros, max);
    final half = micros ~/ 2;
    return Duration(microseconds: half + _random.nextInt(half + 1));
  }

  Future<void> _sleep(Duration delay) {
    final sleeping = _sleeping = Completer<void>();
    _sleepTimer = Timer(delay, () {
      if (!sleeping.isCompleted) sleeping.complete();
    });
    return sleeping.future;
  }

  Future<void> _serve(DwConnection connection) async {
    _connection = connection;
    _generation++;
    _ready = false;
    _authQueue.clear();
    _connectionAccount = null;

    final over = Completer<void>();
    final subscription = connection.messages.listen(
      _onFrame,
      onError: (Object error, StackTrace stackTrace) {
        // A transport error ends the connection; reconnecting is the answer.
        if (!over.isCompleted) over.complete();
      },
      onDone: () {
        if (!over.isCompleted) over.complete();
      },
    );

    final session = _session;
    if (session != null) {
      _authenticate(session.token);
    } else {
      _becomeReady();
    }

    await over.future;
    await subscription.cancel();
    await connection.close();
    _onConnectionLost();
  }

  void _onConnectionLost() {
    _connection = null;
    _ready = false;
    _authQueue.clear();
    _completeAuthWaiters();
    _livenessTimer?.cancel();
    _livenessTimer = null;
    if (_lifecycle != _Lifecycle.started) return;
    for (final record in _channels.values) {
      // The server dropped them with the connection. A closed channel stays
      // closed: that was the server's word, not the connection's.
      if (record.state != _SubState.closed) record.state = _SubState.idle;
    }
    for (final entry in _allEntries) {
      entry.syncLive();
    }
  }

  void _dropConnection() {
    final connection = _connection;
    if (connection != null) unawaited(connection.close());
  }

  Iterable<_Entry> get _allEntries => [
    ..._entries.values,
    ..._pagedEntries.values,
  ];

  // --- frames ---------------------------------------------------------------

  void _send(String frame) {
    try {
      _connection!.send(frame);
    } catch (_) {
      // Closed under us; the done event is on its way and reconnecting
      // re-sends whatever this was.
      _dropConnection();
    }
  }

  void _sendMessage(DwClientMessage message) =>
      _send(jsonEncode(message.toJson(protocol)));

  void _onFrame(String frame) {
    _inboundSinceArmed = true;
    final Map<String, Object?> json;
    try {
      json = jsonDecode(frame) as Map<String, Object?>;
    } catch (error, stackTrace) {
      _report(
        DwProtocolException('A frame is not a JSON object', error),
        stackTrace,
      );
      return;
    }
    final DwServerMessage message;
    try {
      message = DwServerMessage.fromJson(json, protocol);
    } catch (error, stackTrace) {
      _onUnreadable(json, error, stackTrace);
      return;
    }
    switch (message) {
      case DwAuthenticatedMessage():
        _onAuthenticated(message);
      case DwResultMessage():
        _pending.remove(message.id)?.onResult(message);
      case DwUpdateMessage():
        final record = _channels[message.channel];
        if (record == null || record.state == _SubState.closed) return;
        for (final entry in record.entries.toList()) {
          entry.applyItems(message.items);
        }
      case DwSubscribedMessage():
        _onSubscribed(message.channel);
      case DwSubscriptionRefusedMessage():
        _onSubscriptionRefused(message.channel, message.refusal);
      case DwChannelClosedMessage():
        _onChannelClosed(message.channel);
    }
  }

  /// A server message that does not decode. Reported, and where it can be
  /// told what the message was about, its effect is repaired rather than
  /// silently lost.
  void _onUnreadable(
    Map<String, Object?> json,
    Object error,
    StackTrace stackTrace,
  ) {
    final exception = DwProtocolException(
      'Cannot read a server message of kind "${json['k']}"',
      error,
    );
    _report(exception, stackTrace);
    switch (json) {
      case {'k': 'upd', 'ch': final String channel}:
        // An update nobody can read is an update lost: the requests living on
        // the channel ask again rather than drift from the server unnoticed.
        for (final entry in _channels[channel]?.entries.toList() ?? const []) {
          unawaited(entry.refetch());
        }
      case {'k': 'res', 'id': final int id}:
        _pending.remove(id)?.onAbort(exception, stackTrace);
    }
  }

  // --- liveness -------------------------------------------------------------

  void _armLiveness() {
    if (_livenessTimer != null) return;
    _inboundSinceArmed = false;
    _livenessTimer = Timer(options.callTimeout, _checkLiveness);
  }

  void _checkLiveness() {
    _livenessTimer = null;
    if (_connection == null) return;
    final waiting =
        _authQueue.isNotEmpty ||
        _pending.values.any((call) => call.generation == _generation);
    if (!waiting) return;
    if (!_inboundSinceArmed) {
      // A whole window with something asked and nothing heard: the connection
      // is dead even if the socket does not know it yet.
      _dropConnection();
      return;
    }
    _armLiveness();
  }

  // ===========================================================================
  // Authentication and session
  // ===========================================================================

  void _setSession(DwSession session) {
    _session = session;
    _sessionVersion++;
    _account.value = session.id;
  }

  void _clearSession() {
    _session = null;
    _sessionVersion++;
    _account.value = null;
    unawaited(
      tokenStore.clear().catchError((Object error, StackTrace stackTrace) {
        _report(error, stackTrace);
      }),
    );
  }

  void _authenticate(String? token) {
    _ready = false;
    _authQueue.add(token);
    _sendMessage(DwAuthenticateMessage(token));
    _armLiveness();
  }

  Future<void> _authSettled() {
    if (_authQueue.isEmpty) return Future.value();
    final waiter = Completer<void>();
    _authWaiters.add(waiter);
    return waiter.future;
  }

  void _completeAuthWaiters() {
    final waiters = _authWaiters.toList();
    _authWaiters.clear();
    for (final waiter in waiters) {
      waiter.complete();
    }
  }

  void _onAuthenticated(DwAuthenticatedMessage message) {
    if (_authQueue.isEmpty) {
      _onSessionChangedByServer(message);
      return;
    }
    final token = _authQueue.removeFirst();
    // A newer authentication is already on its way; its answer decides.
    if (_authQueue.isNotEmpty) return;

    final session = _session;
    if (token != session?.token) {
      // The session changed locally without a message (a not-authenticated
      // answer cleared it): converge on what the client holds now.
      _authenticate(session?.token);
      return;
    }

    int? account;
    if (session != null) {
      account = message.rejected ? null : message.accountId;
      if (account == null) {
        _clearSession();
      } else if (account != session.id) {
        // The server knows best whose token this is.
        final corrected = DwSession(
          id: account,
          token: session.token,
          isNewAccount: false,
        );
        _setSession(corrected);
        unawaited(
          tokenStore.write(corrected).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            _report(error, stackTrace);
          }),
        );
      }
    }
    _connectionAccount = account;
    _becomeReady();
    _completeAuthWaiters();
  }

  /// An authentication message nobody asked for: the server changed this
  /// connection's session on its own — the key was revoked by a sign-out on
  /// another device, or by the server.
  void _onSessionChangedByServer(DwAuthenticatedMessage message) {
    final account = message.rejected ? null : message.accountId;
    if (account == null && _session != null) _clearSession();
    if (account == _connectionAccount) return;
    _connectionAccount = account;
    if (_ready) _reconcile(newConnection: false, flush: false);
  }

  /// A call answered not-authenticated. When it went out under the session
  /// the client still holds, that session is over.
  void _onNotAuthenticated(_Call call) {
    final session = _session;
    if (session == null || call.sentToken != session.token) return;
    _clearSession();
    _connectionAccount = null;
    if (_ready) _reconcile(newConnection: false, flush: false);
  }

  void _becomeReady() {
    final newConnection = _readyGeneration != _generation;
    _ready = true;
    _readyGeneration = _generation;
    _status.value = DwConnectionStatus.connected;
    _reconcile(newConnection: newConnection, flush: true);
  }

  /// Aligns channels and entries with the current connection and account.
  ///
  /// The order is the protocol's: subscriptions first, so nothing published
  /// between a fetch and its subscription is missed; then the calls that
  /// waited (commands before re-runs, so a re-run sees what a queued command
  /// changed); then the entries.
  void _reconcile({required bool newConnection, required bool flush}) {
    final account = _connectionAccount;
    final accountChanged = account != _reconciledAccount;
    _reconciledAccount = account;

    for (final record in _channels.values) {
      final retry = switch (record.state) {
        _SubState.idle => true,
        // A refusal may not hold for another account, or after a reconnect.
        _SubState.refused => accountChanged || newConnection,
        // Closed is terminal for the account it was closed for.
        _SubState.closed => accountChanged,
        _SubState.subscribing || _SubState.active => false,
      };
      if (retry) {
        record.state = _SubState.subscribing;
        _sendMessage(DwSubscribeMessage(record.name));
      }
    }

    if (flush) {
      for (final call in _pending.values.toList()) {
        if (!_ready) break;
        if (call.entry == null && call.generation != _generation) _write(call);
      }
    }

    for (final entry in _allEntries.toList()) {
      if (!_ready) break;
      entry.onReady(newConnection: newConnection, account: account);
    }
  }

  // ===========================================================================
  // Calls
  // ===========================================================================

  _Call _enqueue(
    DwClientMessage Function(int id) build, {
    required void Function(DwResultMessage message, _Call call) onResult,
    required void Function(Object error, StackTrace stackTrace, _Call call)
    onAbort,
    _Entry? entry,
  }) {
    final id = _nextId++;
    // Encoded once: a re-send is byte-identical, idempotency key included.
    final frame = jsonEncode(build(id).toJson(protocol));
    late final _Call call;
    call = _Call(
      id,
      frame,
      entry,
      (message) => onResult(message, call),
      (error, stackTrace) => onAbort(error, stackTrace, call),
    );
    _pending[id] = call;
    // An entry's call goes out from the entry's own reconcile when not ready;
    // a one-shot call from the flush.
    if (_ready) _write(call);
    return call;
  }

  void _write(_Call call) {
    call.generation = _generation;
    call.sentAccount = _connectionAccount;
    call.sentToken = _session?.token;
    _send(call.frame);
    _armLiveness();
  }

  Future<DwResult<R>> _oneShot<R>({
    required String label,
    required DwClientMessage Function(int id) build,
    required R Function(Object? json) decode,
  }) {
    if (_lifecycle == _Lifecycle.stopped) {
      return Future.error(const DwClientStoppedException());
    }
    final completer = Completer<DwResult<R>>();
    Timer? deadline;
    final _Call call;
    try {
      call = _enqueue(
        build,
        onResult: (message, call) {
          deadline?.cancel();
          try {
            completer.complete(_decodeResult(message, call, label, decode));
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        },
        onAbort: (error, stackTrace, call) {
          deadline?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );
    } catch (error, stackTrace) {
      return Future.error(error, stackTrace);
    }
    deadline = Timer(options.callTimeout, () {
      if (_pending.remove(call.id) != null) {
        completer.completeError(DwTimeoutException(label, options.callTimeout));
      }
    });
    return completer.future;
  }

  DwResult<R> _decodeResult<R>(
    DwResultMessage message,
    _Call call,
    String label,
    R Function(Object? json) decode,
  ) {
    switch (message.status) {
      case DwResultStatus.ok:
        final R value;
        try {
          value = decode(message.value);
        } catch (error) {
          throw DwProtocolException(
            'Cannot decode the result of $label',
            error,
          );
        }
        return DwOk<R>(value);
      case DwResultStatus.refused:
        final refusal = message.refusal;
        if (refusal == null) {
          throw DwProtocolException('$label was refused without a refusal');
        }
        return DwRefused<R>(refusal);
      case DwResultStatus.unauthenticated:
        _onNotAuthenticated(call);
        return DwNotAuthenticated<R>();
      case DwResultStatus.failed:
        return DwFailed<R>(message.incidentId ?? '');
    }
  }

  /// 128 random bits as 32 hex digits, drawn 16 bits at a time: shifts and
  /// values past 32 bits do not survive compilation to JavaScript.
  String _newIdempotencyKey() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'));
    }
    return buffer.toString();
  }

  // ===========================================================================
  // Entries
  // ===========================================================================

  void _retain(_Entry entry) {
    entry.watchers++;
    entry.releaseTimer?.cancel();
    entry.releaseTimer = null;
  }

  void _release(_Entry entry) {
    entry.watchers--;
    if (entry.watchers > 0 || entry.disposed) return;
    final delay = options.releaseDelay;
    if (delay == Duration.zero) {
      _disposeEntry(entry);
      return;
    }
    entry.releaseTimer = Timer(delay, () {
      if (entry.watchers == 0 && !entry.disposed) _disposeEntry(entry);
    });
  }

  void _disposeEntry(_Entry entry) {
    switch (entry) {
      case _RequestEntry():
        _entries.remove(entry.request);
      case _PagedEntry():
        _pagedEntries.remove(entry.request);
    }
    entry.dispose();
    _detachChannels(entry);
  }

  void _report(Object error, StackTrace stackTrace) {
    final onError = _onError;
    if (onError != null) {
      onError(error, stackTrace);
    } else {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}

/// One request or command on its way to an answer.
final class _Call {
  _Call(this.id, this.frame, this.entry, this.onResult, this.onAbort);

  final int id;
  final String frame;

  /// The entry this call runs for; `null` for a one-shot call.
  final _Entry? entry;

  final void Function(DwResultMessage message) onResult;
  final void Function(Object error, StackTrace stackTrace) onAbort;

  /// The connection generation it was last written on; 0 while never sent.
  int generation = 0;
  int? sentAccount;
  String? sentToken;
}
