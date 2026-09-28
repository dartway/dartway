import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// `VideoPlayerPlatform.instance = DwFakeVideoPlayerPlatform()` — drives
/// `DwVideoMediaController` (and, through it, `video_player`'s own
/// `VideoPlayerController`) in a widget test without a plugin registered for
/// any platform.
///
/// **Position and duration are only ever what the test sets** —
/// [setPosition] and [emitInitialized]'s `duration` — there is no simulated
/// clock. `video_player` polls [getPosition] on a 100 ms timer while
/// "playing" (driven by `tester.pump`, which advances the same fake clock the
/// test binding runs timers on), so a progress test calls [setPosition] and
/// pumps that interval to have the controller pick it up.
///
/// [emitCompleted] is the one thing [setPosition] cannot simulate: it is the
/// engine's own signal that real playback reached the end, distinct from a
/// controller-side seek landing on the duration (which flips
/// `VideoPlayerValue.isCompleted` on its own, without this platform doing
/// anything — exactly the trap `DwVideoMediaController` is guarded against).
final class DwFakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<VideoEvent>> _events = {};
  final Map<int, Duration> _positions = {};

  /// `playerId`s created and not yet disposed — for a test asserting cleanup.
  Iterable<int> get livePlayers => _positions.keys;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    // Not awaited: a closed stream's done future completes outside a widget
    // test's fake clock, and `VideoPlayerController.dispose` would never
    // return inside `testWidgets`.
    unawaited(_events.remove(playerId)?.close());
    _positions.remove(playerId);
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextPlayerId++;
    // Single-subscription with an `onCancel` future of the test's own zone:
    // cancelling a broadcast subscription returns a future bound to the root
    // zone, which never completes inside `testWidgets` — and
    // `VideoPlayerController.dispose` awaits exactly that cancel.
    _events[id] = StreamController<VideoEvent>(
      onCancel: () => Future<void>.value(),
    );
    _positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  /// The mandatory first event — `VideoPlayerController.initialize()` does
  /// not complete without it.
  void emitInitialized(
    int playerId, {
    required Duration duration,
    Size size = const Size(1280, 720),
  }) {
    _events[playerId]!.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: size,
      ),
    );
  }

  /// Real playback reaching the end — see the class docs.
  void emitCompleted(int playerId) {
    _events[playerId]!.add(VideoEvent(eventType: VideoEventType.completed));
  }

  void emitBufferingStart(int playerId) {
    _events[playerId]!.add(
      VideoEvent(eventType: VideoEventType.bufferingStart),
    );
  }

  void emitBufferingEnd(int playerId) {
    _events[playerId]!.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
  }

  void emitError(int playerId, String message) {
    _events[playerId]!.addError(
      PlatformException(code: 'dw_fake_video_error', message: message),
    );
  }

  /// What `video_player`'s 100 ms polling timer reads back — set this, then
  /// pump the interval, to move `DwMediaPlaybackState.position` without going
  /// through a guarded [DwMediaController.seek].
  void setPosition(int playerId, Duration position) {
    _positions[playerId] = position;
  }
}
