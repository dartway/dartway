import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../domain/dw_socket_status.dart';

/// Keeps the channels the app asked to follow apart from the streams that
/// currently carry them, and reopens what the network takes away.
///
/// A stream dies with the connection it was opened on, so the two must not be
/// the same bookkeeping: the request outlives the socket and is what the next
/// attempt is rebuilt from. Without that split a network blip silently ends
/// every channel subscription for the rest of the session — the stream ends,
/// its entry is dropped, and nothing ever asks for it again.
///
/// The retry loop lives here because nothing else has one. Serverpod's
/// `StreamingConnectionHandler` reconnected the old streaming connection, but
/// it belongs to the deprecated API and there is no method-stream equivalent:
/// `ClientMethodStreamManager` detects a dead socket and fails every open
/// stream, then stops. Whoever wants the subscription back has to ask again.
class DwChannelSubscriptions {
  DwChannelSubscriptions({
    required this.openChannelStream,
    required this.onUpdate,
    required this.onStatusChanged,
    required this.onChannelClosedByServer,
    this.retryDelay = const Duration(seconds: 5),
  });

  /// Opens the server-side stream for a channel. Injected so the bookkeeping
  /// can be exercised without a client.
  final Stream<SerializableModel> Function(String channelName)
  openChannelStream;

  final void Function(SerializableModel update) onUpdate;

  /// Called whenever [status] changes.
  final void Function(DwSocketStatus status) onStatusChanged;

  /// Called when the server ended a subscription on purpose — the channel is
  /// dropped rather than retried, and the app decides what that means.
  final void Function(String channelName, DwChannelClosedReason reason)
  onChannelClosedByServer;

  /// How long a failed channel waits before it is opened again.
  ///
  /// Fixed rather than backed off, and no shorter than Serverpod's own former
  /// default: every attempt opens a fresh server-side session with its own log
  /// buffer and socket, so an unstable network turns a keen retry into a
  /// reconnect storm.
  final Duration retryDelay;

  final Set<String> _requestedChannels = {};
  final Map<String, StreamSubscription<SerializableModel>> _liveStreams = {};
  Timer? _retryTimer;
  var _started = false;
  var _status = DwSocketStatus.idle;

  /// Channels the app asked to follow, whether or not they are carried now.
  Iterable<String> get requestedChannels => _requestedChannels;

  /// Channels with a live stream at this moment.
  Iterable<String> get liveChannels => _liveStreams.keys;

  DwSocketStatus get status => _status;

  /// Starts opening what has been requested. Called once the app is running:
  /// requests made while it was still starting up are honoured here, so the
  /// first socket is not opened underneath an app that is not ready for it.
  void start() {
    if (_started) return;
    _started = true;
    _openMissingStreams();
  }

  /// Follows [channelName] from now on. Opening is deferred until [start].
  void request(String channelName) {
    _requestedChannels.add(channelName);
    _openStream(channelName);
    _publishStatus();
  }

  /// Stops following [channelName].
  Future<void> release(String channelName) async {
    _requestedChannels.remove(channelName);
    await _liveStreams.remove(channelName)?.cancel();
    _publishStatus();
  }

  /// Stops following every channel — on sign-out, or when the service is
  /// disposed.
  Future<void> releaseAll() async {
    _requestedChannels.clear();
    _retryTimer?.cancel();
    _retryTimer = null;
    await _cancelLiveStreams();
    _publishStatus();
  }

  /// Drops every live stream and opens the requested channels again.
  ///
  /// What an account switch needs: a method stream carries the authentication
  /// it was opened with, so one that outlives the session it belongs to keeps
  /// delivering the previous user's channel into the next user's app. The
  /// requests stand — they belong to the app, not to whoever was signed in —
  /// and each one is checked again by the server as it reopens.
  Future<void> reopenAll() async {
    await _cancelLiveStreams();
    _openMissingStreams();
  }

  Future<void> dispose() async {
    _started = false;
    await releaseAll();
  }

  void _openStream(String channelName) {
    if (!_started ||
        !_requestedChannels.contains(channelName) ||
        _liveStreams.containsKey(channelName)) {
      return;
    }

    try {
      _liveStreams[channelName] = openChannelStream(channelName).listen(
        onUpdate,
        onDone: () => _handleStreamEnded(channelName),
        onError: (error, _) => _handleStreamFailed(channelName, error),
        cancelOnError: true,
      );
    } catch (error) {
      // Opening threw instead of failing the stream. Treated as any other
      // failure: the request stands and the next tick tries again.
      _handleStreamFailed(channelName, error);
    }
  }

  void _openMissingStreams() {
    for (final channelName in _requestedChannels.toList()) {
      _openStream(channelName);
    }
    _publishStatus();
  }

  /// The stream ended without an error — the socket went away under it. The
  /// request stands, so it is opened again on the next tick.
  void _handleStreamEnded(String channelName) {
    _liveStreams.remove(channelName);
    _scheduleRetry();
    _publishStatus();
  }

  void _handleStreamFailed(String channelName, Object error) {
    _liveStreams.remove(channelName);

    // A refusal is not a network blip: asking again with the same session gets
    // the same answer, and a channel nobody may listen to would otherwise be
    // reopened every few seconds for the life of the app.
    if (error is DwChannelClosed) {
      _requestedChannels.remove(channelName);
      _publishStatus();
      onChannelClosedByServer(channelName, error.reason);
      return;
    }

    _scheduleRetry();
    _publishStatus();
  }

  void _scheduleRetry() {
    if (!_started || _retryTimer != null) return;

    // One timer for every failed channel rather than one each: they fail
    // together, because what they share is the socket.
    //
    // The loop keeps itself going through the failures, not from here — an
    // attempt that cannot connect fails asynchronously, lands in
    // [_handleStreamFailed] and asks for the next tick.
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      _openMissingStreams();
    });
  }

  Future<void> _cancelLiveStreams() async {
    final liveStreams = _liveStreams.values.toList();
    _liveStreams.clear();

    for (final stream in liveStreams) {
      await stream.cancel();
    }
  }

  void _publishStatus() {
    final status = switch (_requestedChannels.length) {
      0 => DwSocketStatus.idle,
      final requested when _liveStreams.length == requested =>
        DwSocketStatus.connected,
      _ => DwSocketStatus.waitingToRetry,
    };

    if (status == _status) return;

    _status = status;
    onStatusChanged(status);
  }
}
