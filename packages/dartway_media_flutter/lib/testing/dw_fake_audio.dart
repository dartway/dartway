import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// A stand-in for the `just_audio` platform in a widget test.
///
/// Every track the app opens appears in [tracks] as a [DwFakeAudio]. Inside
/// `testWidgets`, `just_audio` finishes part of its work outside the fake
/// clock: after an audio command, `dwSettleMedia(tester)` rather than `pump`.
base class DwFakeJustAudioPlatform extends JustAudioPlatform {
  /// Also answers the `audio_session` channel `AudioPlayer` asks before it
  /// loads anything — unanswered, that call never completes in a test.
  DwFakeJustAudioPlatform({this.length = const Duration(minutes: 1)}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
  }

  /// Installs a fake as `JustAudioPlatform.instance` and returns it.
  static DwFakeJustAudioPlatform install({
    Duration length = const Duration(minutes: 1),
  }) => JustAudioPlatform.instance = DwFakeJustAudioPlatform(length: length);

  /// How long every track opened from now on is.
  Duration length;

  final List<DwFakeAudio> _opened = [];

  /// Every track opened and not yet released, oldest first.
  List<DwFakeAudio> get tracks => [
    for (final track in _opened)
      if (!track.isReleased) track,
  ];

  /// Every track ever opened, released ones included.
  List<DwFakeAudio> get opened => List.unmodifiable(_opened);

  /// The track opened last.
  DwFakeAudio get latest => _opened.last;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final track = DwFakeAudio._(request.id, length);
    _opened.add(track);
    return track;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    for (final track in _opened) {
      if (track.id == request.id) track._release();
    }
    return DisposePlayerResponse();
  }
}

/// One track opened on a [DwFakeJustAudioPlatform], as the test sees it.
///
/// Seeking to the end of the track reports it completed whether or not it
/// was playing — what Android's player does, and why a seek must never be
/// taken for the end of playback.
final class DwFakeAudio extends AudioPlayerPlatform {
  DwFakeAudio._(super.id, this.length);

  Duration length;

  /// The address loaded last.
  String? uri;

  Duration position = Duration.zero;
  bool _released = false;
  final List<StreamController<PlaybackEventMessage>> _listeners = [];

  bool get isReleased => _released;

  /// Playback has reached [to].
  void advanceTo(Duration to) {
    position = to;
    _report(ProcessingStateMessage.ready);
  }

  /// The platform's own end of playback.
  void finish() {
    position = length;
    _report(ProcessingStateMessage.completed);
  }

  /// The track fails mid-play — reported, as a real platform does, as an
  /// error code on the playback event.
  void fail(String message) =>
      _report(ProcessingStateMessage.idle, errorCode: 1, errorMessage: message);

  /// One stream per listener, each cancelling with a future of the test's
  /// own zone — see [DwFakeVideo] on why not a broadcast stream.
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream {
    late final StreamController<PlaybackEventMessage> listener;
    listener = StreamController(
      onCancel: () {
        _listeners.remove(listener);
        return Future<void>.value();
      },
    );
    _listeners.add(listener);
    return listener.stream;
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    uri = _firstUri(request.audioSourceMessage.toMap()) ?? uri;
    position = request.initialPosition ?? Duration.zero;
    _report(ProcessingStateMessage.ready);
    return LoadResponse(duration: length);
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    position = request.position ?? position;
    _report(
      position >= length
          ? ProcessingStateMessage.completed
          : ProcessingStateMessage.ready,
    );
    return SeekResponse();
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

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _release();
    return DisposeResponse();
  }

  /// The address inside a source message — `just_audio` may wrap a single
  /// URL in a playlist.
  static String? _firstUri(Object? node) {
    if (node is Map) {
      if (node['uri'] case final String found) return found;
      for (final value in node.values) {
        if (_firstUri(value) case final found?) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        if (_firstUri(value) case final found?) return found;
      }
    }
    return null;
  }

  void _release() {
    if (_released) return;
    _released = true;
    for (final listener in List.of(_listeners)) {
      unawaited(listener.close());
    }
    _listeners.clear();
  }

  void _report(
    ProcessingStateMessage processing, {
    int? errorCode,
    String? errorMessage,
  }) {
    final event = PlaybackEventMessage(
      processingState: processing,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: position,
      duration: length,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
    for (final listener in List.of(_listeners)) {
      listener.add(event);
    }
  }
}
