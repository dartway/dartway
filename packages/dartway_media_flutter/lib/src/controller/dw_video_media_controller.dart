import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../lifecycle/dw_media_wakelock.dart';
import '../platform/dw_media_platform.dart';
import '../model/dw_media_playback_state.dart';
import 'dw_media_reducer.dart';
import 'dw_media_engine_controller.dart';
import 'dw_video_surface_binding.dart';

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
    super.onPlaybackEnd,
    super.onObservationBreak,
    super.onSourceChange,
    super.onPlayedInterval,
  });

  VideoPlayerController? _controller;
  final ValueNotifier<VideoPlayerController?> _view = ValueNotifier(null);
  bool _initialized = false;
  bool _failureReported = false;
  bool _playSucceeded = false;
  bool _surfaceReleased = false;
  int _surfaceCount = 0;
  bool _surfaceWasMounted = false;
  bool _handoffPending = false;
  bool _handoffPainted = false;
  int _handoffEpoch = 0;
  Timer? _handoffTimer;

  /// The `video_player` controller to draw, once it has initialized — what
  /// `DwVideoSurface` renders. `null` while loading, and between a retry
  /// dropping the old one and the new one initializing.
  ValueListenable<VideoPlayerController?> get videoController => _view;

  @override
  Future<void> engineLoad(Uri uri) async {
    _clearSurfaceHandoff();
    _playSucceeded = false;
    final previous = _controller;
    _controller = null;
    _view.value = null;
    if (previous != null) {
      previous.removeListener(_onValue);
      unawaited(_disposeAfterFrame(previous));
    }
    final controller = _DwVideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        preventsDisplaySleepDuringVideoPlayback: options.wakelockWhilePlaying,
      ),
      onSurfaceAttached: _surfaceAttached,
      onSurfaceDetached: _surfaceDetached,
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
    final seekEpoch = engineSeekEpoch;
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
    reportEngine(
      EngineFact(
        loading: !value.isInitialized,
        ended: value.isCompleted,
        buffering: value.isBuffering,
        playing: value.isPlaying,
        position: value.position,
        duration: value.duration,
        buffered: value.buffered.isEmpty
            ? Duration.zero
            : value.buffered.last.end,
        seekEpoch: seekEpoch,
      ),
    );
    _restoreSurfaceHandoff();
  }

  void _surfaceAttached(VideoPlayerController controller) {
    if (!dwMediaIsWeb ||
        _surfaceReleased ||
        !identical(controller, _controller)) {
      return;
    }
    _surfaceCount++;
    final replacement = _surfaceWasMounted;
    _surfaceWasMounted = true;
    if (!replacement ||
        !_playSucceeded ||
        state.value.intent != DwMediaPlayIntent.play) {
      return;
    }
    _handoffTimer?.cancel();
    _handoffPending = true;
    _handoffPainted = false;
    final epoch = ++_handoffEpoch;
    _handoffTimer = Timer(const Duration(milliseconds: 500), () {
      if (epoch == _handoffEpoch) _handoffPending = false;
    });
    unawaited(_afterSurfaceFrame(controller, epoch));
  }

  void _surfaceDetached(VideoPlayerController controller) {
    if (!dwMediaIsWeb || !identical(controller, _controller)) return;
    if (_surfaceCount > 0) _surfaceCount--;
    if (_surfaceCount == 0) _handoffPainted = false;
  }

  Future<void> _afterSurfaceFrame(
    VideoPlayerController controller,
    int epoch,
  ) async {
    // A web platform view can still be detached at the replacement frame's
    // end. Give its DOM placement two further rendered frames before play;
    // playing the detached element is itself immediately paused by Chrome.
    for (var frame = 0; frame < 3; frame++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!identical(controller, _controller) ||
          epoch != _handoffEpoch ||
          !_handoffPending ||
          _surfaceCount == 0 ||
          _surfaceReleased ||
          isDisposed) {
        return;
      }
    }
    _handoffPainted = true;
    // One attempt within the mount's lease, never a position-poll retry loop.
    _restoreSurfaceHandoff();
  }

  void _restoreSurfaceHandoff() {
    final controller = _controller;
    if (!_handoffPending ||
        !_handoffPainted ||
        _surfaceCount == 0 ||
        controller == null ||
        !_initialized ||
        _surfaceReleased ||
        isDisposed ||
        controller.value.isPlaying ||
        controller.value.hasError ||
        controller.value.isCompleted ||
        state.value.isError ||
        state.value.intent != DwMediaPlayIntent.play ||
        state.value.seekTarget != null) {
      return;
    }
    _handoffPending = false;
    _handoffTimer?.cancel();
    unawaited(restoreEnginePlayback());
  }

  void _clearSurfaceHandoff() {
    _handoffTimer?.cancel();
    _handoffTimer = null;
    _handoffEpoch++;
    _surfaceCount = 0;
    _surfaceWasMounted = false;
    _handoffPending = false;
    _handoffPainted = false;
  }

  /// A failed video is not playing, whatever its last value said: the
  /// screen may sleep again.
  @override
  void reportFailure(Object error, [StackTrace? stackTrace]) {
    DwWakelockCoordinator.instance.setWants(this, false);
    super.reportFailure(error, stackTrace);
  }

  @override
  Future<void> enginePlay() async {
    final controller = _controller;
    await controller?.play();
    if (controller != null &&
        identical(controller, _controller) &&
        !isDisposed &&
        state.value.intent == DwMediaPlayIntent.play) {
      _playSucceeded = true;
    }
  }

  @override
  Future<void> enginePause() async {
    _playSucceeded = false;
    _handoffPending = false;
    _handoffTimer?.cancel();
    await _controller?.pause();
  }

  @override
  Future<void> engineSeek(Duration position) async {
    _handoffPending = false;
    _handoffTimer?.cancel();
    await _controller?.seekTo(position);
  }

  @override
  Future<void> engineSetSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> engineSetVolume(double volume) async =>
      _controller?.setVolume(volume);

  @override
  Future<void> dispose() async {
    // Revoke the lease before the base awaits observation/resume storage.
    revokeVideoSurfaceHandoff();
    await super.dispose();
  }

  /// The session releases presentation before deferred engine disposal.
  @internal
  void revokeVideoSurfaceHandoff() {
    _surfaceReleased = true;
    _playSucceeded = false;
    _handoffPending = false;
    _handoffTimer?.cancel();
  }

  @override
  Future<void> engineDispose() async {
    _clearSurfaceHandoff();
    final controller = _controller;
    _controller = null;
    _view.value = null;
    controller?.removeListener(_onValue);
    DwWakelockCoordinator.instance.setWants(this, false);
    await controller?.dispose();
  }
}

final class _DwVideoPlayerController extends VideoPlayerController
    implements DwVideoSurfaceBinding {
  _DwVideoPlayerController.networkUrl(
    super.url, {
    super.videoPlayerOptions,
    required void Function(VideoPlayerController) onSurfaceAttached,
    required void Function(VideoPlayerController) onSurfaceDetached,
  }) : _onSurfaceAttached = onSurfaceAttached,
       _onSurfaceDetached = onSurfaceDetached,
       super.networkUrl();

  final void Function(VideoPlayerController) _onSurfaceAttached;
  final void Function(VideoPlayerController) _onSurfaceDetached;

  @override
  void attachVideoSurface() => _onSurfaceAttached(this);

  @override
  void detachVideoSurface() => _onSurfaceDetached(this);

  int _seekEpoch = 0;
  int _seeking = 0;

  @override
  Future<Duration?> get position async {
    final epoch = _seekEpoch;
    final clean = _seeking == 0;
    final position = await super.position;
    return clean && epoch == _seekEpoch ? position : value.position;
  }

  @override
  Future<void> seekTo(Duration position) async {
    _seekEpoch++;
    _seeking++;
    try {
      await super.seekTo(position);
    } finally {
      _seeking--;
      _seekEpoch++;
    }
  }
}
