import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../model/dw_media_playback_state.dart';
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
    super.onObservationEnd,
  });

  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  Future<void> engineLoad(Uri uri) async {
    // The old player goes on its own: a failed `AudioPlayer` may still be
    // tearing its platform down, and the new one does not wait for that.
    unawaited(_release().catchError((Object _) {}));
    final player = AudioPlayer();
    _player = player;
    void onChange(Object? _) => _onUpdate(player);
    _subscriptions.addAll([
      player.playerStateStream.listen(onChange),
      player.positionStream.listen(onChange),
      player.bufferedPositionStream.listen(onChange),
      player.errorStream.listen((error) {
        if (identical(_player, player)) reportFailure(error);
      }),
    ]);
    await player.setUrl(uri.toString());
    _onUpdate(player);
  }

  void _onUpdate(AudioPlayer player) {
    if (!identical(_player, player)) return;
    final playerState = player.playerState;
    updateState(
      (current) => current.copyWith(
        playState: switch (playerState.processingState) {
          ProcessingState.idle ||
          ProcessingState.loading => DwMediaPlayState.loading,
          ProcessingState.buffering => DwMediaPlayState.buffering,
          ProcessingState.ready =>
            playerState.playing
                ? DwMediaPlayState.playing
                : DwMediaPlayState.paused,
          ProcessingState.completed => DwMediaPlayState.ended,
        },
        position: player.position,
        duration: player.duration ?? Duration.zero,
        buffered: player.bufferedPosition,
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
    unawaited(
      player.play().catchError((Object error, StackTrace stackTrace) {
        if (dwMediaIsPlayRefusal(error)) {
          unawaited(player.pause());
        } else {
          reportFailure(error, stackTrace);
        }
      }),
    );
  }

  @override
  Future<void> enginePause() async => _player?.pause();

  @override
  Future<void> engineSeek(Duration position) async => _player?.seek(position);

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
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    await player?.dispose();
  }
}
