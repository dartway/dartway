import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// `JustAudioPlatform.instance = DwFakeJustAudioPlatform()` — drives
/// `DwAudioMediaController` (and, through it, `just_audio`'s own
/// `AudioPlayer`) in a widget test without a plugin registered for any
/// platform.
///
/// Each `AudioPlayer` created while this is the platform gets its own
/// [DwFakeAudioPlayerPlatform], reachable through [players] once the test has
/// pumped past `DwMediaController.forItem`'s construction. [defaultDuration]
/// is what every one of them reports from `load` unless the test overwrites
/// its `duration` field first.
final class DwFakeJustAudioPlatform extends JustAudioPlatform {
  DwFakeJustAudioPlatform({this.defaultDuration = const Duration(minutes: 1)});

  final Duration defaultDuration;

  /// Every player created so far, keyed by the id `just_audio` assigned it —
  /// there is exactly one per `DwAudioMediaController` in normal use.
  final Map<String, DwFakeAudioPlayerPlatform> players = {};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = DwFakeAudioPlayerPlatform(
      request.id,
      duration: defaultDuration,
    );
    players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    final player = players.remove(request.id);
    await player?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }
}

final class DwFakeAudioPlayerPlatform extends AudioPlayerPlatform {
  DwFakeAudioPlayerPlatform(super.id, {required this.duration});

  /// What `load` reports as the track's duration — settable up to the point
  /// the test calls `AudioPlayer.setUrl`.
  Duration? duration;

  // One single-subscription stream per listener, each cancelling with a
  // future of the test's own zone — see `DwFakeVideoPlayerPlatform` on why a
  // broadcast stream would hang `AudioPlayer.dispose` inside `testWidgets`.
  final List<StreamController<PlaybackEventMessage>> _listeners = [];
  Duration _position = Duration.zero;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream {
    late final StreamController<PlaybackEventMessage> controller;
    controller = StreamController<PlaybackEventMessage>(
      onCancel: () {
        _listeners.remove(controller);
        return Future<void>.value();
      },
    );
    _listeners.add(controller);
    return controller.stream;
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _position = request.initialPosition ?? Duration.zero;
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  /// The Android quirk `DwAudioMediaController` is guarded against: seeking
  /// exactly to the duration while paused reaches `completed` on its own,
  /// without `play()` ever being called — `dartway/molodey#128`'s origin.
  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _position = request.position ?? _position;
    final total = duration;
    if (total != null && _position >= total) {
      _emit(ProcessingStateMessage.completed);
    } else {
      _emit(ProcessingStateMessage.ready);
    }
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _emit(ProcessingStateMessage.idle);
    for (final listener in List.of(_listeners)) {
      unawaited(listener.close());
    }
    _listeners.clear();
    return DisposeResponse();
  }

  /// Real playback reaching the end, without a seek — see the class docs.
  void emitCompleted() => _emit(ProcessingStateMessage.completed);

  /// Moves the reported position without seeking — a progress/threshold test
  /// calls this and lets the player's own stream deliver it, the way
  /// [DwFakeVideoPlayerPlatform.setPosition] does for video.
  void emitPosition(Duration position) {
    _position = position;
    _emit(ProcessingStateMessage.ready);
  }

  /// A failure of a track already loaded — the network dropping mid-play.
  void emitError(String message) {
    for (final listener in List.of(_listeners)) {
      listener.addError(
        PlatformException(code: 'dw_fake_audio_error', message: message),
      );
    }
  }

  void _emit(ProcessingStateMessage state) {
    final message = PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: _position,
      bufferedPosition: _position,
      duration: duration,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    );
    for (final listener in List.of(_listeners)) {
      listener.add(message);
    }
  }
}
