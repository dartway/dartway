import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';
import '../platform/dw_media_platform.dart';
import '../observation/dw_media_played_interval.dart';
import '../resume/dw_media_position_store.dart';
import 'dw_media_controller.dart';
import 'dw_media_reducer.dart';

/// Where resume positions live when `DwMediaConfig.positionStore` is `null`:
/// one store for the life of the app, so an item reopened by another session
/// resumes too.
final DwMediaPositionStore _inMemoryPositionStore =
    DwMediaInMemoryPositionStore();

/// What both engines share: the state, the callbacks and their guards, the
/// resume policy, retries. A subclass implements only the `engine*` calls and
/// reports what its engine says through [reportEngine] and [reportFailure].
///
/// **Real playback, not a position.** Both engines report a seek to the end
/// as "completed": `video_player` sets `isCompleted` on any `seekTo` landing
/// on the duration, and `just_audio` on Android reaches
/// `ProcessingState.completed` after a seek made while paused. And
/// `video_player` reports `isPlaying` the moment `play()` is called, before
/// the platform answers — a web `play()` the browser refuses still reads as
/// playing. So a tick counts as **real playback** only when the engine plays,
/// no seek of this controller is in flight, and the position has moved past
/// where playback started or the last seek landed. `onStarted`, `onProgress`,
/// the periodic resume save and `reachedEndTolerance` read only such ticks,
/// and `onReachedEnd` fires on the engine turning to "ended" only when real
/// playback happened since the last seek. A scrub to the end, a resume point
/// near the end, a completed event arriving late after a paused seek — none
/// of them counts.
abstract class DwMediaEngineController extends DwMediaController {
  DwMediaEngineController({
    required this.item,
    required DwMediaCallbacks callbacks,
    required this.options,
    double? initialSpeed,
    bool? initialMuted,
    VoidCallback? onPlaybackEnd,
    VoidCallback? onObservationBreak,
    VoidCallback? onSourceChange,
    void Function(DwMediaPlayedInterval)? onPlayedInterval,
  }) : _callbacks = callbacks,
       _onPlaybackEnd = onPlaybackEnd,
       _onObservationBreak = onObservationBreak,
       _onSourceChange = onSourceChange,
       _onPlayedInterval = onPlayedInterval,
       _speed = initialSpeed ?? options.defaultSpeed,
       _muted = initialMuted,
       _autoRetriesLeft = options.autoRetryCount {
    unawaited(_track(_load()));
  }

  @override
  final DwMediaItem item;

  /// The resolved settings this controller runs on.
  DwMediaConfig options;

  @override
  void adoptOptions(DwMediaConfig next) => options = next;

  final DwMediaCallbacks _callbacks;
  final VoidCallback? _onPlaybackEnd;
  final VoidCallback? _onObservationBreak;
  final VoidCallback? _onSourceChange;
  final void Function(DwMediaPlayedInterval)? _onPlayedInterval;
  MediaPlayerState _playerState = const MediaPlayerState();

  @override
  bool get hasReallyPlayed => _playerState.hasReallyPlayed;

  final ValueNotifier<DwMediaPlaybackState> _state = ValueNotifier(
    const DwMediaPlaybackState(),
  );

  @override
  ValueListenable<DwMediaPlaybackState> get state => _state;

  double _speed;
  bool? _muted;
  double _volumeBeforeMute = 1;

  Future<void>? _seekRunning;
  Duration? _queuedSeek;
  bool _startedFired = false;
  bool _completedFired = false;
  bool _reachedEndFired = false;
  bool _endedByPlayback = false;
  DateTime? _lastProgressAt;
  DateTime? _lastSaveAt;

  bool _loaded = false;
  bool _failed = false;

  /// The load in flight — the first one or a reload — which a retry joins.
  /// Cleared the moment it settles, a timeout included, so a load that
  /// overran is never joined.
  Future<void>? _reloading;

  Future<void> _track(Future<void> load) {
    late final Future<void> tracked;
    tracked = load.whenComplete(() {
      if (identical(_reloading, tracked)) _reloading = null;
    });
    return _reloading = tracked;
  }

  int _autoRetriesLeft;
  Timer? _autoRetryTimer;
  int _loadGeneration = 0;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  bool get wantsToPlay =>
      !_loaded && _state.value.intent == DwMediaPlayIntent.play;

  @override
  bool get endedByPlayback => _endedByPlayback;

  DwMediaPositionStore get _store =>
      options.positionStore ?? _inMemoryPositionStore;

  // --- Engine seam ---------------------------------------------------------

  /// Loads [uri], replacing whatever was loaded before, and reports the first
  /// state through [reportEngine]. Throws when the source cannot be opened.
  @protected
  Future<void> engineLoad(Uri uri);

  @protected
  Future<void> enginePlay();
  @protected
  Future<void> enginePause();
  @protected
  Future<void> engineSeek(Duration position);
  @protected
  Future<void> engineSetSpeed(double speed);
  @protected
  Future<void> engineSetVolume(double volume);
  @protected
  Future<void> engineDispose();

  // --- Loading and failures --------------------------------------------------

  Future<void> _load({Duration? restoreTo}) async {
    final generation = ++_loadGeneration;
    bool stale() => _disposed || generation != _loadGeneration;
    _loaded = false;
    _seekRunning = null;
    _queuedSeek = null;
    _failed = false;
    _dispatch(const LoadCommand());
    _onSourceChange?.call();
    var overran = false;
    try {
      final policy = options.resume;
      final startAt =
          restoreTo ?? (policy == null ? null : await _store.read(item.id));
      Future<void> open() async {
        final uri = await item.source.resolve();
        if (stale()) return;
        await engineLoad(uri);
      }

      final timeout = options.loadTimeout;
      if (timeout == null) {
        await open();
      } else {
        await open().timeout(
          timeout,
          onTimeout: () {
            // The load that overran may still finish; it is stale from here
            // on and never joined or applied. Only the load still in charge
            // moves the generation — a superseded one must not push a newer
            // load into looking stale.
            if (!stale()) {
              overran = true;
              _loadGeneration++;
            }
            throw TimeoutException('the item did not load', timeout);
          },
        );
      }
      if (stale()) return;
      await engineSetSpeed(_speed);
      final muted = _muted;
      if (muted != null) await _applyVolume(muted ? 0 : _volumeBeforeMute);
      _dispatch(SettingsCommand(speed: _speed));
      _loaded = true;
      if (_queuedSeek != null) {
        await _startSeeks();
      } else if (startAt != null && startAt > Duration.zero) {
        await seek(startAt);
      }
      if (stale() || _failed) return;
      _autoRetriesLeft = options.autoRetryCount;
      if (_state.value.intent == DwMediaPlayIntent.play) await _playEngine();
    } catch (error, stackTrace) {
      if (overran || !stale()) reportFailure(error, stackTrace);
    }
  }

  /// What an engine calls when its source fails, at load or mid-playback.
  /// Retries on its own while `DwMediaConfig.autoRetryCount` allows, then
  /// shows [DwMediaPlayState.error] and calls `onError`.
  @protected
  void reportFailure(Object error, [StackTrace? stackTrace]) {
    if (_disposed || dwMediaIsBenignError(error)) return;
    if (_autoRetriesLeft > 0) {
      _autoRetriesLeft--;
      _autoRetryTimer?.cancel();
      _autoRetryTimer = Timer(options.autoRetryDelay, () {
        if (!_disposed) unawaited(_reload());
      });
      _dispatch(const LoadCommand());
      return;
    }
    _dispatch(FailureFact(error.toString()));
    _failed = true;
    _callbacks.onError?.call(item, error);
  }

  /// Loads the item again from where it failed. The error is gone the moment
  /// it starts — the person sees it loading, not the old error — and a call
  /// while any load runs, the first one included, joins it instead of
  /// loading twice.
  Future<void> _reload() {
    final running = _reloading;
    if (running != null) return running;
    final position = _state.value.position;
    _failed = false;
    return _track(_load(restoreTo: position > Duration.zero ? position : null));
  }

  @override
  Future<void> retry() {
    if (_disposed) return Future.value();
    if (_reloading != null) return _reloading!;
    _autoRetryTimer?.cancel();
    _autoRetriesLeft = options.autoRetryCount;
    return _reload();
  }

  // --- State and callbacks -------------------------------------------------

  /// Engine adapters translate their values into facts; only the reducer
  /// chooses intent, waiting, displayed position and playback evidence.
  @protected
  void reportEngine(EngineFact fact) => _dispatch(fact);

  @protected
  void reportPlayRefused() => _dispatch(const PlayRefused());

  void _dispatch(MediaEvent event) {
    if (_disposed) return;
    final previous = _state.value;
    _playerState = reduceMedia(_playerState, event);
    final next = _playerState.playback;
    final interval = _playerState.interval;
    if (interval != null) _onPlayedInterval?.call(interval);
    // Seal before listeners can move the queue and detach this controller.
    if (_playerState.sealPlayback) _onObservationBreak?.call();
    _state.value = next;
    if (interval != null) _onRealPlayback(next);
    if (next.isEnded && !previous.isEnded && _playerState.playedSinceSeek) {
      _reachEnd();
    }
    if (!next.isEnded && previous.isEnded) _endedByPlayback = false;
    if (!_completedFired &&
        next.duration > Duration.zero &&
        next.position.inMicroseconds >=
            next.duration.inMicroseconds * options.completedThreshold) {
      _completedFired = true;
      _callbacks.onCompleted?.call(item);
    }
  }

  void _onRealPlayback(DwMediaPlaybackState next) {
    if (!_startedFired) {
      _startedFired = true;
      _callbacks.onStarted?.call(item);
    }
    final now = clock.now();
    final lastProgress = _lastProgressAt;
    if (lastProgress == null ||
        now.difference(lastProgress) >= options.progressInterval) {
      _lastProgressAt = now;
      _callbacks.onProgress?.call(item, next.position, next.duration);
    }
    final policy = options.resume;
    final lastSave = _lastSaveAt;
    if (policy != null &&
        (lastSave == null || now.difference(lastSave) >= policy.saveInterval)) {
      _lastSaveAt = now;
      unawaited(_writePosition(next));
    }
    final tolerance = options.reachedEndTolerance;
    if (tolerance > Duration.zero &&
        next.duration > Duration.zero &&
        next.duration - next.position <= tolerance) {
      _reachEnd();
    }
  }

  /// Real playback reached the end: the session hears it every time, the
  /// app's `onReachedEnd` once per item.
  void _reachEnd() {
    if (!_endedByPlayback) {
      _endedByPlayback = true;
      _onPlaybackEnd?.call();
    }
    if (_reachedEndFired) return;
    _reachedEndFired = true;
    _callbacks.onReachedEnd?.call(item);
  }

  // --- Resume --------------------------------------------------------------

  Future<void> _writePosition(DwMediaPlaybackState state) async {
    final policy = options.resume;
    if (policy == null || state.duration <= Duration.zero) return;
    if (state.position.inMicroseconds >=
        state.duration.inMicroseconds * policy.clearPastFraction) {
      await _store.clear(item.id);
      return;
    }
    if (state.position < policy.minimum) return;
    await _store.write(item.id, state.position);
  }

  @override
  Future<void> savePosition() => _writePosition(_state.value);

  // --- Commands --------------------------------------------------------------

  @override
  Future<void> play() async {
    if (_disposed ||
        (_state.value.intent == DwMediaPlayIntent.play &&
            !_state.value.isEnded)) {
      return;
    }
    final restart = _state.value.isEnded;
    _dispatch(const PlayCommand());
    if (!_loaded) return;
    if (restart) await seek(Duration.zero);
    if (_state.value.intent == DwMediaPlayIntent.play) await _playEngine();
  }

  Future<void> _playEngine() async {
    try {
      await enginePlay();
    } catch (error, stackTrace) {
      if (dwMediaIsPlayRefusal(error)) {
        reportPlayRefused();
        await _quietly(enginePause);
        return;
      }
      reportFailure(error, stackTrace);
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _dispatch(const PauseCommand());
    await _quietly(enginePause);
    if (options.resume?.saveOnPause ?? false) await savePosition();
  }

  @override
  Future<void> seek(Duration position) {
    if (_disposed) return Future.value();
    _dispatch(SeekCommand(position));
    _endedByPlayback = false;
    _queuedSeek = _state.value.seekTarget;
    if (!_loaded) return _reloading ?? Future.value();
    return _startSeeks();
  }

  Future<void> _startSeeks() {
    final running = _seekRunning;
    if (running != null) return running;
    final completion = Completer<void>();
    _seekRunning = completion.future;
    unawaited(_drainSeeks(completion, _loadGeneration));
    return completion.future;
  }

  Future<void> _drainSeeks(Completer<void> completion, int generation) async {
    bool stale() => _disposed || generation != _loadGeneration;
    try {
      while (_queuedSeek != null && !stale() && !_failed) {
        final target = _queuedSeek!;
        _queuedSeek = null;
        try {
          await engineSeek(target);
        } catch (error, stackTrace) {
          if (!stale()) reportFailure(error, stackTrace);
        }
        if (stale() || _failed) return;
        _dispatch(SeekSettled(target));
      }
    } finally {
      // Release ownership before completing the callers' future: a seek from
      // their continuation or a state listener must start its own drain.
      if (identical(_seekRunning, completion.future)) _seekRunning = null;
      completion.complete();
    }
  }

  @override
  Future<void> skip(Duration offset) => seek(_state.value.position + offset);

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    if (speed == _state.value.speed) return;
    _speed = speed;
    _dispatch(SettingsCommand(speed: speed));
    await _quietly(() => engineSetSpeed(speed));
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped > 0) _volumeBeforeMute = clamped;
    _muted = clamped == 0;
    await _applyVolume(clamped);
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    _muted = muted;
    await _applyVolume(muted ? 0 : _volumeBeforeMute);
  }

  Future<void> _applyVolume(double volume) async {
    await _quietly(() => engineSetVolume(volume));
    _dispatch(SettingsCommand(volume: volume, muted: volume == 0));
  }

  /// Runs an engine command, reporting a real failure and swallowing a
  /// benign one (see [dwMediaIsBenignError]).
  Future<void> _quietly(Future<void> Function() command) async {
    try {
      await command();
    } catch (error, stackTrace) {
      reportFailure(error, stackTrace);
    }
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    if (_disposed) return;
    if (options.resume?.saveOnDispose ?? false) await savePosition();
    _disposed = true;
    _autoRetryTimer?.cancel();
    try {
      await engineDispose();
    } catch (_) {
      // Nothing is left to report to: the item is gone either way.
    }
    _state.dispose();
  }
}
