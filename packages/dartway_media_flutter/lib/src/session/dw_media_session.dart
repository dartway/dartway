import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../config/dw_media_config.dart';
import '../controller/dw_media_controller.dart';
import '../controller/dw_video_media_controller.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import 'dw_media_queue_state.dart';
import 'dw_media_session_manager.dart';

/// A queue, its current controller, fullscreen and minimized state — one
/// `DwMedia.open()` call. **Survives route changes**: the widget tree can be
/// torn down and rebuilt (a page popped and pushed again, the mini-player
/// taking over) without this object being touched, which is what lets
/// playback continue uninterrupted. Held by `DwMediaSessionManager`, not by
/// any widget's `State`.
final class DwMediaSession {
  DwMediaSession._({
    required List<DwMediaItem> items,
    required int startIndex,
    required DwMediaCallbacks appCallbacks,
    required DwMediaConfig options,
    required DwMediaSessionManager manager,
  }) : _appCallbacks = appCallbacks,
       options = options,
       _manager = manager,
       queue = ValueNotifier(
         DwMediaQueueState(items: items, currentIndex: startIndex),
       ) {
    _controllerCallbacks = DwMediaCallbacks(
      onStarted: appCallbacks.onStarted,
      onProgress: appCallbacks.onProgress,
      progressInterval: options.progressInterval,
      onReachedEnd: (item) {
        appCallbacks.onReachedEnd?.call(item);
        if (options.autoplayNext) unawaited(next());
      },
      onCompleted: appCallbacks.onCompleted,
      completedThreshold: options.completedThreshold,
      onError: appCallbacks.onError,
    );
    _openCurrent(autoplay: options.autoplayOnOpen);
  }

  /// Factory used by `DwMediaSessionManager.open` — not a public constructor,
  /// since a session is always owned by the manager.
  static DwMediaSession open({
    required List<DwMediaItem> items,
    required int startIndex,
    required DwMediaCallbacks callbacks,
    required DwMediaConfig options,
    required DwMediaSessionManager manager,
  }) => DwMediaSession._(
    items: items,
    startIndex: startIndex,
    appCallbacks: callbacks,
    options: options,
    manager: manager,
  );

  final DwMediaCallbacks _appCallbacks;
  late final DwMediaCallbacks _controllerCallbacks;

  /// The resolved settings this session was opened with — read by a controls
  /// widget for `speeds`, `controlsAutoHideDelay`, and so on.
  final DwMediaConfig options;

  final DwMediaSessionManager _manager;

  final ValueNotifier<DwMediaQueueState> queue;
  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);

  /// Whether `DwMiniPlayerHost` should show this session shrunk down. Set by
  /// the app's own navigation (`minimize()` on leaving the full player page,
  /// `restore()` on reopening it) — the plugin has no opinion on routing.
  final ValueNotifier<bool> minimized = ValueNotifier(false);

  DwMediaController? _controller;
  double? _rememberedSpeed;
  bool? _rememberedMuted;
  Timer? _previewTimer;
  bool _disposed = false;

  bool get isDisposed => _disposed;
  DwMediaController get controller => _controller!;
  DwMediaItem get currentItem => queue.value.current;

  /// The playing `VideoPlayerController`, when the current item is a video —
  /// what `DwVideoSurface` renders. `null` for an audio item or before the
  /// video finishes loading.
  VideoPlayerController? get videoController {
    final controller = _controller;
    return controller is DwVideoMediaController
        ? controller.videoController
        : null;
  }

  void _openCurrent({required bool autoplay}) {
    final item = queue.value.current;
    _controller = DwMediaController.forItem(
      item: item,
      callbacks: _controllerCallbacks,
      options: options,
      initialSpeed: options.rememberSpeedAcrossItems ? _rememberedSpeed : null,
      initialMuted: options.webRememberSoundChoice ? _rememberedMuted : null,
    );
    _previewTimer?.cancel();
    if (options.nextPreview || options.autoplayNext) {
      _previewTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickPreview(),
      );
    }
    if (autoplay) unawaited(play());
  }

  void _tickPreview() {
    if (_disposed) return;
    final current = queue.value;
    final playback = _controller?.state.value;
    if (playback == null || !current.hasNext || playback.duration <= Duration.zero) {
      if (current.showNextPreview || current.autoplayCountdownSeconds != null) {
        queue.value = current.copyWith(
          showNextPreview: false,
          autoplayCountdownSeconds: null,
        );
      }
      return;
    }
    final remaining = playback.duration - playback.position;
    final showPreview =
        options.nextPreview && remaining <= options.nextPreviewLeadTime;
    int? countdown;
    if (options.autoplayNext &&
        options.autoplayCountdown &&
        remaining <= options.autoplayCountdownDuration) {
      countdown = remaining.inSeconds.clamp(
        0,
        options.autoplayCountdownDuration.inSeconds,
      );
    }
    if (showPreview != current.showNextPreview ||
        countdown != current.autoplayCountdownSeconds) {
      queue.value = current.copyWith(
        showNextPreview: showPreview,
        autoplayCountdownSeconds: countdown,
      );
    }
  }

  // --- Playback delegated to the current controller ------------------------

  Future<void> play() async {
    if (_disposed) return;
    if (options.singleActiveItem) _manager.claimActive(this);
    if (options.autoEnterFullscreenOnPlay &&
        currentItem.kind == DwMediaKind.video &&
        options.fullscreen) {
      isFullscreen.value = true;
    }
    await controller.play();
  }

  Future<void> pause() => _disposed ? Future.value() : controller.pause();

  Future<void> seek(Duration position) =>
      _disposed ? Future.value() : controller.seek(position);

  Future<void> skipBack() =>
      _disposed ? Future.value() : controller.skip(-options.skipBack);

  Future<void> skipForward() =>
      _disposed ? Future.value() : controller.skip(options.skipForward);

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    _rememberedSpeed = speed;
    await controller.setSpeed(speed);
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    _rememberedMuted = muted;
    await controller.setMuted(muted);
  }

  Future<void> setVolume(double volume) => controller.setVolume(volume);

  Future<void> retry() => controller.retry();

  // --- Queue -----------------------------------------------------------

  Future<void> next({bool autoplay = true}) => _disposed || !queue.value.hasNext
      ? Future.value()
      : _advanceTo(queue.value.currentIndex + 1, autoplay: autoplay);

  Future<void> previous({bool autoplay = true}) =>
      _disposed || !queue.value.hasPrevious
      ? Future.value()
      : _advanceTo(queue.value.currentIndex - 1, autoplay: autoplay);

  Future<void> jumpTo(int index, {bool autoplay = true}) =>
      _disposed || index < 0 || index >= queue.value.items.length
      ? Future.value()
      : _advanceTo(index, autoplay: autoplay);

  Future<void> _advanceTo(int index, {required bool autoplay}) async {
    final old = _controller;
    _rememberedSpeed = old?.state.value.speed ?? _rememberedSpeed;
    _rememberedMuted = old?.state.value.muted ?? _rememberedMuted;
    await old?.dispose();
    queue.value = queue.value.copyWith(
      currentIndex: index,
      showNextPreview: false,
      autoplayCountdownSeconds: null,
    );
    if (isFullscreen.value && !options.keepFullscreenAcrossItems) {
      isFullscreen.value = false;
    }
    _openCurrent(autoplay: autoplay);
    _appCallbacks.onItemChanged?.call(queue.value.current);
  }

  // --- Fullscreen / mini-player --------------------------------------------

  void enterFullscreen() {
    if (options.fullscreen) isFullscreen.value = true;
  }

  void exitFullscreen() => isFullscreen.value = false;

  void minimize() {
    if (options.miniPlayer) minimized.value = true;
  }

  void restore() => minimized.value = false;

  /// What `DwMiniPlayerHost`'s close control calls —
  /// `options.miniPlayerCloseStopsPlayback` decides whether that stops the
  /// session outright or only pauses and hides it.
  Future<void> closeFromMiniPlayer() async {
    if (options.miniPlayerCloseStopsPlayback) {
      await dispose();
    } else {
      await pause();
      minimized.value = false;
      _manager.forget(this);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _previewTimer?.cancel();
    await _controller?.dispose();
    _manager.onSessionDisposed(this);
    queue.dispose();
    isFullscreen.dispose();
    minimized.dispose();
  }
}
