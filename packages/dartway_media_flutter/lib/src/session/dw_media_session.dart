part of 'dw_media_session_manager.dart';

/// One `DwMedia.open()`: a queue, the controller of its current item, and
/// whether it is fullscreen or minimized. **Owned by the plugin, not by a
/// widget**: pages come and go, the mini-player takes over, and the session
/// plays on untouched. It ends with [dispose] — or with the mini-player's
/// close, under `DwMediaConfig.miniPlayerCloseStopsPlayback`.
///
/// A controls widget reads [playback] (the current item's state, following
/// the queue), [queue], [isFullscreen] and [minimized], and calls the
/// commands below; [options] carries the knobs it shows (`speeds`,
/// `controlsAutoHideDelay`).
final class DwMediaSession {
  DwMediaSession._({
    required List<DwMediaItem> items,
    required int startIndex,
    required DwMediaCallbacks callbacks,
    required this.options,
    required DwMediaSessionManager manager,
  }) : _callbacks = callbacks,
       _manager = manager,
       _speed = options.defaultSpeed,
       queue = ValueNotifier(
         DwMediaQueueState(items: items, currentIndex: startIndex),
       ) {
    _open(autoplay: options.autoplayOnOpen);
  }

  /// The resolved settings: the plugin's `DwMediaConfig` with this open's
  /// `DwMediaOpenOptions` laid over it.
  final DwMediaConfig options;

  final DwMediaCallbacks _callbacks;
  final DwMediaSessionManager _manager;

  final ValueNotifier<DwMediaQueueState> queue;
  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);

  /// Shown by `DwMiniPlayerHost` while `true`. The app's navigation sets it:
  /// [minimize] when the person leaves the player page, [restore] when they
  /// come back.
  final ValueNotifier<bool> minimized = ValueNotifier(false);

  final ValueNotifier<DwMediaPlaybackState> _playback = ValueNotifier(
    const DwMediaPlaybackState(),
  );
  final ValueNotifier<VideoPlayerController?> _videoView = ValueNotifier(null);

  late DwMediaController _controller;
  double _speed;
  bool _reachedEnd = false;
  bool _autoplayHandled = false;
  Timer? _countdown;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// The controller of the current item. It changes when the queue moves —
  /// a widget that must follow the queue reads [playback] instead.
  DwMediaController get controller => _controller;

  DwMediaItem get currentItem => queue.value.current;

  /// The current item's playback state, following the queue from item to
  /// item — what a controls widget listens to.
  ValueListenable<DwMediaPlaybackState> get playback => _playback;

  /// The `video_player` controller of the current item once it can be
  /// drawn, `null` for audio, while loading and after [dispose] — what
  /// `DwVideoSurface` renders.
  ValueListenable<VideoPlayerController?> get videoView => _videoView;

  // --- The current item ------------------------------------------------------

  void _open({required bool autoplay}) {
    final item = queue.value.current;
    _reachedEnd = false;
    _autoplayHandled = false;
    final controller = createDwMediaController(
      item: item,
      callbacks: DwMediaCallbacks(
        onStarted: _callbacks.onStarted,
        onProgress: _callbacks.onProgress,
        onReachedEnd: (item) {
          _reachedEnd = true;
          _callbacks.onReachedEnd?.call(item);
          _maybeAutoplay();
        },
        onCompleted: _callbacks.onCompleted,
        onError: _callbacks.onError,
      ),
      options: options,
      initialSpeed: _speed,
      initialMuted: _initialMuted(item),
    );
    _controller = controller;
    controller.state.addListener(_onPlayback);
    if (controller is DwVideoMediaController) {
      controller.videoController.addListener(_onVideoView);
    }
    _onPlayback();
    _onVideoView();
    if (autoplay) unawaited(play());
  }

  bool? _initialMuted(DwMediaItem item) {
    final remembered = options.rememberSound ? _manager._rememberedMuted : null;
    if (remembered != null) return remembered;
    if (dwMediaIsWeb &&
        options.webMutedStart &&
        item.kind == DwMediaKind.video) {
      return true;
    }
    return null;
  }

  void _detach(DwMediaController controller) {
    controller.state.removeListener(_onPlayback);
    if (controller is DwVideoMediaController) {
      controller.videoController.removeListener(_onVideoView);
    }
  }

  void _onVideoView() {
    final controller = _controller;
    _videoView.value = controller is DwVideoMediaController
        ? controller.videoController.value
        : null;
  }

  void _onPlayback() {
    final next = _controller.state.value;
    _playback.value = next;
    if (!next.isEnded) _autoplayHandled = false;
    _maybeAutoplay();
    _updatePreview(next);
  }

  void _updatePreview(DwMediaPlaybackState playback) {
    final current = queue.value;
    final remaining = playback.duration - playback.position;
    final show =
        _countdown != null ||
        (options.nextPreview &&
            current.hasNext &&
            playback.duration > Duration.zero &&
            remaining <= options.nextPreviewLeadTime);
    if (show != current.showNextPreview) {
      queue.value = current.copyWith(showNextPreview: show);
    }
  }

  // --- Autoplay ------------------------------------------------------------

  /// Once per ending: the item has really played to its end (the
  /// controller's `onReachedEnd`, which may come a tick before or after the
  /// state turns ended) and now stands ended.
  void _maybeAutoplay() {
    if (_autoplayHandled || !_reachedEnd || !_playback.value.isEnded) return;
    _autoplayHandled = true;
    if (!options.autoplayNext || !queue.value.hasNext) return;
    if (!options.autoplayCountdown ||
        options.autoplayCountdownDuration <= Duration.zero) {
      unawaited(next());
      return;
    }
    var left = options.autoplayCountdownDuration;
    queue.value = queue.value.copyWith(
      showNextPreview: true,
      autoplayCountdown: () => left,
    );
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      left -= const Duration(seconds: 1);
      if (left > Duration.zero) {
        queue.value = queue.value.copyWith(autoplayCountdown: () => left);
        return;
      }
      _countdown = null;
      timer.cancel();
      unawaited(next());
    });
  }

  /// Stops a running autoplay countdown; the queue stays on this item.
  void cancelAutoplay() {
    if (_countdown == null) return;
    _countdown?.cancel();
    _countdown = null;
    queue.value = queue.value.copyWith(autoplayCountdown: () => null);
    _updatePreview(_playback.value);
  }

  // --- Commands --------------------------------------------------------------

  /// Plays the current item. Pauses every other session first under
  /// `singleActiveItem`, and goes fullscreen under
  /// `autoEnterFullscreenOnPlay`.
  Future<void> play() async {
    if (_disposed) return;
    cancelAutoplay();
    _manager._claim(this);
    if (options.autoEnterFullscreenOnPlay &&
        currentItem.kind == DwMediaKind.video) {
      enterFullscreen();
    }
    await _controller.play();
  }

  Future<void> pause() async {
    if (_disposed) return;
    await _controller.pause();
  }

  Future<void> seek(Duration position) async {
    if (_disposed) return;
    cancelAutoplay();
    await _controller.seek(position);
  }

  Future<void> skipBack() => seek(_playback.value.position - options.skipBack);

  Future<void> skipForward() =>
      seek(_playback.value.position + options.skipForward);

  /// Sets the speed of the current item — and of the items after it, under
  /// `rememberSpeedAcrossItems`.
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    if (options.rememberSpeedAcrossItems) _speed = speed;
    await _controller.setSpeed(speed);
  }

  /// Mutes or unmutes — and, under `rememberSound`, every item opened after
  /// this, in any session.
  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    if (options.rememberSound) _manager._rememberedMuted = muted;
    await _controller.setMuted(muted);
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    await _controller.setVolume(volume);
  }

  Future<void> retry() async {
    if (_disposed) return;
    await _controller.retry();
  }

  // --- Queue ---------------------------------------------------------------

  Future<void> next({bool autoplay = true}) async {
    if (_disposed || !queue.value.hasNext) return;
    await _moveTo(queue.value.currentIndex + 1, autoplay: autoplay);
  }

  Future<void> previous({bool autoplay = true}) async {
    if (_disposed || !queue.value.hasPrevious) return;
    await _moveTo(queue.value.currentIndex - 1, autoplay: autoplay);
  }

  Future<void> jumpTo(int index, {bool autoplay = true}) async {
    if (_disposed || index < 0 || index >= queue.value.items.length) return;
    await _moveTo(index, autoplay: autoplay);
  }

  Future<void> _moveTo(int index, {required bool autoplay}) async {
    cancelAutoplay();
    final old = _controller;
    _detach(old);
    queue.value = queue.value.copyWith(
      currentIndex: index,
      showNextPreview: false,
      autoplayCountdown: () => null,
    );
    if (isFullscreen.value && !options.keepFullscreenAcrossItems) {
      isFullscreen.value = false;
    }
    _open(autoplay: autoplay);
    _callbacks.onItemChanged?.call(currentItem);
    unawaited(_disposeAfterFrame(old));
  }

  /// The old item's video view leaves the tree on the next frame; its engine
  /// goes after that — on the web, disposing a video whose element is still
  /// on the page throws in the browser.
  static Future<void> _disposeAfterFrame(DwMediaController controller) async {
    await SchedulerBinding.instance.endOfFrame;
    await controller.dispose();
  }

  // --- Fullscreen and the mini-player --------------------------------------

  /// Goes fullscreen — `DwMediaFullscreenHost` pushes the route. Does
  /// nothing with `DwMediaConfig.fullscreen` off.
  void enterFullscreen() {
    if (!_disposed && options.fullscreen) isFullscreen.value = true;
  }

  void exitFullscreen() {
    if (!_disposed) isFullscreen.value = false;
  }

  /// Hands the session to `DwMiniPlayerHost`. Does nothing with
  /// `DwMediaConfig.miniPlayer` off. Safe to call from a page's
  /// `State.dispose`, where the change waits for the end of the frame.
  void minimize() {
    if (options.miniPlayer) _setMinimized(true);
  }

  /// Takes the session back from the mini-player — the player page coming
  /// back. Safe from `initState` and `dispose` alike.
  void restore() => _setMinimized(false);

  void _setMinimized(bool value) {
    if (_disposed) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (!_disposed) minimized.value = value;
      });
      return;
    }
    minimized.value = value;
  }

  /// The mini-player's close: ends the session under
  /// `miniPlayerCloseStopsPlayback`, otherwise pauses and hides it.
  Future<void> closeFromMiniPlayer() async {
    if (_disposed) return;
    if (options.miniPlayerCloseStopsPlayback) {
      await dispose();
      return;
    }
    minimized.value = false;
    _manager._release(this);
    await pause();
  }

  /// Ends the session: saves under `saveOnDispose`, drops the video view,
  /// and releases the engine after the next frame.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _countdown?.cancel();
    _countdown = null;
    final controller = _controller;
    _detach(controller);
    _videoView.value = null;
    isFullscreen.value = false;
    minimized.value = false;
    _manager._remove(this);
    unawaited(_disposeAfterFrame(controller));
  }
}
