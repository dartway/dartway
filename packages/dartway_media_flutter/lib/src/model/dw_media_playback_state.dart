import 'package:flutter/foundation.dart';

/// Where an item is in its playback.
enum DwMediaPlayState {
  /// The source is being resolved and the engine is preparing it, or a
  /// failed load waits for its automatic retry.
  loading,

  /// Loaded, and nothing has really played yet.
  ready,

  /// Playing but waiting on data.
  buffering,

  playing,
  paused,

  /// The engine stands at the end — by playback or by a seek. Whether it
  /// was real playback is `DwMediaCallbacks.onReachedEnd`'s question.
  ended,

  /// Failed; the controller waits for `retry()`.
  error,
}

/// A snapshot of one item's playback — what a controls widget reads to draw
/// itself (`DwMediaSession.playback`).
@immutable
final class DwMediaPlaybackState {
  const DwMediaPlaybackState({
    this.playState = DwMediaPlayState.loading,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.muted = false,
    this.errorMessage,
  });

  final DwMediaPlayState playState;
  final Duration position;
  final Duration duration;

  /// How far the engine has buffered, as an absolute position — `0` until an
  /// engine reports one.
  final Duration buffered;

  final double speed;
  final double volume;
  final bool muted;

  /// The failure, while [playState] is [DwMediaPlayState.error] — for a log;
  /// what the person sees is the app's own text.
  final String? errorMessage;

  bool get isPlaying => playState == DwMediaPlayState.playing;
  bool get isBuffering => playState == DwMediaPlayState.buffering;
  bool get isError => playState == DwMediaPlayState.error;
  bool get isEnded => playState == DwMediaPlayState.ended;

  /// `position / duration`, or `0` while the duration is unknown.
  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0, 1);

  DwMediaPlaybackState copyWith({
    DwMediaPlayState? playState,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? speed,
    double? volume,
    bool? muted,
    Object? errorMessage = _unset,
  }) => DwMediaPlaybackState(
    playState: playState ?? this.playState,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  @override
  String toString() => 'DwMediaPlaybackState($playState, $position/$duration)';
}

const Object _unset = Object();
