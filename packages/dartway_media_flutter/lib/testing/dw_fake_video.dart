import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A stand-in for the `video_player` platform in a widget test.
///
/// Every video the app opens appears in [videos] as a [DwFakeVideo] the test
/// drives: it becomes [DwFakeVideo.ready] on its own (unless [readyOnOpen] is
/// off), and it moves only when the test says so — nothing plays by itself.
base class DwFakeVideoPlayerPlatform extends VideoPlayerPlatform {
  DwFakeVideoPlayerPlatform({
    this.length = const Duration(minutes: 1),
    this.readyOnOpen = true,
  });

  /// Installs a fake as `VideoPlayerPlatform.instance` and returns it.
  static DwFakeVideoPlayerPlatform install({
    Duration length = const Duration(minutes: 1),
    bool readyOnOpen = true,
  }) => VideoPlayerPlatform.instance = DwFakeVideoPlayerPlatform(
    length: length,
    readyOnOpen: readyOnOpen,
  );

  /// How long every video opened from now on is.
  Duration length;

  /// Whether a new video reports itself loaded at once. Off, the test calls
  /// [DwFakeVideo.ready] — until then `initialize()` waits.
  final bool readyOnOpen;

  final List<DwFakeVideo> _opened = [];

  /// Every video opened and not yet released, oldest first.
  List<DwFakeVideo> get videos => [
    for (final video in _opened)
      if (!video.isReleased) video,
  ];

  /// Every video ever opened, released ones included.
  List<DwFakeVideo> get opened => List.unmodifiable(_opened);

  /// The video opened last.
  DwFakeVideo get latest => _opened.last;

  DwFakeVideo _video(int id) => _opened[id];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final video = DwFakeVideo._(_opened.length, options.dataSource.uri, length);
    _opened.add(video);
    if (readyOnOpen) video.ready();
    return video.id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _video(playerId)._events.stream;

  @override
  Future<void> dispose(int playerId) async => _video(playerId)._release();

  @override
  Future<void> play(int playerId) async {
    final video = _video(playerId);
    if (video.refusePlayWith case final error?) throw error;
    video._playing = true;
  }

  @override
  Future<void> pause(int playerId) async => _video(playerId)._playing = false;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    final video = _video(playerId);
    if (video.refuseSeekWith case final error?) throw error;
    video.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => _video(playerId).position;

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      _video(playerId).volume = volume;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      _video(playerId).speed = speed;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

/// One video opened on a [DwFakeVideoPlayerPlatform], as the test sees it.
final class DwFakeVideo {
  DwFakeVideo._(this.id, this.uri, this.length);

  final int id;

  /// The address the app opened — a fresh one after a retry re-resolved it.
  final String? uri;

  Duration length;

  /// Where the platform says the video is. `video_player` reads it every
  /// 100 ms while playing; [advanceTo] is the usual way to move it.
  Duration position = Duration.zero;

  double volume = 1;
  double speed = 1;

  /// Thrown by the next `play()` / `seekTo()` while set — a browser refusing
  /// to play, a seek aborted.
  Object? refusePlayWith;
  Object? refuseSeekWith;

  bool _playing = false;
  bool _ready = false;
  bool _released = false;

  /// Single-subscription, cancelling with a future of the test's own zone: a
  /// broadcast stream's cancel completes in the root zone, which the fake
  /// clock of `testWidgets` never runs, and `VideoPlayerController.dispose`
  /// waits for exactly that cancel.
  final StreamController<VideoEvent> _events = StreamController(
    onCancel: () => Future<void>.value(),
  );

  /// Whether the app has told the platform to play and not to pause since.
  bool get isPlaying => _playing;

  bool get isReleased => _released;

  /// Reports the video loaded — what lets `initialize()` complete.
  void ready({Duration? length, Size size = const Size(1280, 720)}) {
    if (_ready) return;
    _ready = true;
    if (length != null) this.length = length;
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: this.length,
        size: size,
      ),
    );
  }

  /// Playback has reached [to] — seen by the app on its next 100 ms poll.
  void advanceTo(Duration to) => position = to;

  /// The platform's own end of playback.
  void finish() {
    position = length;
    _events.add(VideoEvent(eventType: VideoEventType.completed));
  }

  void startBuffering() =>
      _events.add(VideoEvent(eventType: VideoEventType.bufferingStart));

  void stopBuffering() =>
      _events.add(VideoEvent(eventType: VideoEventType.bufferingEnd));

  /// The video fails — the network gone, the link expired.
  void fail(String message) =>
      _events.addError(PlatformException(code: 'VideoError', message: message));

  void _release() {
    _released = true;
    _playing = false;
    unawaited(_events.close());
  }
}
