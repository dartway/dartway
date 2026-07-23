import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

/// Keeps the channels the app asked to follow apart from the streams that
/// currently carry them.
///
/// A stream dies with the connection it was opened on, so the two must not be
/// the same bookkeeping: the request outlives the socket and is what the next
/// connection is rebuilt from. Without that split a network blip silently ends
/// every channel subscription for the rest of the session — the stream ends,
/// its entry is dropped, and nothing ever asks for it again.
class DwChannelSubscriptions {
  DwChannelSubscriptions({
    required this.openChannelStream,
    required this.onUpdate,
  });

  /// Opens the server-side stream for a channel. Injected so the bookkeeping
  /// can be exercised without a client.
  final Stream<SerializableModel> Function(String channelName)
  openChannelStream;

  final void Function(SerializableModel update) onUpdate;

  final Set<String> _requestedChannels = {};
  final Map<String, StreamSubscription<SerializableModel>> _liveStreams = {};
  var _isConnected = false;

  /// Channels the app asked to follow, whether or not they are carried now.
  Iterable<String> get requestedChannels => _requestedChannels;

  /// Channels with a live stream at this moment.
  Iterable<String> get liveChannels => _liveStreams.keys;

  /// Follows [channelName] from now on. Opening is deferred while the
  /// connection is down and happens on the next [handleConnected].
  void request(String channelName) {
    _requestedChannels.add(channelName);
    _openStream(channelName);
  }

  /// Stops following [channelName].
  Future<void> release(String channelName) async {
    _requestedChannels.remove(channelName);
    await _liveStreams.remove(channelName)?.cancel();
  }

  /// Stops following every channel — on sign-out, or when the service is
  /// disposed.
  Future<void> releaseAll() async {
    _requestedChannels.clear();
    await _cancelLiveStreams();
  }

  /// The connection is up. Streams from the previous one are dead even when
  /// their `onDone` has not landed yet, so they are dropped and every requested
  /// channel is opened again.
  Future<void> handleConnected() async {
    _isConnected = true;
    await _cancelLiveStreams();

    for (final channelName in _requestedChannels) {
      _openStream(channelName);
    }
  }

  void handleDisconnected() => _isConnected = false;

  void _openStream(String channelName) {
    if (!_isConnected || _liveStreams.containsKey(channelName)) return;

    _liveStreams[channelName] = openChannelStream(channelName).listen(
      onUpdate,
      onDone: () => _liveStreams.remove(channelName),
      onError: (_, __) => _liveStreams.remove(channelName),
      cancelOnError: true,
    );
  }

  Future<void> _cancelLiveStreams() async {
    final liveStreams = _liveStreams.values.toList();
    _liveStreams.clear();

    for (final stream in liveStreams) {
      await stream.cancel();
    }
  }
}
