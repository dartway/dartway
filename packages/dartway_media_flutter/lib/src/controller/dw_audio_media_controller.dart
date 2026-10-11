import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'dw_media_reducer.dart';
import '../platform/dw_media_platform.dart';
import 'dw_media_engine_controller.dart';

/// [DwMediaController] over `just_audio`.
///
/// A failure after a successful load — the network dropping mid-track —
/// arrives on `AudioPlayer.errorStream` only: the state and event streams
/// swallow the platform's errors, so a player listening to them alone never
/// learns the track died.
final class DwAudioMediaController extends DwMediaEngineController {
  DwAudioMediaController({
    required super.item,
    required super.callbacks,
    required super.options,
    super.initialSpeed,
    super.initialMuted,
    super.onPlaybackEnd,
    super.onObservationBreak,
    super.onSourceChange,
    super.onPlayedInterval,
  });

  AudioPlayer? _player;
  PlaybackEvent? _playbackEvent;
  int? _seekInFlightEpoch;
  DateTime? _seekStartedAt;
  int? _preSeekEpoch;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  Future<void> engineLoad(Uri uri) async {
    // The old player goes on its own: a failed `AudioPlayer` may still be
    // tearing its platform down, and the new one does not wait for that.
    unawaited(_release().catchError((Object _) {}));
    final player = AudioPlayer();
    _player = player;
    _playbackEvent = null;
    void onState(Object? _) => _onUpdate(player, player.position);
    _subscriptions.addAll([
      player.playerStateStream.listen(onState),
      player.playbackEventStream.listen((event) {
        if (!identical(_player, player)) return;
        _playbackEvent = event;
        final beforeSeek = _seekStartedAt case final started?
            ? event.updateTime.isBefore(started)
            : false;
        _onUpdate(
          player,
          event.updatePosition,
          seekEpoch: beforeSeek ? _preSeekEpoch : null,
        );
      }),
      player.positionStream.listen((position) => _onUpdate(player, position)),
      player.errorStream.listen((error) {
        if (identical(_player, player)) reportFailure(error);
      }),
    ]);
    await player.setUrl(uri.toString());
    _onUpdate(player, player.position);
  }

  void _onUpdate(
    AudioPlayer player,
    Duration position, {
    int? seekEpoch,
  }) {
    if (!identical(_player, player)) return;
    final event = _playbackEvent ?? player.playbackEvent;
    final processingState = event.processingState;
    final beforeSeek = _seekStartedAt case final started?
        ? event.updateTime.isBefore(started)
        : false;
    final factSeekEpoch =
        seekEpoch ??
        (beforeSeek ? _preSeekEpoch : null) ??
        _seekInFlightEpoch ??
        engineSeekEpoch;
    reportEngine(
      EngineFact(
        loading:
            processingState == ProcessingState.idle ||
            processingState == ProcessingState.loading,
        buffering: processingState == ProcessingState.buffering,
        ended: processingState == ProcessingState.completed,
        playing:
            player.playing && processingState == ProcessingState.ready,
        position: position,
        duration: event.duration ?? Duration.zero,
        buffered: event.bufferedPosition,
        seekEpoch: factSeekEpoch,
        // just_audio has no positive web playback event: all web coverage is
        // owned by the pending play call and committed only if that call
        // completes. Native players cannot refuse play, so their ticks count
        // immediately.
        provisionalPlayback: dwMediaIsWeb,
      ),
    );
  }

  @override
  Future<void> enginePlay() async {
    // `AudioPlayer.play()` completes only when playback stops again —
    // awaiting it would hold `DwMediaController.play()` until the pause.
    // Its failure — a browser refusing sound without a gesture — is handled
    // here for the same reason.
    final player = _player;
    if (player == null) return;
    final playEpoch = enginePlayEpoch;
    unawaited(
      player.play().then(
        (_) {
          if (dwMediaIsWeb && identical(_player, player)) {
            reportPlayAccepted(playEpoch);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!identical(_player, player)) return;
          if (dwMediaIsPlayRefusal(error)) {
            reportPlayRefused(playEpoch);
            unawaited(player.pause());
          } else if (!dwMediaIsBenignError(error)) {
            reportFailure(error, stackTrace);
          }
        },
      ),
    );
  }

  @override
  Future<void> enginePause() async => _player?.pause();

  @override
  Future<void> engineSeek(Duration position) async {
    final player = _player;
    if (player == null) return;
    final epoch = engineSeekEpoch - 1;
    _seekInFlightEpoch = epoch;
    _preSeekEpoch = epoch;
    _seekStartedAt = DateTime.now();
    try {
      await player.seek(position);
    } finally {
      if (_seekInFlightEpoch == epoch) _seekInFlightEpoch = null;
    }
  }

  @override
  Future<void> engineSetSpeed(double speed) async => _player?.setSpeed(speed);

  @override
  Future<void> engineSetVolume(double volume) async =>
      _player?.setVolume(volume);

  @override
  Future<void> engineDispose() => _release();

  Future<void> _release() async {
    final player = _player;
    _player = null;
    _playbackEvent = null;
    _seekInFlightEpoch = null;
    _seekStartedAt = null;
    _preSeekEpoch = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    await player?.dispose();
  }
}
