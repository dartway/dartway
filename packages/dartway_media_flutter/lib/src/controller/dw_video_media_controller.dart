import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../lifecycle/dw_media_wakelock.dart';
import '../model/dw_media_playback_state.dart';
import 'dw_media_engine_controller.dart';

/// [DwMediaController] over `video_player`.
///
/// `video_player`'s own background rule is switched off
/// (`allowBackgroundPlayback: true`): it pauses on `paused` and resumes by
/// itself on `resumed`, which would override
/// `DwMediaConfig.pauseVideoInBackground` both ways. `DwMedia` applies the
/// config's rule instead. The screen is kept on through
/// `preventsDisplaySleepDuringVideoPlayback` where the platform supports it
/// (iOS) and through `wakelock_plus` everywhere, both following
/// `DwMediaConfig.wakelockWhilePlaying`.
final class DwVideoMediaController extends DwMediaEngineController {
  DwVideoMediaController({
    required super.item,
    required super.callbacks,
    required super.options,
    super.initialSpeed,
    super.initialMuted,
  });

  VideoPlayerController? _controller;
  final ValueNotifier<VideoPlayerController?> _view = ValueNotifier(null);
  bool _initialized = false;
  bool _failureReported = false;

  /// The `video_player` controller to draw, once it has initialized — what
  /// `DwVideoSurface` renders. `null` while loading, and between a retry
  /// dropping the old one and the new one initializing.
  ValueListenable<VideoPlayerController?> get videoController => _view;

  @override
  Future<void> engineLoad(Uri uri) async {
    final previous = _controller;
    _controller = null;
    _view.value = null;
    if (previous != null) {
      previous.removeListener(_onValue);
      unawaited(_disposeAfterFrame(previous));
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        preventsDisplaySleepDuringVideoPlayback: options.wakelockWhilePlaying,
      ),
    );
    _controller = controller;
    _initialized = false;
    _failureReported = false;
    controller.addListener(_onValue);
    await controller.initialize();
    if (!identical(_controller, controller)) return;
    _initialized = true;
    _view.value = controller;
    _onValue();
  }

  /// On the web the video is a platform view: disposing its controller while
  /// the view is still in the tree throws in the browser. The surface drops
  /// the view on the frame after [_view] clears, and the controller goes
  /// after that frame.
  Future<void> _disposeAfterFrame(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (_) {
      // Pausing a controller on its way out: a failure changes nothing.
    }
    await SchedulerBinding.instance.endOfFrame;
    await controller.dispose();
  }

  void _onValue() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      // A failure during `initialize()` throws from `engineLoad` and is
      // reported there; this is the failure of a video already playing.
      if (_initialized && !_failureReported) {
        _failureReported = true;
        reportFailure(value.errorDescription ?? 'video playback failed');
      }
      return;
    }
    DwWakelockCoordinator.instance.setWants(
      this,
      value.isPlaying && options.wakelockWhilePlaying,
    );
    updateState(
      (current) => current.copyWith(
        playState: !value.isInitialized
            ? DwMediaPlayState.loading
            : value.isCompleted
            ? DwMediaPlayState.ended
            : value.isBuffering
            ? DwMediaPlayState.buffering
            : value.isPlaying
            ? DwMediaPlayState.playing
            : DwMediaPlayState.paused,
        position: value.position,
        duration: value.duration,
        buffered: value.buffered.isEmpty
            ? Duration.zero
            : value.buffered.last.end,
      ),
    );
  }

  @override
  Future<void> enginePlay() async => _controller?.play();

  @override
  Future<void> enginePause() async => _controller?.pause();

  @override
  Future<void> engineSeek(Duration position) async =>
      _controller?.seekTo(position);

  @override
  Future<void> engineSetSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> engineSetVolume(double volume) async =>
      _controller?.setVolume(volume);

  @override
  Future<void> engineDispose() async {
    final controller = _controller;
    _controller = null;
    _view.value = null;
    controller?.removeListener(_onValue);
    DwWakelockCoordinator.instance.setWants(this, false);
    await controller?.dispose();
  }
}
