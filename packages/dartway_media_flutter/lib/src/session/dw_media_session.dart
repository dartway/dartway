part of 'dw_media_session_manager.dart';

/// One `DwMedia.open()`: a queue, the engine of its current item, and
/// whether it is fullscreen, minimized and showing its controls. **Owned by
/// the plugin, not by a widget**: pages come and go, the mini-player takes
/// over, and the session plays on untouched. Opening the same item again
/// returns it. It ends with [dispose] — or with the mini-player's close,
/// under `DwMediaConfig.miniPlayerCloseStopsPlayback`.
///
/// A controls widget reads [playback] (the current item's state, following
/// the queue), [queue], [isFullscreen], [minimized] and [controlsVisible],
/// and calls the commands below; [options] carries the settings it shows.
final class DwMediaSession {
  DwMediaSession._({
    required List<DwMediaItem> items,
    required int startIndex,
    required DwMediaCallbacks callbacks,
    required DwMediaConfig options,
    required DwMediaSessionManager manager,
    required int sessionId,
  }) : _options = options,
       _callbacks = callbacks,
       _manager = manager,
       _sessionId = sessionId,
       _speed = options.defaultSpeed,
       _queue = ValueNotifier(
         DwMediaQueueState(items: items, currentIndex: startIndex),
       );

  /// The resolved settings: the plugin's `DwMediaConfig` with the latest
  /// `DwMediaOpenOptions` for this session laid over it — an open that
  /// returned this session replaces them (see `DwMediaSessionManager.open`).
  DwMediaConfig get options => _options;
  DwMediaConfig _options;

  DwMediaCallbacks _callbacks;
  final DwMediaSessionManager _manager;
  final int _sessionId;
  int _sourceGeneration = 0;
  int _observationEpoch = 0;
  Object? _observationVisit;
  String? _observationItemId;
  final DwMediaIntervalAccumulator _confirmed = DwMediaIntervalAccumulator();

  /// A token for this item's current source/continuity generation. Acquire a
  /// new one after play/pause/buffer/seek/speed/load boundaries. State only
  /// gates recording: the caller must independently confirm the played span,
  /// including platform discontinuities the default players cannot identify.
  DwMediaObservationHandle get playbackObservation {
    final source = _sourceGeneration;
    final epoch = _observationEpoch;
    final itemId = _observationItemId ?? currentItem.id;
    return DwMediaObservationHandle._(
      sessionId: _sessionId,
      itemId: itemId,
      sourceGeneration: source,
      record: (interval) {
        if (_disposed ||
            source != _sourceGeneration ||
            epoch != _observationEpoch) {
          return DwMediaObservationResult.stale;
        }
        if (_options.playbackDelivery == null)
          return DwMediaObservationResult.disabled;
        if (!_controller.canObservePlayback)
          return DwMediaObservationResult.notPlaying;
        _confirmed.add(interval);
        return DwMediaObservationResult.recorded;
      },
    );
  }

  /// Seals the current confirmed window, starts one handled delivery attempt,
  /// and returns its pending identity; null for an empty window. New
  /// observations accumulate separately. See the manager's pending/error and
  /// retry APIs for acknowledgement/failure. This does not await delivery.
  DwMediaPlaybackReport? flushPlayback() {
    if (_confirmed.isEmpty) return null;
    final delivery = _options.playbackDelivery!;
    final intervals = _confirmed.intervals;
    final report = _manager._sealPlayback(
      sessionId: _sessionId,
      itemId: _observationItemId!,
      sourceGeneration: _sourceGeneration,
      intervals: intervals,
      delivery: delivery,
    );
    _confirmed.clear();
    return report;
  }

  void _breakObservation() => _observationEpoch++;

  void _sourceChanged(String itemId) {
    if (_disposed) return;
    flushPlayback();
    _sourceGeneration++;
    _observationItemId = itemId;
    _breakObservation();
  }

  void _observationEnded() {
    _breakObservation();
    flushPlayback();
  }

  final ValueNotifier<DwMediaQueueState> _queue;
  final ValueNotifier<bool> _fullscreen = ValueNotifier(false);
  final ValueNotifier<bool> _minimized = ValueNotifier(false);
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);
  final ValueNotifier<DwMediaPlaybackState> _playback = ValueNotifier(
    const DwMediaPlaybackState(),
  );
  final ValueNotifier<VideoPlayerController?> _videoView = ValueNotifier(null);

  late DwMediaController _controller;
  double _speed;
  bool _autoplayHandled = false;
  bool _wasPlaying = false;
  Timer? _countdownTick;
  Timer? _countdownEnd;
  Timer? _hideControls;
  int _fullscreenHosts = 0;
  bool _fullscreenRequested = false;
  bool _leftForMiniPlayer = false;
  bool _hidden = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  DwMediaItem get currentItem => _queue.value.current;

  /// The queue: its items, the current one, the next-item preview and the
  /// autoplay countdown.
  ValueListenable<DwMediaQueueState> get queue => _queue;

  /// The current item's playback state, following the queue from item to
  /// item.
  ValueListenable<DwMediaPlaybackState> get playback => _playback;

  /// Whether the session is fullscreen — `DwMediaFullscreenHost` pushes and
  /// pops the route by it.
  ValueListenable<bool> get isFullscreen => _fullscreen;

  /// Whether `DwMiniPlayerHost` shows this session: [minimize] when the
  /// player page goes, [restore] when it comes back.
  ValueListenable<bool> get minimized => _minimized;

  /// Whether the controls should be up: always while the item is not
  /// playing, and for `DwMediaConfig.controlsAutoHideDelay` after it starts
  /// or after [showControls] while it plays.
  ValueListenable<bool> get controlsVisible => _controlsVisible;

  /// The `video_player` controller of the current item once it can be
  /// drawn — what `DwVideoSurface` renders. `null` for audio, while loading
  /// and after [dispose].
  ValueListenable<VideoPlayerController?> get videoView => _videoView;

  // --- The current item ------------------------------------------------------

  void _open({required bool autoplay}) {
    final item = _queue.value.current;
    final visit = Object();
    _observationVisit = visit;
    void currentOnly(void Function() action) {
      if (!_disposed && identical(_observationVisit, visit)) action();
    }

    _autoplayHandled = false;
    final controller = createDwMediaController(
      item: item,
      // Read at the moment of the call, so an open that reuses this session
      // with callbacks of its own replaces them for the playing item too.
      callbacks: DwMediaCallbacks(
        onStarted: (item) => _callbacks.onStarted?.call(item),
        onProgress: (item, position, duration) =>
            _callbacks.onProgress?.call(item, position, duration),
        onReachedEnd: (item) => _callbacks.onReachedEnd?.call(item),
        onCompleted: (item) => _callbacks.onCompleted?.call(item),
        onError: (item, error) => _callbacks.onError?.call(item, error),
      ),
      options: options,
      initialSpeed: _speed,
      initialMuted: _initialMuted(item),
      onPlaybackEnd: _maybeAutoplay,
      onObservationBreak: () => currentOnly(_breakObservation),
      onSourceChange: () => currentOnly(() => _sourceChanged(item.id)),
      onObservationEnd: () => currentOnly(_observationEnded),
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
    if (next.isPlaying != _wasPlaying) {
      _wasPlaying = next.isPlaying;
      next.isPlaying ? showControls() : _holdControls();
    }
    _maybeAutoplay();
    _updatePreview(next);
  }

  void _updatePreview(DwMediaPlaybackState playback) {
    final current = _queue.value;
    final remaining = playback.duration - playback.position;
    final show =
        _countdownEnd != null ||
        (options.nextPreview &&
            current.hasNext &&
            playback.duration > Duration.zero &&
            remaining <= options.nextPreviewLeadTime);
    if (show != current.showNextPreview) {
      _queue.value = current.copyWith(showNextPreview: show);
    }
  }

  // --- Controls --------------------------------------------------------------

  /// Brings the controls up; while the item plays they go again after
  /// `controlsAutoHideDelay`.
  void showControls() {
    if (_disposed) return;
    _controlsVisible.value = true;
    _hideControls?.cancel();
    final delay = options.controlsAutoHideDelay;
    if (!_playback.value.isPlaying || delay <= Duration.zero) return;
    _hideControls = Timer(delay, () {
      if (!_disposed && _playback.value.isPlaying) {
        _controlsVisible.value = false;
      }
    });
  }

  /// Hides the controls now.
  void hideControls() {
    if (_disposed) return;
    _hideControls?.cancel();
    _controlsVisible.value = false;
  }

  /// What a tap on the picture does: shows hidden controls, hides shown ones.
  void toggleControls() =>
      _controlsVisible.value ? hideControls() : showControls();

  void _holdControls() {
    _hideControls?.cancel();
    _controlsVisible.value = true;
  }

  // --- Autoplay ------------------------------------------------------------

  /// Once per ending: the item stands at its end and real playback took it
  /// there. A seek clears that (the engine's `endedByPlayback`), so a
  /// scrub to the end — before or after a real end — never moves the queue.
  void _maybeAutoplay() {
    if (_disposed || _autoplayHandled) return;
    if (!_playback.value.isEnded || !_controller.endedByPlayback) return;
    _autoplayHandled = true;
    if (!options.autoplayNext || !_queue.value.hasNext) return;
    if (_manager._inBackground && _pausesInBackground) return;
    if (!options.autoplayCountdown ||
        options.autoplayCountdownDuration <= Duration.zero) {
      unawaited(next());
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    final total = options.autoplayCountdownDuration;
    final tick = options.autoplayCountdownTick;
    var elapsed = Duration.zero;
    _queue.value = _queue.value.copyWith(
      showNextPreview: true,
      autoplayCountdown: () => total,
    );
    if (tick > Duration.zero) {
      _countdownTick = Timer.periodic(tick, (_) {
        elapsed += tick;
        final left = total - elapsed;
        if (left > Duration.zero) {
          _queue.value = _queue.value.copyWith(autoplayCountdown: () => left);
        }
      });
    }
    _countdownEnd = Timer(total, () {
      _stopCountdown();
      unawaited(next());
    });
  }

  void _stopCountdown() {
    _countdownTick?.cancel();
    _countdownEnd?.cancel();
    _countdownTick = null;
    _countdownEnd = null;
  }

  /// Stops a running autoplay countdown; the queue stays on this item.
  void cancelAutoplay() {
    if (_countdownEnd == null) return;
    _stopCountdown();
    _queue.value = _queue.value.copyWith(autoplayCountdown: () => null);
    _updatePreview(_playback.value);
  }

  // --- Commands --------------------------------------------------------------

  /// Plays the current item. Pauses every other session first under
  /// `singleActiveItem`, and goes fullscreen under
  /// `autoEnterFullscreenOnPlay`. Refused while the app is in the background
  /// and the background rules would pause this item.
  Future<void> play() async {
    if (_disposed) return;
    if (_manager._inBackground && _pausesInBackground) return;
    cancelAutoplay();
    _hidden = false;
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

  /// Seeks the current item; a seek clears any real end, so it never
  /// starts autoplay.
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    cancelAutoplay();
    await _controller.seek(position);
  }

  Future<void> skipBack() => seek(_playback.value.position - options.skipBack);

  Future<void> skipForward() =>
      seek(_playback.value.position + options.skipForward);

  /// Sets the speed of the current item — and of the items after it, under
  /// `rememberSpeedAcrossItems`. Only a speed from `options.speeds` is
  /// accepted: with the list empty the speed control is off.
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    if (!options.speeds.contains(speed)) {
      throw ArgumentError.value(
        speed,
        'speed',
        options.speeds.isEmpty
            ? 'the speed control is off (DwMediaConfig.speeds is empty)'
            : 'not one of DwMediaConfig.speeds ${options.speeds}',
      );
    }
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

  /// Loads the current item again from where it failed, asking its source
  /// anew. A tap while a retry runs joins it.
  Future<void> retry() async {
    if (_disposed) return;
    await _controller.retry();
  }

  // --- Queue ---------------------------------------------------------------

  Future<void> next({bool autoplay = true}) async {
    if (_disposed || !_queue.value.hasNext) return;
    await _moveTo(_queue.value.currentIndex + 1, autoplay: autoplay);
  }

  Future<void> previous({bool autoplay = true}) async {
    if (_disposed || !_queue.value.hasPrevious) return;
    await _moveTo(_queue.value.currentIndex - 1, autoplay: autoplay);
  }

  Future<void> jumpTo(int index, {bool autoplay = true}) async {
    if (_disposed || index < 0 || index >= _queue.value.items.length) return;
    await _moveTo(index, autoplay: autoplay);
  }

  Future<void> _moveTo(int index, {required bool autoplay}) async {
    cancelAutoplay();
    _breakObservation();
    flushPlayback();
    final old = _controller;
    _detach(old);
    _queue.value = _queue.value.copyWith(
      currentIndex: index,
      showNextPreview: false,
      autoplayCountdown: () => null,
    );
    if (_fullscreen.value && !options.keepFullscreenAcrossItems) {
      exitFullscreen();
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

  /// Goes fullscreen through a `DwMediaFullscreenHost` for this session.
  ///
  /// With no host mounted yet — `autoplayOnOpen` playing before the page has
  /// built, a call from the page's own `initState` — the request waits, and
  /// the first host that mounts honours it. From the mini-player (the page
  /// handed the session over with [minimize]) it does nothing: no page will
  /// come to show it, and a flag left up would lie. Does nothing with
  /// `DwMediaConfig.fullscreen` off.
  void enterFullscreen() {
    if (_disposed || !options.fullscreen) return;
    if (_fullscreenHosts > 0) {
      _setLater(_fullscreen, true);
    } else if (!_leftForMiniPlayer && !_hidden) {
      _fullscreenRequested = true;
    }
  }

  /// What a host calls when it mounts: honours a request that waited for it.
  void _hostAttached() {
    _fullscreenHosts++;
    if (!_fullscreenRequested) return;
    _fullscreenRequested = false;
    _setLater(_fullscreen, true);
  }

  /// Leaves fullscreen, and drops a request still waiting for a host. Safe
  /// from a `State.dispose`.
  void exitFullscreen() {
    _fullscreenRequested = false;
    _setLater(_fullscreen, false);
  }

  /// Hands the session to `DwMiniPlayerHost` — what the player page calls
  /// when it goes. With `DwMediaConfig.miniPlayer` off, nothing would show
  /// it, and `onLeaveWithoutMiniPlayer` decides: pause, stop or play on.
  /// Safe from a `State.dispose`.
  void minimize() {
    if (_disposed) return;
    _fullscreenRequested = false;
    if (options.miniPlayer) {
      _leftForMiniPlayer = true;
      _setLater(_minimized, true);
      return;
    }
    switch (options.onLeaveWithoutMiniPlayer) {
      case DwMediaLeaveAction.pause:
        cancelAutoplay();
        unawaited(pause());
      case DwMediaLeaveAction.stop:
        unawaited(dispose());
      case DwMediaLeaveAction.keepPlaying:
        break;
    }
  }

  /// Takes the session back from the mini-player — the player page coming
  /// back. Safe from `initState`.
  void restore() {
    _hidden = false;
    _leftForMiniPlayer = false;
    _setLater(_minimized, false);
  }

  /// Sets [notifier] now, or after the frame when called while the tree is
  /// locked (a `State.dispose`, a build).
  void _setLater(ValueNotifier<bool> notifier, bool value) {
    if (_disposed) return;
    _whenUnlocked(() {
      if (!_disposed) notifier.value = value;
    });
  }

  /// The mini-player's close: ends the session under
  /// `miniPlayerCloseStopsPlayback`, otherwise pauses and hides it — it stays
  /// open, `DwMedia.open()` of its item comes back to it, and opening any
  /// other session ends it, so no hidden engine outlives the next one.
  Future<void> closeFromMiniPlayer() async {
    if (_disposed) return;
    if (options.miniPlayerCloseStopsPlayback) {
      await dispose();
      return;
    }
    _hidden = true;
    _minimized.value = false;
    _manager._release(this);
    cancelAutoplay();
    await pause();
  }

  // --- The app's lifecycle ---------------------------------------------------

  bool get _pausesInBackground => switch (currentItem.kind) {
    DwMediaKind.video => options.pauseVideoInBackground,
    DwMediaKind.audio => !options.backgroundAudio,
  };

  /// The app went to the background: save, and stop whatever would play on
  /// against the settings — playing, buffering, waiting to load to play, or
  /// counting down to the next item.
  void _toBackground() {
    if (_disposed) return;
    _breakObservation();
    if (options.resume?.saveOnBackground ?? false) {
      unawaited(_controller.savePosition());
    }
    if (!_pausesInBackground) return;
    final countingDown = _countdownEnd != null;
    cancelAutoplay();
    final state = _playback.value;
    if (state.isPlaying ||
        state.isBuffering ||
        _controller.wantsToPlay ||
        countingDown) {
      unawaited(pause());
    }
  }

  // --- The end ---------------------------------------------------------------

  /// Ends the session: saves under `saveOnDispose`, drops the video view,
  /// and releases the engine after the next frame.
  ///
  /// Safe from a `State.dispose` — `onLeaveWithoutMiniPlayer: stop` ends the
  /// session exactly there: what its listeners hear is written once the tree
  /// is unlocked.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _breakObservation();
    flushPlayback();
    _fullscreenRequested = false;
    _stopCountdown();
    _hideControls?.cancel();
    final controller = _controller;
    _detach(controller);
    _whenUnlocked(() {
      _videoView.value = null;
      _fullscreen.value = false;
      _minimized.value = false;
    });
    _manager._remove(this);
    unawaited(_disposeAfterFrame(controller));
  }

  // --- Reuse -----------------------------------------------------------------

  /// An open for the item this session stands on: the caller's request wins.
  /// The callbacks and the settings are replaced — the engine takes the
  /// settings that can still apply ([DwMediaController.adoptOptions]); a
  /// different queue replaces this one around the same item, keeping its
  /// engine; and `autoplayOnOpen` plays the item if it is paused or hidden.
  ///
  /// What nobody listens to changes at once, so [options] read in the same
  /// build is already the new one; the engine, the queue and the play that
  /// listeners hear wait until the tree is unlocked.
  void _reopen({
    required List<DwMediaItem> items,
    required int startIndex,
    required DwMediaCallbacks callbacks,
    required DwMediaConfig options,
  }) {
    if (!identical(_options.playbackDelivery, options.playbackDelivery)) {
      flushPlayback();
      _breakObservation();
    }
    _callbacks = callbacks;
    _options = options;
    // Opened again: a page wants it, not only the mini-player.
    _leftForMiniPlayer = false;
    _hidden = false;
    _whenUnlocked(() {
      if (_disposed) return;
      _controller.adoptOptions(options);
      final queue = _queue.value;
      final sameQueue =
          queue.currentIndex == startIndex && listEquals(queue.items, items);
      if (!sameQueue) {
        cancelAutoplay();
        _queue.value = DwMediaQueueState(
          items: items,
          currentIndex: startIndex,
        );
        _updatePreview(_playback.value);
      }
      if (options.autoplayOnOpen && !_playback.value.isPlaying) {
        unawaited(play());
      }
    });
  }
}

/// A recording decision, not a playback or delivery acknowledgement.
enum DwMediaObservationResult { recorded, disabled, stale, notPlaying }

/// An explicit confirmation capability bound to a session/item/source and
/// continuity generation. Invalid spans fail in DwMediaPlayedInterval's
/// constructor even when this handle would reject recording.
final class DwMediaObservationHandle {
  DwMediaObservationHandle._({
    required this.sessionId,
    required this.itemId,
    required this.sourceGeneration,
    required DwMediaObservationResult Function(DwMediaPlayedInterval) record,
  }) : _record = record;
  final int sessionId;
  final String itemId;
  final int sourceGeneration;
  final DwMediaObservationResult Function(DwMediaPlayedInterval) _record;
  DwMediaObservationResult record(DwMediaPlayedInterval confirmed) =>
      _record(confirmed);
}
