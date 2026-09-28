import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../model/dw_media_playback_state.dart';
import 'dw_media_engine_controller.dart';

/// [DwMediaController] over `just_audio`.
///
/// **The trap this guards against:** on Android, `just_audio` can reach
/// `ProcessingState.completed` after a seek performed while paused — a
/// platform quirk, not real playback finishing (`dartway/molodey#128`'s
/// origin). Exactly like [DwVideoMediaController], [markReachedEnd] is never
/// derived from a processing-state check by itself: every seek runs through
/// [guardedSeek], which suppresses the one synchronous update the seek
/// itself causes. A real completion — reached by continued playback, without
/// this controller calling `seek` — still calls it.
final class DwAudioMediaController extends DwMediaEngineController {
  DwAudioMediaController({
    required super.item,
    required super.callbacks,
    required super.options,
    super.initialSpeed,
    super.initialMuted,
  });

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferedSub;

  @override
  Future<void> engineLoad(Uri uri) async {
    final previous = _player;
    _player = null;
    await previous?.dispose();
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _bufferedSub?.cancel();

    final player = AudioPlayer();
    _player = player;
    _stateSub = player.playerStateStream.listen(
      (playerState) => _onUpdate(player, playerState),
      onError: (Object error, StackTrace stackTrace) =>
          handleError(error, stackTrace),
    );
    _positionSub = player.positionStream.listen(
      (_) => _onUpdate(player, player.playerState),
    );
    _bufferedSub = player.bufferedPositionStream.listen(
      (_) => _onUpdate(player, player.playerState),
    );
    await player.setUrl(uri.toString());
    _onUpdate(player, player.playerState);
  }

  void _onUpdate(AudioPlayer player, PlayerState playerState) {
    if (_player != player) return;
    final processing = playerState.processingState;
    if (processing == ProcessingState.completed) markReachedEnd();
    updateState(
      (current) => current.copyWith(
        playState: switch (processing) {
          ProcessingState.idle || ProcessingState.loading =>
            DwMediaPlayState.loading,
          ProcessingState.buffering => DwMediaPlayState.buffering,
          ProcessingState.ready => playerState.playing
              ? DwMediaPlayState.playing
              : DwMediaPlayState.paused,
          ProcessingState.completed => DwMediaPlayState.ended,
        },
        position: player.position,
        duration: player.duration ?? Duration.zero,
        buffered: player.bufferedPosition,
        speed: player.speed,
        volume: player.volume,
        muted: player.volume == 0,
      ),
    );
  }

  @override
  Future<void> enginePlay() async {
    // `AudioPlayer.play()`'s future does not resolve until playback stops
    // again (its own documented behaviour) — awaiting it here would make
    // `DwMediaController.play()` hang until pause or the end of the track.
    unawaited(_player?.play());
  }

  @override
  Future<void> enginePause() async => _player?.pause();

  @override
  Future<void> engineSeek(Duration position) async =>
      _player?.seek(position);

  @override
  Future<void> engineSetSpeed(double speed) async =>
      _player?.setSpeed(speed);

  @override
  Future<void> engineSetVolume(double volume) async =>
      _player?.setVolume(volume);

  @override
  Future<void> engineDispose() async {
    final player = _player;
    _player = null;
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _bufferedSub?.cancel();
    await player?.dispose();
  }
}
