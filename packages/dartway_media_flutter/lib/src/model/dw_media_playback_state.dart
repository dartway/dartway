import 'package:flutter/foundation.dart';

/// Where a [DwMediaController] is in its lifecycle.
enum DwMediaPlayState {
  /// The source is being resolved and the engine is preparing it — nothing
  /// has played yet.
  loading,

  /// Prepared, not started — used briefly between [loading] and the first
  /// [playing]/[paused], and after a seek settles.
  ready,

  /// Playing but waiting on data.
  buffering,

  playing,
  paused,

  /// Reached the end of real playback (see [DwMediaController.retry] docs on
  /// why this is never derived from position == duration alone).
  ended,

  error;

  bool get isTerminalError => this == DwMediaPlayState.error;
}

/// A snapshot of one [DwMediaController] — what a controls widget reads to
/// draw itself.
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

  /// Set only while [playState] is [DwMediaPlayState.error]; the app decides
  /// what to show, this is the cause for logging.
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
