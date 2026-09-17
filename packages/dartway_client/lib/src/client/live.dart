part of 'dw_app_client.dart';

enum _SubState {
  /// Not subscribed on the current connection; subscribes when it can.
  idle,

  /// `sub` sent, answer pending.
  subscribing,

  active,

  /// The server said no. Retried after a reconnect or an account change.
  refused,

  /// The server closed the subscription (access revoked). Not retried for
  /// the same account.
  closed,
}

/// What holds a channel open: a request's entry, or a listener that only
/// hears what is published (`DwAppClient.listen`).
abstract interface class _ChannelMember {
  /// Wire names of its channels, caller channels resolved.
  List<String> get channels;

  bool get disposed;

  void absorb(List<DwWireObject> objects);

  void onChannelActivated(int seq);

  void onLiveChanged();

  Future<void> reload();
}

/// One wire channel and the members that need it. There is exactly one
/// record per channel name, however many members declare it: the reference
/// count is the size of [entries].
final class _ChannelRecord {
  _ChannelRecord(this.name);

  final String name;
  final Set<_ChannelMember> entries = {};
  _SubState state = _SubState.idle;
}

/// A `DwAppClient.listen` stream's hold on its channels. Reads nothing, keeps
/// nothing: every object published to its channels goes to the stream, and a
/// reconnect or a reload has nothing to fetch.
final class _ChannelListener implements _ChannelMember {
  _ChannelListener(this.declared, this.controller);

  final List<DwLiveChannel> declared;
  final StreamController<DwWireObject> controller;

  @override
  List<String> channels = const [];

  @override
  bool disposed = false;

  /// [declared] as wire names for [account]: a caller channel is that
  /// account's, and signed out there is none (D-037, D-020).
  void resolveFor(int? account) {
    channels = List.unmodifiable({
      for (final channel in declared)
        if (!channel.isOfCaller)
          channel.wireName
        else if (account != null)
          channel.resolvedFor(account).wireName,
    });
  }

  @override
  void absorb(List<DwWireObject> objects) {
    if (disposed) return;
    objects.forEach(controller.add);
  }

  @override
  void onChannelActivated(int seq) {}

  @override
  void onLiveChanged() {}

  @override
  Future<void> reload() async {}
}

/// The live socket's state, kept on the client (a part cannot add fields).
final class _LiveState {
  DwLiveConnection? connection;

  /// Increments with every connection.
  int generation = 0;

  /// The generation on which authentication last completed.
  int readyGeneration = 0;

  /// The id from `hello`; `null` until it arrives.
  String? connectionId;

  /// Hello received and authentication settled: subscriptions may be sent.
  bool ready = false;

  /// Tokens sent in `auth` messages on this connection, oldest first, each
  /// awaiting its answer.
  final Queue<String?> authQueue = Queue();

  /// The token and account the server confirmed for this connection.
  String? token;
  int? account;

  /// The account channels were last reconciled for, across connections.
  int? reconciledAccount;

  /// Whether the connect loop runs.
  bool looping = false;

  Timer? idleTimer;
  Completer<void>? sleeping;
  Timer? livenessTimer;
  bool inboundSinceArmed = false;

  /// Increments with every confirmed subscription; an entry whose data was
  /// asked for before its channel became active may have missed updates.
  int activationSeq = 0;
}

extension on DwAppClient {
  _LiveState get _live => _liveState;
  DwLiveConnection? get _liveConnection => _liveState.connection;

  /// Whether the socket should be open: something watched declares channels
  /// and an account is signed in. Every subscription requires sign-in
  /// (D-020) — a framework rule, not a project's — so a socket opened for an
  /// anonymous client would only collect refusals, and hold a connection per
  /// visitor for nothing.
  bool get _wantsLive =>
      _lifecycle == _Lifecycle.started &&
      _incompatibility.value == null &&
      _session != null &&
      _channels.isNotEmpty;

  Uri get _liveUrl => baseUrl.replace(
    scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
    path: _pathOf(DwHttpContract.livePath),
    queryParameters: {
      DwHttpContract.liveProtocolParameter: '$dwProtocolVersion',
      DwHttpContract.liveAppVersionParameter: '$appVersion',
    },
  );

  /// The live connection a call may name in `Dw-Live-Connection`: only one
  /// that is authenticated as the call's own token. Named, it keeps the
  /// call's updates off the socket — they come in the response — so naming
  /// a socket that acts for someone else would lose them.
  String? _liveConnectionIdFor(String? token) {
    final live = _live;
    if (!live.ready || live.authQueue.isNotEmpty || live.token != token) {
      return null;
    }
    return live.connectionId;
  }

  // ===========================================================================
  // Demand
  // ===========================================================================

  /// Opens the socket while some entry has channels and an account is signed
  /// in; closes it `liveIdleDelay` after either stops being true.
  void _updateLiveDemand() {
    final live = _live;
    if (_wantsLive) {
      live.idleTimer?.cancel();
      live.idleTimer = null;
      if (!live.looping && _sessionReady) {
        live.looping = true;
        unawaited(_liveLoop());
      }
      return;
    }
    if (!live.looping || live.idleTimer != null) return;
    live.idleTimer = Timer(options.liveIdleDelay, () {
      live.idleTimer = null;
      if (_wantsLive) return;
      final connection = live.connection;
      if (connection != null) unawaited(connection.close());
      _wakeLiveLoop();
    });
  }

  void _stopLive() {
    final live = _live;
    live.idleTimer?.cancel();
    live.idleTimer = null;
    live.livenessTimer?.cancel();
    live.livenessTimer = null;
    _wakeLiveLoop();
  }

  void _wakeLiveLoop() {
    final sleeping = _live.sleeping;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
  }

  /// Sets the status and tells the entries: one waiting for its
  /// subscriptions stops waiting once the socket is not coming up.
  void _setLiveStatus(DwConnectionStatus status) {
    if (_status.value == status) return;
    _status.value = status;
    for (final entry in _entries.values.toList()) {
      entry.onLiveChanged();
    }
  }

  Future<void> _liveLoop() async {
    try {
      await _connectRepeatedly();
    } finally {
      _live.looping = false;
    }
    if (_lifecycle == _Lifecycle.started && _incompatibility.value == null) {
      _setLiveStatus(DwConnectionStatus.idle);
      // Demand may have come back while the loop was ending.
      if (_wantsLive) _updateLiveDemand();
    }
  }

  Future<void> _connectRepeatedly() async {
    final live = _live;
    var failures = 0;
    while (_wantsLive) {
      _setLiveStatus(DwConnectionStatus.connecting);
      DwLiveConnection? connection;
      try {
        connection = await liveConnector.connect(_liveUrl);
      } catch (_) {
        // An unreachable server is an ordinary state for a client, visible as
        // the status and retried — not an error to report.
      }
      if (!_wantsLive) {
        await connection?.close();
        break;
      }
      if (connection != null) {
        await _serveLive(connection);
        if (_lifecycle == _Lifecycle.stopped) return;
        final code = connection.closeCode;
        if (code == DwCloseCode.incompatible) {
          _becomeIncompatible(_incompatibilityNamed(connection.closeReason));
          return;
        }
        switch (code) {
          case DwCloseCode.slowConsumer:
            // Shed under load; coming straight back would meet the same load,
            // so the backoff keeps growing.
            break;
          case final int code
              when code == DwCloseCode.protocolError ||
                  code == DwCloseCode.unsupportedData ||
                  code == DwCloseCode.messageTooBig:
            // This client sent what closed it, and reconnecting re-sends it:
            // loud, and backing off.
            _report(
              DwConnectionRejectedException(code, connection.closeReason),
              StackTrace.current,
            );
          default:
            // A connection that authenticated was a success; the next outage
            // counts from the first delay again.
            if (live.readyGeneration == live.generation) failures = 0;
        }
      }
      if (!_wantsLive) break;
      _setLiveStatus(DwConnectionStatus.disconnected);
      failures++;
      await _liveSleep(_backoff(failures));
    }
  }

  Future<void> _liveSleep(Duration delay) {
    final sleeping = _live.sleeping = Completer<void>();
    final timer = Timer(delay, () {
      if (!sleeping.isCompleted) sleeping.complete();
    });
    return sleeping.future.whenComplete(timer.cancel);
  }

  /// The refusal a `DwCloseCode.incompatible` close names in its reason.
  DwCallRefusal _incompatibilityNamed(String? reason) {
    for (final code in DwCoreRefusal.incompatibilities) {
      if (code.code == reason) return DwCallRefusal(code);
    }
    return DwCallRefusal(DwCoreRefusal.protocolUnsupported);
  }

  Future<void> _serveLive(DwLiveConnection connection) async {
    final live = _live
      ..connection = connection
      ..generation += 1
      ..connectionId = null
      ..ready = false
      ..token = null
      ..account = null;
    live.authQueue.clear();

    final over = Completer<void>();
    final subscription = connection.messages.listen(
      _onLiveFrame,
      onError: (Object error, StackTrace stackTrace) {
        // A transport error ends the connection; reconnecting is the answer.
        if (!over.isCompleted) over.complete();
      },
      onDone: () {
        if (!over.isCompleted) over.complete();
      },
    );
    // Waiting for hello: a server that accepted and says nothing is dead.
    _armLiveness();
    await over.future;
    await subscription.cancel();
    await connection.close();
    _onLiveLost();
  }

  void _onLiveLost() {
    final live = _live
      ..connection = null
      ..connectionId = null
      ..ready = false
      ..token = null
      ..account = null;
    live.authQueue.clear();
    live.livenessTimer?.cancel();
    live.livenessTimer = null;
    if (_lifecycle != _Lifecycle.started) return;
    for (final record in _channels.values) {
      // The server dropped them with the connection. A closed channel stays
      // closed: that was the server's word, not the connection's.
      if (record.state != _SubState.closed) record.state = _SubState.idle;
    }
    if (_incompatibility.value == null && _wantsLive) {
      _status.value = DwConnectionStatus.disconnected;
    }
    // Told even when the status did not change: the subscriptions did.
    for (final entry in _entries.values.toList()) {
      entry.onLiveChanged();
    }
  }

  // ===========================================================================
  // Frames
  // ===========================================================================

  void _sendLive(DwClientMessage message) {
    final connection = _live.connection;
    if (connection == null) return;
    try {
      connection.send(jsonEncode(message.toJson()));
    } catch (_) {
      // Closed under us; the done event is on its way and the next connection
      // re-sends what is still needed.
      unawaited(connection.close());
      return;
    }
    _armLiveness();
  }

  void _onLiveFrame(String frame) {
    _live.inboundSinceArmed = true;
    final Object? json;
    try {
      json = jsonDecode(frame);
    } catch (error, stackTrace) {
      _report(
        DwProtocolException('A live frame is not JSON', error),
        stackTrace,
      );
      return;
    }
    final DwServerMessage message;
    try {
      message = DwServerMessage.fromJson(json, protocol);
    } catch (error, stackTrace) {
      _onUnreadableLive(json, error, stackTrace);
      return;
    }
    switch (message) {
      case DwHelloMessage(:final connectionId):
        _onHello(connectionId);
      case DwAuthenticatedMessage():
        _onAuthenticated(message);
      case DwSubscribedMessage(:final channel):
        _onSubscribed(channel);
      case DwSubscriptionRefusedMessage():
        _onSubscriptionRefused(message);
      case DwUpdateMessage(:final channel, :final updates):
        final state = _channels[channel]?.state;
        // Only a subscription made on this connection for the current account
        // feeds state: an update for a released or closed channel may have
        // been checked for another account.
        if (state == _SubState.subscribing || state == _SubState.active) {
          _applyUpdates([(channel, updates.objects)]);
        }
      case DwChannelClosedMessage(:final channel):
        _onChannelClosed(channel);
    }
  }

  /// A server message that does not decode. Reported, and where it can be
  /// told what the message was about, its effect is repaired rather than
  /// silently lost.
  void _onUnreadableLive(Object? json, Object error, StackTrace stackTrace) {
    final kind = json is Map ? json['k'] : null;
    _report(
      DwProtocolException('Cannot read a live message of kind "$kind"', error),
      stackTrace,
    );
    if (json case {'k': 'upd', 'ch': final String channel}) {
      // An update nobody can read is an update lost: the requests living on
      // the channel ask again rather than drift from the server unnoticed.
      for (final entry in _channels[channel]?.entries.toList() ?? const []) {
        unawaited(entry.reload());
      }
    }
  }

  void _onHello(String connectionId) {
    final live = _live;
    if (live.connectionId != null) {
      _report(
        const DwProtocolException('A second hello on one live connection'),
        StackTrace.current,
      );
      return;
    }
    live.connectionId = connectionId;
    // The network is back: retries waiting out their backoff go now.
    _wakeRetries();
    final session = _session;
    if (session != null) {
      _authenticateLive(session.token);
    } else {
      _becomeLiveReady();
    }
  }

  // --- liveness -------------------------------------------------------------

  void _armLiveness() {
    final live = _live;
    if (live.livenessTimer != null) return;
    live.inboundSinceArmed = false;
    live.livenessTimer = Timer(options.callTimeout, _checkLiveness);
  }

  void _checkLiveness() {
    final live = _live..livenessTimer = null;
    final connection = live.connection;
    if (connection == null) return;
    final waiting =
        live.connectionId == null ||
        live.authQueue.isNotEmpty ||
        _channels.values.any((r) => r.state == _SubState.subscribing);
    if (!waiting) return;
    if (!live.inboundSinceArmed) {
      // A whole window with something asked and nothing heard: the socket is
      // dead even if it does not know it yet.
      unawaited(connection.close());
      return;
    }
    _armLiveness();
  }

  // ===========================================================================
  // Authentication
  // ===========================================================================

  /// Binds the socket to [token] unless it is bound (or being bound) to it
  /// already.
  void _authenticateLive(String? token) {
    final live = _live;
    if (live.connection == null || live.connectionId == null) return;
    final bound = live.authQueue.isEmpty ? live.token : live.authQueue.last;
    if (bound == token && (live.authQueue.isNotEmpty || live.ready)) return;
    live.ready = false;
    live.authQueue.add(token);
    _sendLive(DwAuthenticateMessage(token));
  }

  void _onAuthenticated(DwAuthenticatedMessage message) {
    final live = _live;
    final confirmed = message.rejected ? null : message.accountId;
    if (live.authQueue.isEmpty) {
      // Nobody asked: the server changed this connection's session on its
      // own — the key was revoked by a sign-out elsewhere, or by the server.
      if (confirmed == live.account) return;
      live.account = confirmed;
      if (confirmed == null) {
        live.token = null;
        // The server already unbound the socket, so ending the session sends
        // no second authentication.
        _endSession();
      }
      if (live.ready) _becomeLiveReady();
      return;
    }
    final token = live.authQueue.removeFirst();
    // A newer authentication is already on its way; its answer decides.
    if (live.authQueue.isNotEmpty) return;

    final session = _session;
    if (token != session?.token) {
      // The session changed locally without a message (a not-authenticated
      // answer ended it): converge on what the client holds now.
      _authenticateLive(session?.token);
      return;
    }
    // Settled before the session reacts, so ending or correcting it finds the
    // socket already bound as the server said and sends nothing more.
    live
      ..token = session == null || confirmed == null ? null : token
      ..account = session == null ? null : confirmed
      ..ready = true;
    if (session != null && confirmed == null) {
      _endSession();
    } else if (session != null && confirmed != session.id) {
      _correctAccount(session, confirmed!);
    }
    _becomeLiveReady();
  }

  /// Authenticated on the current connection: subscribe what is needed.
  void _becomeLiveReady() {
    final live = _live;
    if (live.connection == null) return;
    final newConnection = live.readyGeneration != live.generation;
    final accountChanged = live.account != live.reconciledAccount;
    live
      ..ready = true
      ..readyGeneration = live.generation
      ..reconciledAccount = live.account;
    // Set without telling the entries yet: they hear once the subscriptions
    // below are on their way.
    _status.value = DwConnectionStatus.connected;
    // Signed out while the socket winds down: nothing may be subscribed.
    if (_session == null) {
      for (final entry in _entries.values.toList()) {
        entry.onLiveChanged();
      }
      return;
    }
    for (final record in _channels.values.toList()) {
      final retry = switch (record.state) {
        _SubState.idle => true,
        // A refusal may not hold for another account, or after a reconnect.
        _SubState.refused => accountChanged || newConnection,
        // Closed is terminal for the account it was closed for.
        _SubState.closed => accountChanged,
        _SubState.subscribing || _SubState.active => false,
      };
      if (retry) _subscribe(record);
    }
    for (final entry in _entries.values.toList()) {
      entry.onLiveChanged();
    }
  }

  // ===========================================================================
  // Channels
  // ===========================================================================

  void _subscribe(_ChannelRecord record) {
    record.state = _SubState.subscribing;
    _sendLive(DwSubscribeMessage(record.name));
  }

  void _attachChannels(_ChannelMember entry) {
    if (entry.channels.isEmpty) return;
    for (final name in entry.channels) {
      final record = _channels.putIfAbsent(name, () => _ChannelRecord(name));
      record.entries.add(entry);
      if (record.state == _SubState.idle && _live.ready && _session != null) {
        _subscribe(record);
      }
    }
    _updateLiveDemand();
  }

  void _detachChannels(_ChannelMember entry) {
    if (entry.channels.isEmpty) return;
    for (final name in entry.channels) {
      final record = _channels[name];
      if (record == null) continue;
      record.entries.remove(entry);
      if (record.entries.isNotEmpty) continue;
      _channels.remove(name);
      // Subscribing or active means a `sub` went out on this connection; a
      // refused or closed channel holds nothing on the server to release.
      final held =
          record.state == _SubState.subscribing ||
          record.state == _SubState.active;
      if (held) _sendLive(DwUnsubscribeMessage(name));
    }
    _updateLiveDemand();
  }

  void _onSubscribed(String name) {
    final record = _channels[name];
    // No record: released while the answer travelled, and `unsub` followed.
    if (record == null || record.state != _SubState.subscribing) return;
    record.state = _SubState.active;
    final seq = ++_live.activationSeq;
    for (final entry in record.entries.toList()) {
      entry.onChannelActivated(seq);
    }
  }

  void _onSubscriptionRefused(DwSubscriptionRefusedMessage message) {
    final name = message.channel;
    final record = _channels[name];
    if (record == null || record.state != _SubState.subscribing) return;
    record.state = _SubState.refused;
    final refusal = message.refusal;
    // A refusal for access is the ordinary answer to a user without it, and
    // the request's own fetch tells that story. An unknown channel is the
    // server never having been taught a kind a request names: a wiring
    // mistake, silent unless reported. A failed check is an incident; it is
    // reported here too, because the data it leaves behind silently stops
    // being live.
    if (refusal != null && refusal.isCode(DwCoreRefusal.unknownChannel)) {
      _report(DwChannelRefusedException(name, refusal), StackTrace.current);
    } else if (message.incidentId case final incident?) {
      _report(DwChannelFailedException(name, incident), StackTrace.current);
    }
    for (final entry in record.entries.toList()) {
      entry.onLiveChanged();
    }
  }

  void _onChannelClosed(String name) {
    final record = _channels[name];
    if (record == null) return;
    final live = _live;
    if (live.authQueue.isNotEmpty) {
      // Part of an authentication change the client asked for: what is still
      // needed is subscribed again once it completes.
      record.state = _SubState.idle;
      for (final entry in record.entries.toList()) {
        entry.onLiveChanged();
      }
      return;
    }
    record.state = _SubState.closed;
    final entries = record.entries.toList();
    for (final entry in entries) {
      entry.onLiveChanged();
    }
    // Keep the data, stop being live, and ask again so the screen shows what
    // the new access allows — data, or a refusal. Asked on the next turn of
    // the event loop: a server that revokes a whole session closes the
    // channels first and rejects the session right after, and then the
    // entries are released rather than asked again.
    final account = live.account;
    final generation = live.generation;
    Timer.run(() {
      if (_lifecycle != _Lifecycle.started) return;
      if (live.generation != generation || live.account != account) return;
      for (final entry in entries) {
        if (!entry.disposed) unawaited(entry.reload());
      }
    });
  }

  /// Whether [entry]'s subscriptions are on their way, so fetching now could
  /// miss what is published before they are active.
  bool _liveSettling(_Entry entry) {
    // Signed out, nothing is subscribed: there is nothing to wait for.
    if (entry.channels.isEmpty || _session == null) return false;
    switch (_status.value) {
      case DwConnectionStatus.connecting:
        return true;
      case DwConnectionStatus.connected:
        return entry.channels.any((name) {
          final state = _channels[name]?.state;
          return state == _SubState.idle || state == _SubState.subscribing;
        });
      case DwConnectionStatus.idle ||
          DwConnectionStatus.disconnected ||
          DwConnectionStatus.incompatible:
        return false;
    }
  }

  /// Whether updates reach [entry] right now.
  bool _isLive(_Entry entry) =>
      entry.channels.isNotEmpty &&
      _live.ready &&
      entry.channels.every(
        (name) => _channels[name]?.state == _SubState.active,
      );
}
