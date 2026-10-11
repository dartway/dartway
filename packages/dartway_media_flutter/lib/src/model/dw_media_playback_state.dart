import 'package:flutter/foundation.dart';

/// The person's command, independent of the engine's buffering and optimism.
enum DwMediaPlayIntent { play, pause }

/// Where an item is in its playback. Waiting is a separate flag.
enum DwMediaPlayState { loading, ready, playing, paused, ended, error }

/// The part of playback that controls read; position ticks do not change it.
@immutable
final class DwMediaPlaybackStatus {
  const DwMediaPlaybackStatus({
    this.intent = DwMediaPlayIntent.pause,
    this.waiting = false,
    this.playState = DwMediaPlayState.loading,
    this.errorMessage,
    this.speed = 1,
    this.volume = 1,
    this.muted = false,
  });

  final DwMediaPlayIntent intent;
  final bool waiting;
  final DwMediaPlayState playState;
  final String? errorMessage;
  final double speed;
  final double volume;
  final bool muted;

  bool get isPlaying => playState == DwMediaPlayState.playing;
  bool get isError => playState == DwMediaPlayState.error;
  bool get isEnded => playState == DwMediaPlayState.ended;

  Object get _key =>
      (intent, waiting, playState, errorMessage, speed, volume, muted);
  @override
  bool operator ==(Object other) =>
      other is DwMediaPlaybackStatus && _key == other._key;
  @override
  int get hashCode => _key.hashCode;
}

/// The ticking part of playback, including a seek's displayed target.
@immutable
final class DwMediaPositionState {
  const DwMediaPositionState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.seekTarget,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final Duration? seekTarget;

  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0, 1);

  Object get _key => (position, duration, buffered, seekTarget);
  @override
  bool operator ==(Object other) =>
      other is DwMediaPositionState && _key == other._key;
  @override
  int get hashCode => _key.hashCode;
}

/// The merge of `session.status` and `session.position`.
@immutable
final class DwMediaPlaybackState {
  const DwMediaPlaybackState({
    this.intent = DwMediaPlayIntent.pause,
    this.waiting = false,
    this.playState = DwMediaPlayState.loading,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.seekTarget,
    this.speed = 1.0,
    this.volume = 1.0,
    this.muted = false,
    this.errorMessage,
  });

  final DwMediaPlayIntent intent;
  final bool waiting;
  final DwMediaPlayState playState;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final Duration? seekTarget;
  final double speed;
  final double volume;
  final bool muted;
  final String? errorMessage;

  DwMediaPlaybackStatus get status => DwMediaPlaybackStatus(
    intent: intent,
    waiting: waiting,
    playState: playState,
    errorMessage: errorMessage,
    speed: speed,
    volume: volume,
    muted: muted,
  );
  DwMediaPositionState get positionState => DwMediaPositionState(
    position: position,
    duration: duration,
    buffered: buffered,
    seekTarget: seekTarget,
  );
  bool get isPlaying => playState == DwMediaPlayState.playing;
  bool get isError => playState == DwMediaPlayState.error;
  bool get isEnded => playState == DwMediaPlayState.ended;
  double get progress => positionState.progress;

  DwMediaPlaybackState copyWith({
    DwMediaPlayIntent? intent,
    bool? waiting,
    DwMediaPlayState? playState,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    Object? seekTarget = _unset,
    double? speed,
    double? volume,
    bool? muted,
    Object? errorMessage = _unset,
  }) => DwMediaPlaybackState(
    intent: intent ?? this.intent,
    waiting: waiting ?? this.waiting,
    playState: playState ?? this.playState,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    seekTarget: identical(seekTarget, _unset)
        ? this.seekTarget
        : seekTarget as Duration?,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is DwMediaPlaybackState &&
      status == other.status &&
      positionState == other.positionState;
  @override
  int get hashCode => Object.hash(status, positionState);
  @override
  String toString() =>
      'DwMediaPlaybackState($intent, $playState, $position/$duration)';
}

const Object _unset = Object();
