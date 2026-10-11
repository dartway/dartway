import '../model/dw_media_playback_state.dart';
import '../observation/dw_media_played_interval.dart';

sealed class MediaEvent {
  const MediaEvent();
}

final class PlayCommand extends MediaEvent {
  const PlayCommand();
}

final class PauseCommand extends MediaEvent {
  const PauseCommand();
}

final class PlayRefused extends MediaEvent {
  const PlayRefused();
}

final class SeekCommand extends MediaEvent {
  const SeekCommand(this.target);
  final Duration target;
}

final class SeekSettled extends MediaEvent {
  const SeekSettled(this.target);
  final Duration target;
}

final class SeekAborted extends MediaEvent {
  const SeekAborted(this.target);
  final Duration target;
}

final class LoadCommand extends MediaEvent {
  const LoadCommand();
}

final class FailureFact extends MediaEvent {
  const FailureFact(this.message);
  final String message;
}

final class SettingsCommand extends MediaEvent {
  const SettingsCommand({this.speed, this.volume, this.muted});
  final double? speed;
  final double? volume;
  final bool? muted;
}

final class EngineFact extends MediaEvent {
  const EngineFact({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.playing,
    this.loading = false,
    this.buffering = false,
    this.ended = false,
    this.seekEpoch = 0,
  });
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool playing;
  final bool loading;
  final bool buffering;
  final bool ended;
  final int seekEpoch;
}

/// Pure state and evidence: engine adapters never choose UI state.
final class MediaPlayerState {
  const MediaPlayerState({
    this.playback = const DwMediaPlaybackState(),
    this.anchor = Duration.zero,
    this.playedSinceSeek = false,
    this.hasReallyPlayed = false,
    this.playConfirmed = false,
    this.interval,
    this.sealPlayback = false,
    this.seekEpoch = 0,
    this.needsEngineAnchor = false,
  });
  final DwMediaPlaybackState playback;
  final Duration anchor;
  final bool playedSinceSeek;
  final bool hasReallyPlayed;
  final bool playConfirmed;

  /// Evidence earned by this event only, never by a command or stale seek tick.
  final DwMediaPlayedInterval? interval;

  /// This event closes the current report window after its evidence is recorded.
  final bool sealPlayback;
  final int seekEpoch;
  final bool needsEngineAnchor;
}

const mediaSeekTolerance = Duration(milliseconds: 200);

MediaPlayerState reduceMedia(MediaPlayerState state, MediaEvent event) {
  var next = state.playback;
  var anchor = state.anchor;
  var played = state.playedSinceSeek;
  var ever = state.hasReallyPlayed;
  var confirmed = state.playConfirmed;
  DwMediaPlayedInterval? interval;
  var seal = false;
  var seekEpoch = state.seekEpoch;
  var needsEngineAnchor = state.needsEngineAnchor;
  DwMediaPlayState resting() =>
      ever ? DwMediaPlayState.paused : DwMediaPlayState.ready;
  switch (event) {
    case PlayCommand():
      if (next.intent == DwMediaPlayIntent.play && !next.isEnded) break;
      confirmed = false;
      if (next.isEnded) {
        anchor = Duration.zero;
        played = false;
        next = next.copyWith(
          position: Duration.zero,
          seekTarget: Duration.zero,
        );
      } else {
        anchor = next.position;
      }
      next = next.copyWith(
        intent: DwMediaPlayIntent.play,
        waiting: !next.isError,
        playState: next.isError
            ? DwMediaPlayState.error
            : next.playState == DwMediaPlayState.loading
            ? DwMediaPlayState.loading
            : DwMediaPlayState.playing,
      );
    case PauseCommand() || PlayRefused():
      seal = true;
      confirmed = false;
      anchor = next.position;
      next = next.copyWith(
        intent: DwMediaPlayIntent.pause,
        waiting: false,
        playState:
            next.isEnded ||
                next.isError ||
                next.playState == DwMediaPlayState.loading
            ? next.playState
            : resting(),
      );
    case SeekCommand(:final target):
      if (next.isError) break;
      seal = true;
      var clamped = target < Duration.zero ? Duration.zero : target;
      if (next.duration > Duration.zero && clamped > next.duration) {
        clamped = next.duration;
      }
      anchor = clamped;
      played = false;
      seekEpoch++;
      needsEngineAnchor = false;
      next = next.copyWith(position: clamped, seekTarget: clamped);
    case SeekSettled(:final target):
      if (next.seekTarget == target && !next.isError) {
        anchor = target;
        final ended = next.duration > Duration.zero && target >= next.duration;
        seal = ended;
        next = next.copyWith(
          position: target,
          seekTarget: null,
          intent: ended ? DwMediaPlayIntent.pause : next.intent,
          waiting: ended ? false : next.waiting,
          playState: ended
              ? DwMediaPlayState.ended
              : next.intent == DwMediaPlayIntent.play
              ? DwMediaPlayState.playing
              : resting(),
        );
      }
    case SeekAborted(:final target):
      if (next.seekTarget == target && !next.isError) {
        next = next.copyWith(seekTarget: null);
        needsEngineAnchor = true;
      }
    case LoadCommand():
      seal = true;
      confirmed = false;
      anchor = next.position;
      played = false;
      next = next.copyWith(
        playState: DwMediaPlayState.loading,
        waiting: next.intent == DwMediaPlayIntent.play,
        seekTarget: null,
        errorMessage: null,
      );
    case FailureFact(:final message):
      seal = true;
      confirmed = false;
      anchor = next.position;
      played = false;
      next = next.copyWith(
        playState: DwMediaPlayState.error,
        waiting: false,
        seekTarget: null,
        errorMessage: message,
      );
    case SettingsCommand(:final speed, :final volume, :final muted):
      if (speed != null && speed != next.speed) {
        anchor = next.position;
        seal = true;
      }
      next = next.copyWith(speed: speed, volume: volume, muted: muted);
    case EngineFact():
      if (next.isError) break;
      if (event.seekEpoch < seekEpoch) break;
      var target = next.seekTarget;
      final seeking = target != null;
      if (target != null &&
          (event.position - target).abs() <= mediaSeekTolerance) {
        // Once arrival is proved, any difference within tolerance is a seek
        // landing, not played coverage.
        anchor = event.position;
        target = null;
      }
      final position = seeking ? next.position : event.position;
      final ended =
          event.ended &&
          target == null &&
          (!seeking || next.position >= event.duration);
      seal = ended && !next.isEnded;
      final real =
          !needsEngineAnchor &&
          !seeking &&
          !event.loading &&
          !event.buffering &&
          !event.ended &&
          event.playing &&
          next.intent == DwMediaPlayIntent.play &&
          position > anchor;
      if (real) {
        interval = DwMediaPlayedInterval(anchor, position);
        anchor = position;
        played = ever = confirmed = true;
      }
      if (needsEngineAnchor) {
        anchor = position;
        needsEngineAnchor = false;
      }
      // Buffering holds the evidence anchor. A stopped engine cannot prove a gap.
      if (!seeking &&
          ((!event.playing && !event.buffering && !ended) ||
              position < anchor)) {
        anchor = position;
      }
      final waiting = seeking && target != null
          ? next.waiting
          : next.intent == DwMediaPlayIntent.play &&
                !ended &&
                (event.loading ||
                    event.buffering ||
                    !event.playing ||
                    !confirmed);
      next = next.copyWith(
        position: position,
        duration: event.duration,
        buffered: event.buffered,
        seekTarget: target,
        intent: ended ? DwMediaPlayIntent.pause : next.intent,
        waiting: waiting,
        playState: ended
            ? DwMediaPlayState.ended
            : event.loading
            ? DwMediaPlayState.loading
            : next.intent == DwMediaPlayIntent.play
            ? DwMediaPlayState.playing
            : resting(),
      );
  }
  return MediaPlayerState(
    playback: next,
    anchor: anchor,
    playedSinceSeek: played,
    hasReallyPlayed: ever,
    playConfirmed: confirmed,
    interval: interval,
    sealPlayback: seal,
    seekEpoch: seekEpoch,
    needsEngineAnchor: needsEngineAnchor,
  );
}
