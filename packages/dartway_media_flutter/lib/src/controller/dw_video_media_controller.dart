import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../lifecycle/dw_media_wakelock.dart';
import '../model/dw_media_playback_state.dart';
import 'dw_media_engine_controller.dart';

/// [DwMediaController] over `video_player`.
///
/// **The trap this guards against:** `VideoPlayerValue.isCompleted` becomes
/// `true` on *any* seek that lands on the duration, not only on real playback
/// reaching the end — a scrub to the end sets it exactly the same way. So
/// [markReachedEnd] is never called from watching `isCompleted` directly;
/// every seek this controller performs runs through [guardedSeek], which
/// suppresses it for the one synchronous state update the seek itself causes.
/// A real end-of-playback still calls it, because `VideoPlayerController`
/// reaches `isCompleted` there through its own internal `pause()`+`seekTo()`,
/// outside this controller's [guardedSeek].
///
/// **Web:** starting unmuted throws `NotAllowedError` outside a user gesture,
/// so with `options.webMutedStart` the controller loads muted and applies the
/// real volume once playback is actually granted (the first `isPlaying`
/// tick). `options.webRememberSoundChoice` is read by `DwMediaSession`, which
/// carries the last chosen volume into the next item's `initialSpeed`-like
/// wiring (see its docs).
final class DwVideoMediaController extends DwMediaEngineController {
  DwVideoMediaController({
    required super.item,
    required super.callbacks,
    required super.options,
    super.initialSpeed,
    super.initialMuted,
  });

  VideoPlayerController? _controller;
  bool _webSoundApplied = false;
  double _desiredVolume = 1;

  /// The underlying controller, once [engineLoad] completes — `null` before
  /// that and after [engineDispose]. `DwVideoSurface` reads this through
  /// `DwMediaSession.videoController`.
  VideoPlayerController? get videoController => _controller;

  @override
  Future<void> engineLoad(Uri uri) async {
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous.removeListener(_onUpdate);
      await previous.dispose();
    }
    final muteForWeb = kIsWeb && options.webMutedStart;
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
    );
    _controller = controller;
    _webSoundApplied = !muteForWeb;
    controller.addListener(_onUpdate);
    if (muteForWeb) await controller.setVolume(0);
    await controller.initialize();
    _onUpdate();
  }

  void _onUpdate() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      handleError(value.errorDescription ?? 'video playback error');
      return;
    }
    if (kIsWeb && value.isPlaying && !_webSoundApplied) {
      _webSoundApplied = true;
      unawaited(controller.setVolume(_desiredVolume));
    }
    if (value.isCompleted) markReachedEnd();
    unawaited(
      DwWakelockCoordinator.instance.setWants(
        this,
        value.isPlaying && options.wakelockWhilePlaying,
      ),
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
        speed: value.playbackSpeed,
        volume: _desiredVolume,
      ),
    );
  }

  @override
  Future<void> enginePlay() async {
    await _controller?.play();
  }

  @override
  Future<void> enginePause() async => _controller?.pause();

  @override
  Future<void> engineSeek(Duration position) async =>
      _controller?.seekTo(position);

  @override
  Future<void> engineSetSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> engineSetVolume(double volume) async {
    _desiredVolume = volume;
    // Stay muted until the web grants playback — see class docs.
    if (kIsWeb && !_webSoundApplied) return;
    await _controller?.setVolume(volume);
  }

  @override
  Future<void> engineDispose() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onUpdate);
    await DwWakelockCoordinator.instance.setWants(this, false);
    await controller?.dispose();
  }
}
