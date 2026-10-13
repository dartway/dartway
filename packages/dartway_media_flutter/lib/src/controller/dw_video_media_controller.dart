import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart';

import '../lifecycle/dw_media_wakelock.dart';
import '../platform/dw_media_platform.dart';
import '../platform/dw_video_event_bridge.dart';
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
  _RestorationAttempt? _restoration;
  int _playOwnership = 0;
  Completer<void>? _waitingPlayWake;

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
      if (previous is _DwVideoPlayerController) previous.releaseEventBinding();
      previous.removeListener(_onValue);
      unawaited(_disposeAfterFrame(previous));
    }
    late final _DwVideoPlayerController controller;
    controller = _DwVideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        preventsDisplaySleepDuringVideoPlayback: options.wakelockWhilePlaying,
      ),
      onSurfaceAttached: _surfaceAttached,
      onSurfaceDetached: _surfaceDetached,
      onNativeEvent: (event) => _onNativeEvent(controller, event),
      onNativeError: (error, stack) => _onNativeError(controller, error, stack),
      onEventBindingReleased: () => _releasePlaybackOwnership(controller),
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
    if (_surfaceReleased) return;
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
        (_restoration != null && !_restoration!.completed) ||
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
    unawaited(_restorePlayback(controller));
  }

  Future<void> _restorePlayback(VideoPlayerController controller) async {
    if (_restoration != null && !_restoration!.completed) return;
    final attempt = _RestorationAttempt(controller);
    _restoration?.timer?.cancel();
    _restoration = attempt;
    // A single browser play promise owns this bounded error capture. Successful
    // native play plus promise completion ends it; an optimistic SDK value does not.
    attempt.timer = Timer(const Duration(seconds: 30), () {
      if (!identical(_restoration, attempt)) return;
      attempt.timedOut = true;
      attempt.retired = true;
      attempt.deadline.complete();
      // A pending browser promise cannot safely overlap another native play.
      // Stay paused until it settles or an explicit retry replaces the source.
      if (state.value.intent == DwMediaPlayIntent.play) reportPlayRefused();
      unawaited(controller.pause());
    });
    try {
      await runZoned(
        restoreEnginePlayback,
        zoneValues: {_restorationZone: attempt},
      );
      // The platform queues stream errors before its successful play future.
      await Future<void>.value();
    } finally {
      attempt.completed = true;
      if (!attempt.settled.isCompleted) attempt.settled.complete();
      if (identical(_restoration, attempt) &&
          (attempt.nativePlaying || attempt.terminalError || attempt.retired)) {
        _clearRestoration();
      }
    }
  }

  void _onNativeEvent(VideoPlayerController controller, VideoEvent event) {
    final attempt = _restoration;
    if (attempt == null || !identical(attempt.controller, controller)) return;
    if (event.eventType == VideoEventType.isPlayingStateUpdate) {
      attempt.nativePlaying = event.isPlaying == true;
      if (attempt.nativePlaying && attempt.completed) _clearRestoration();
    } else if (event.eventType == VideoEventType.completed) {
      _clearRestoration();
    }
  }

  bool _onNativeError(
    VideoPlayerController controller,
    Object error,
    StackTrace stack,
  ) {
    final attempt = _restoration;
    if (attempt == null ||
        !identical(attempt.controller, controller) ||
        !identical(_controller, controller) ||
        isDisposed ||
        _surfaceReleased) {
      return false;
    }
    if (error is! PlatformException ||
        (error.code != 'NotAllowedError' && error.code != 'AbortError')) {
      _clearRestoration();
      return false;
    }
    attempt.terminalError = true;
    _playSucceeded = false;
    if (!attempt.retired && state.value.intent == DwMediaPlayIntent.play) {
      reportPlayRefused();
    }
    // Suppressing the stream failure preserves initialized metadata. Pause also
    // corrects video_player's optimistic isPlaying and the actual native element.
    unawaited(controller.pause());
    return true;
  }

  void _invalidateWaitingPlay() {
    _playOwnership++;
    final wake = _waitingPlayWake;
    _waitingPlayWake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  void _releasePlaybackOwnership(VideoPlayerController controller) {
    if (!identical(controller, _controller)) return;
    _initialized = false;
    _invalidateWaitingPlay();
    _clearRestoration();
  }

  void _clearRestoration() {
    _restoration?.timer?.cancel();
    _restoration = null;
  }

  void _clearSurfaceHandoff() {
    _invalidateWaitingPlay();
    _clearRestoration();
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
    if (_surfaceReleased) return;
    DwWakelockCoordinator.instance.setWants(this, false);
    super.reportFailure(error, stackTrace);
  }

  @override
  Future<void> enginePlay() async {
    final controller = _controller;
    final restoration = _restoration;
    if (restoration != null && Zone.current[_restorationZone] != restoration) {
      final ownership = ++_playOwnership;
      restoration.retired = true;
      if (restoration.timedOut) {
        reportPlayRefused();
        return;
      }
      final wake = Completer<void>();
      _waitingPlayWake?.complete();
      _waitingPlayWake = wake;
      await Future.any<void>([
        restoration.settled.future,
        restoration.deadline.future,
        wake.future,
      ]);
      if (identical(_waitingPlayWake, wake)) _waitingPlayWake = null;
      if (ownership != _playOwnership ||
          !identical(controller, _controller) ||
          isDisposed ||
          _surfaceReleased ||
          state.value.isError ||
          state.value.intent != DwMediaPlayIntent.play) {
        return;
      }
      if (restoration.timedOut) {
        reportPlayRefused();
        return;
      }
      if (identical(_restoration, restoration)) _clearRestoration();
    }
    await controller?.play();
    if (controller != null &&
        identical(controller, _controller) &&
        !isDisposed &&
        !_surfaceReleased &&
        !controller.value.hasError &&
        !state.value.isError &&
        state.value.intent == DwMediaPlayIntent.play &&
        !(Zone.current[_restorationZone] is _RestorationAttempt &&
            (Zone.current[_restorationZone] as _RestorationAttempt).retired)) {
      _playSucceeded = true;
    }
  }

  @override
  Future<void> enginePause() async {
    _invalidateWaitingPlay();
    _restoration?.retired = true;
    _playSucceeded = false;
    _handoffPending = false;
    _handoffTimer?.cancel();
    await _controller?.pause();
  }

  @override
  Future<void> engineSeek(Duration position) async {
    _invalidateWaitingPlay();
    _restoration?.retired = true;
    _handoffPending = false;
    _handoffTimer?.cancel();
    await _controller?.seekTo(position);
    // A seek supersedes the waiting resume, then owns playback from its new
    // position once the old restoration command has settled.
    if (_restoration != null && state.value.intent == DwMediaPlayIntent.play) {
      await enginePlay();
    }
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

  @override
  void reportPlayRefused() {
    if (_surfaceReleased) return;
    super.reportPlayRefused();
  }

  /// The session releases presentation before deferred engine disposal.
  @internal
  void revokeVideoSurfaceHandoff() {
    _surfaceReleased = true;
    DwWakelockCoordinator.instance.setWants(this, false);
    _initialized = false;
    final controller = _controller;
    controller?.removeListener(_onValue);
    if (controller is _DwVideoPlayerController) {
      controller.releaseEventBinding();
    }
    _invalidateWaitingPlay();
    _clearRestoration();
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
    if (controller is _DwVideoPlayerController) {
      controller.releaseEventBinding();
    }
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
    required void Function(VideoEvent) onNativeEvent,
    required bool Function(Object, StackTrace) onNativeError,
    required void Function() onEventBindingReleased,
  }) : _onSurfaceAttached = onSurfaceAttached,
       _onSurfaceDetached = onSurfaceDetached,
       _eventBinding = DwVideoEventBinding(
         onEvent: onNativeEvent,
         onError: onNativeError,
         onRelease: onEventBindingReleased,
       ),
       super.networkUrl();

  final DwVideoEventBinding _eventBinding;

  @override
  Future<void> initialize() => dwMediaIsWeb
      ? _eventBinding.initialize(super.initialize)
      : super.initialize();

  void releaseEventBinding() => _eventBinding.release();

  final void Function(VideoPlayerController) _onSurfaceAttached;
  final void Function(VideoPlayerController) _onSurfaceDetached;

  @override
  void attachVideoSurface() => _onSurfaceAttached(this);

  @override
  void detachVideoSurface() => _onSurfaceDetached(this);

  final Set<Future<void>> _pendingPlays = {};
  bool _disposing = false;

  @override
  Future<void> play() async {
    if (!dwMediaIsWeb) return super.play();
    if (_disposing) return;
    final completion = Completer<void>();
    _pendingPlays.add(completion.future);
    try {
      await super.play();
      // The SDK starts its position timer after awaiting native play. A pause
      // or release during that await must cancel the newly-created timer too.
      if (_disposing || !value.isPlaying) await super.pause();
    } finally {
      _pendingPlays.remove(completion.future);
      completion.complete();
    }
  }

  @override
  Future<void> dispose() async {
    if (!dwMediaIsWeb) return super.dispose();
    if (_disposing) return;
    _disposing = true;
    releaseEventBinding();
    // HTML pause aborts pending play. Ownership is already gone; only native
    // resource disposal waits. A broken delegate that never settles cannot be
    // safely force-disposed without the SDK creating a timer after disposal.
    await super.pause();
    if (_pendingPlays.isNotEmpty) await Future.wait(_pendingPlays.toList());
    await Future<void>.value();
    await super.pause();
    await super.dispose();
  }

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

final class _RestorationAttempt {
  _RestorationAttempt(this.controller);
  final VideoPlayerController controller;
  Timer? timer;
  bool nativePlaying = false;
  bool completed = false;
  bool retired = false;
  bool timedOut = false;
  bool terminalError = false;
  final settled = Completer<void>();
  final deadline = Completer<void>();
}

final Object _restorationZone = Object();
