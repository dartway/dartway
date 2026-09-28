import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';
import '../platform/dw_media_platform.dart';
import '../resume/dw_media_position_store.dart';
import 'dw_media_controller.dart';

/// Where resume positions live when `DwMediaConfig.positionStore` is `null`:
/// one store for the life of the app, so an item reopened by another session
/// resumes too.
final DwMediaPositionStore _inMemoryPositionStore =
    DwMediaInMemoryPositionStore();

/// What both engines share: the state, the callbacks and their guards, the
/// resume policy, retries. A subclass implements only the `engine*` calls and
/// reports what its engine says through [updateState] and [reportFailure].
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
  }) : _callbacks = callbacks,
       _onPlaybackEnd = onPlaybackEnd,
       _speed = initialSpeed ?? options.defaultSpeed,
       _muted = initialMuted,
       _autoRetriesLeft = options.autoRetryCount {
    unawaited(_load());
  }

  @override
  final DwMediaItem item;

  /// The resolved settings this controller runs on.
  DwMediaConfig options;

  @override
  void adoptOptions(DwMediaConfig next) => options = next;

  final DwMediaCallbacks _callbacks;
  final VoidCallback? _onPlaybackEnd;

  final ValueNotifier<DwMediaPlaybackState> _state = ValueNotifier(
    const DwMediaPlaybackState(),
  );

  @override
  ValueListenable<DwMediaPlaybackState> get state => _state;

  double _speed;
  bool? _muted;
  double _volumeBeforeMute = 1;

  int _seeksInFlight = 0;
  Duration? _anchor;
  bool _playedSinceSeek = false;
  bool _everPlayed = false;
  bool _startedFired = false;
  bool _completedFired = false;
  bool _reachedEndFired = false;
  bool _endedByPlayback = false;
  DateTime? _lastProgressAt;
  DateTime? _lastSaveAt;

  bool _loaded = false;
  bool _playWhenLoaded = false;
  bool _failed = false;
  Future<void>? _reloading;

  int _autoRetriesLeft;
  Timer? _autoRetryTimer;
  int _loadGeneration = 0;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  bool get wantsToPlay => _playWhenLoaded;

  @override
  bool get endedByPlayback => _endedByPlayback;

  DwMediaPositionStore get _store =>
      options.positionStore ?? _inMemoryPositionStore;

  // --- Engine seam ---------------------------------------------------------

  /// Loads [uri], replacing whatever was loaded before, and reports the first
  /// state through [updateState]. Throws when the source cannot be opened.
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
    _failed = false;
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
            // on and never joined or applied.
            _loadGeneration++;
            throw TimeoutException('the item did not load', timeout);
          },
        );
      }
      if (stale()) return;
      await engineSetSpeed(_speed);
      final muted = _muted;
      if (muted != null) await _applyVolume(muted ? 0 : _volumeBeforeMute);
      updateState((current) => current.copyWith(speed: _speed));
      if (startAt != null && startAt > Duration.zero) await seek(startAt);
      _anchor ??= _state.value.position;
      _autoRetriesLeft = options.autoRetryCount;
      _loaded = true;
      if (_playWhenLoaded) {
        _playWhenLoaded = false;
        await play();
      }
    } catch (error, stackTrace) {
      if (error is TimeoutException || !stale()) {
        reportFailure(error, stackTrace);
      }
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
      updateState(
        (current) => current.copyWith(playState: DwMediaPlayState.loading),
      );
      return;
    }
    updateState(
      (current) => current.copyWith(
        playState: DwMediaPlayState.error,
        errorMessage: error.toString(),
      ),
    );
    _failed = true;
    _callbacks.onError?.call(item, error);
  }

  /// Loads the item again from where it failed. The error is gone the moment
  /// it starts — the person sees it loading, not the old error — and a second
  /// call while it runs joins the first instead of loading twice.
  Future<void> _reload() {
    final running = _reloading;
    if (running != null) return running;
    final position = _state.value.position;
    _failed = false;
    updateState(
      (current) => current.copyWith(
        playState: DwMediaPlayState.loading,
        errorMessage: null,
      ),
    );
    final reload = _load(
      restoreTo: position > Duration.zero ? position : null,
    ).whenComplete(() => _reloading = null);
    return _reloading = reload;
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

  /// Merges what the engine reports into the state and fires the callbacks
  /// the change earns. An engine reports [DwMediaPlayState.paused] for "not
  /// playing"; before any real playback it reads as
  /// [DwMediaPlayState.ready].
  @protected
  void updateState(
    DwMediaPlaybackState Function(DwMediaPlaybackState current) update,
  ) {
    if (_disposed) return;
    final previous = _state.value;
    var next = update(previous);
    // A failed engine keeps talking — an idle player, a reset value — and
    // none of it may cover the error until a retry loads again.
    if (_failed) next = next.copyWith(playState: DwMediaPlayState.error);
    if (next.playState == DwMediaPlayState.paused && !_everPlayed) {
      next = next.copyWith(playState: DwMediaPlayState.ready);
    }
    _state.value = next;
    _afterUpdate(previous, next);
  }

  void _afterUpdate(DwMediaPlaybackState previous, DwMediaPlaybackState next) {
    final seeking = _seeksInFlight > 0;
    if (next.isPlaying && !previous.isPlaying && !seeking) {
      _anchor = next.position;
    }
    final anchor = _anchor;
    final realTick =
        next.isPlaying && !seeking && anchor != null && next.position > anchor;
    if (realTick) _onRealPlayback(next);
    if (next.isEnded && !previous.isEnded && !seeking && _playedSinceSeek) {
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
    _playedSinceSeek = true;
    _everPlayed = true;
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

  /// Before the item has loaded, remembers the intent and plays once it
  /// has — what `DwMediaConfig.autoplayOnOpen` relies on.
  @override
  Future<void> play() async {
    if (_disposed) return;
    if (!_loaded) {
      _playWhenLoaded = true;
      return;
    }
    try {
      await enginePlay();
    } catch (error, stackTrace) {
      if (dwMediaIsPlayRefusal(error)) {
        await _quietly(enginePause);
        return;
      }
      reportFailure(error, stackTrace);
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _playWhenLoaded = false;
    await _quietly(enginePause);
    if (options.resume?.saveOnPause ?? false) await savePosition();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    final duration = _state.value.duration;
    var target = position < Duration.zero ? Duration.zero : position;
    if (duration > Duration.zero && target > duration) target = duration;
    _seeksInFlight++;
    _playedSinceSeek = false;
    _endedByPlayback = false;
    try {
      await _quietly(() => engineSeek(target));
    } finally {
      _seeksInFlight--;
    }
    _anchor = target;
  }

  @override
  Future<void> skip(Duration offset) => seek(_state.value.position + offset);

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    _speed = speed;
    await _quietly(() => engineSetSpeed(speed));
    updateState((current) => current.copyWith(speed: speed));
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
    updateState(
      (current) => current.copyWith(volume: volume, muted: volume == 0),
    );
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
