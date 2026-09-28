import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';
import '../resume/dw_media_position_store.dart';
import 'dw_media_controller.dart';

/// Resume falls back to this shared in-memory store whenever
/// `DwMediaConfig.positionStore` is left `null` — "in-memory default" holds
/// even for a project that never wires a store, and one instance is shared so
/// a position saved for an item is read back for it regardless of which
/// session opened it.
final DwMediaPositionStore dwMediaFallbackPositionStore =
    DwMediaInMemoryPositionStore();

/// Shared machinery over both engines: the state notifier, callback firing
/// (throttled progress, the reached-end guard, the completed threshold),
/// retry-via-resolve with `options.autoRetryCount`, and the resume policy. A
/// subclass wires exactly the engine-specific calls in the `engine*` methods
/// below.
///
/// Every behaviour here reads from [options] — a resolved [DwMediaConfig] —
/// rather than a fixed constant, so a project turns each one off or tunes it
/// without touching this class.
abstract class DwMediaEngineController extends DwMediaController {
  DwMediaEngineController({
    required this.item,
    required DwMediaCallbacks callbacks,
    required DwMediaConfig options,
    double? initialSpeed,
    bool? initialMuted,
  }) : _callbacks = callbacks,
       _options = options,
       _initialSpeed = initialSpeed ?? options.defaultSpeed,
       _initialMuted = initialMuted {
    _autoRetriesLeft = options.autoRetryCount;
    unawaited(_start());
  }

  @override
  final DwMediaItem item;

  final DwMediaCallbacks _callbacks;
  final DwMediaConfig _options;
  final double _initialSpeed;
  final bool? _initialMuted;

  final ValueNotifier<DwMediaPlaybackState> _stateNotifier = ValueNotifier(
    const DwMediaPlaybackState(),
  );

  @override
  ValueListenable<DwMediaPlaybackState> get state => _stateNotifier;

  /// The resolved settings this controller was opened with — read by a
  /// controls widget that wants a knob (`speeds`, `controlsAutoHideDelay`)
  /// without going back to `dw.plugins.media`.
  DwMediaConfig get options => _options;

  bool _seeking = false;
  bool _startedFired = false;
  bool _completedFired = false;
  bool _reachedEndFired = false;
  DateTime? _lastProgressAt;
  Timer? _resumeTimer;
  Timer? _autoRetryTimer;
  int _autoRetriesLeft = 0;
  bool _disposed = false;
  double _volumeBeforeMute = 1;

  // --- Engine seam ---------------------------------------------------------

  /// Loads [uri] into the underlying engine and reports the first state
  /// through [updateState] — called once at construction and again on
  /// [retry].
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

  // --- Shared behaviour ------------------------------------------------

  Future<void> _start() async {
    try {
      final resumePolicy = _options.resume;
      final store = _options.positionStore ?? dwMediaFallbackPositionStore;
      final resumeFrom = resumePolicy == null ? null : await store.read(item.id);
      final uri = await item.source.resolve();
      if (_disposed) return;
      await engineLoad(uri);
      if (_disposed) return;
      await engineSetSpeed(_initialSpeed);
      updateState((current) => current.copyWith(speed: _initialSpeed));
      if (_initialMuted != null) await setMuted(_initialMuted);
      if (resumeFrom != null && resumeFrom > Duration.zero) {
        await engineSeek(resumeFrom);
      }
      _autoRetriesLeft = _options.autoRetryCount;
      _resumeTimer?.cancel();
      final interval = resumePolicy?.saveInterval;
      if (interval != null) {
        _resumeTimer = Timer.periodic(
          interval,
          (_) => _maybeSavePosition(_stateNotifier.value),
        );
      }
    } catch (error, stackTrace) {
      _handleLoadFailure(error, stackTrace);
    }
  }

  void _handleLoadFailure(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    if (_autoRetriesLeft > 0) {
      _autoRetriesLeft--;
      _autoRetryTimer?.cancel();
      _autoRetryTimer = Timer(_options.autoRetryDelay, () {
        if (!_disposed) unawaited(_start());
      });
      return;
    }
    handleError(error, stackTrace);
  }

  /// Merges [update] into the current state, reports it, and fires whichever
  /// callbacks that transition earns.
  @protected
  void updateState(
    DwMediaPlaybackState Function(DwMediaPlaybackState current) update,
  ) {
    if (_disposed) return;
    final next = update(_stateNotifier.value);
    _stateNotifier.value = next;
    _afterStateUpdate(next);
  }

  void _afterStateUpdate(DwMediaPlaybackState next) {
    if (next.playState == DwMediaPlayState.playing) {
      if (!_startedFired) {
        _startedFired = true;
        _callbacks.onStarted?.call(item);
      }
      final now = clock.now();
      if (_lastProgressAt == null ||
          now.difference(_lastProgressAt!) >= _options.progressInterval) {
        _lastProgressAt = now;
        _callbacks.onProgress?.call(item, next.position, next.duration);
      }
      _checkReachedEndByTolerance(next);
    }
    if (!_completedFired &&
        next.duration > Duration.zero &&
        next.position.inMicroseconds >=
            next.duration.inMicroseconds * _options.completedThreshold) {
      _completedFired = true;
      _callbacks.onCompleted?.call(item);
    }
    _maybeSavePosition(next);
  }

  /// The [DwMediaConfig.reachedEndTolerance] safety net: real, still-playing
  /// ticks that land within tolerance of the duration also count, on top of
  /// each engine's own end-of-playback event. Guarded by [_seeking] exactly
  /// like [markReachedEnd], so a scrub landing inside the tolerance window
  /// still does not count — only continued playback afterwards does.
  void _checkReachedEndByTolerance(DwMediaPlaybackState next) {
    if (_seeking || _reachedEndFired) return;
    final tolerance = _options.reachedEndTolerance;
    if (tolerance <= Duration.zero || next.duration <= Duration.zero) return;
    if (next.duration - next.position <= tolerance) markReachedEnd();
  }

  /// Called by a subclass when the engine reports **real playback** reaching
  /// the end. Never derive this from `position == duration`: both engines
  /// reach that state on a plain seek to the end too (see the two engine
  /// controllers' docs). Suppressed while a [seek]/[skip] call from this
  /// controller is in flight, and fires at most once per controller.
  @protected
  void markReachedEnd() {
    if (_seeking || _reachedEndFired) return;
    _reachedEndFired = true;
    _callbacks.onReachedEnd?.call(item);
  }

  @protected
  void handleError(Object error, [StackTrace? stackTrace]) {
    if (_disposed) return;
    updateState(
      (current) => current.copyWith(
        playState: DwMediaPlayState.error,
        errorMessage: error.toString(),
      ),
    );
    _callbacks.onError?.call(item, error);
  }

  @protected
  Future<T> guardedSeek<T>(Future<T> Function() action) async {
    _seeking = true;
    try {
      return await action();
    } finally {
      _seeking = false;
    }
  }

  void _maybeSavePosition(DwMediaPlaybackState state) {
    final policy = _options.resume;
    if (policy == null || state.duration <= Duration.zero) return;
    final store = _options.positionStore ?? dwMediaFallbackPositionStore;
    final fraction =
        state.position.inMicroseconds / state.duration.inMicroseconds;
    if (fraction >= policy.clearPastFraction) {
      unawaited(store.clear(item.id));
      return;
    }
    if (state.position < policy.minimum) return;
    unawaited(store.write(item.id, state.position));
  }

  @protected
  Future<void> savePositionNow() async {
    final policy = _options.resume;
    if (policy == null || !policy.saveOnLifecycleEvents) return;
    _maybeSavePosition(_stateNotifier.value);
  }

  @override
  Future<void> retry() async {
    _autoRetriesLeft = _options.autoRetryCount;
    updateState(
      (current) => current.copyWith(
        playState: DwMediaPlayState.loading,
        errorMessage: null,
      ),
    );
    await _start();
  }

  @override
  Future<void> play() => enginePlay();

  @override
  Future<void> pause() async {
    await enginePause();
    await savePositionNow();
  }

  @override
  Future<void> seek(Duration position) {
    final duration = _stateNotifier.value.duration;
    var clamped = position;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (duration > Duration.zero && clamped > duration) clamped = duration;
    return guardedSeek(() => engineSeek(clamped));
  }

  @override
  Future<void> skip(Duration offset) =>
      seek(_stateNotifier.value.position + offset);

  @override
  Future<void> setSpeed(double speed) async {
    await engineSetSpeed(speed);
    updateState((current) => current.copyWith(speed: speed));
  }

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await engineSetVolume(clamped);
    if (clamped > 0) _volumeBeforeMute = clamped;
    updateState(
      (current) => current.copyWith(volume: clamped, muted: clamped == 0),
    );
  }

  @override
  Future<void> setMuted(bool muted) {
    if (muted) return setVolume(0);
    return setVolume(_volumeBeforeMute == 0 ? 1 : _volumeBeforeMute);
  }

  @override
  @mustCallSuper
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _resumeTimer?.cancel();
    _autoRetryTimer?.cancel();
    await savePositionNow();
    await engineDispose();
    _stateNotifier.dispose();
  }
}
