import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/controller/dw_media_controller_factory.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

export 'package:dartway_media_flutter/src/controller/dw_media_controller_factory.dart';

DwMediaItem videoItem(String id) => DwMediaItem(
  id: id,
  kind: DwMediaKind.video,
  source: DwMediaSource.url('https://example.com/$id.mp4'),
);

DwMediaItem audioItem(String id) => DwMediaItem(
  id: id,
  kind: DwMediaKind.audio,
  source: DwMediaSource.url('https://example.com/$id.mp3'),
);

/// Both fake engines, installed fresh for every test.
final class MediaRig {
  MediaRig()
    : video = DwFakeVideoPlayerPlatform(initializeOnCreate: false),
      audio = DwFakeJustAudioPlatform(
        defaultDuration: const Duration(seconds: 100),
      ) {
    VideoPlayerPlatform.instance = video;
    JustAudioPlatform.instance = audio;
  }

  final DwFakeVideoPlayerPlatform video;
  final DwFakeJustAudioPlatform audio;

  /// The newest video player — the one the last load created.
  int get lastVideo => video.livePlayers.last;

  /// Lets the newest video load: the platform answers `initialized`.
  Future<int> loadVideo(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 100),
  }) async {
    await tester.pump();
    final id = lastVideo;
    video.emitInitialized(id, duration: duration);
    await tester.pump();
    await tester.pump();
    return id;
  }

  /// Lets the newest audio player load.
  Future<DwFakeAudioPlayerPlatform> loadAudio(WidgetTester tester) async {
    await dwSettleMedia(tester);
    return audio.players.values.last;
  }

  /// Real playback of the newest video up to [position]: the platform
  /// reports it and `video_player`'s 100 ms poll picks it up.
  Future<void> playVideoTo(WidgetTester tester, Duration position) async {
    video.setPosition(lastVideo, position);
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DwMediaController controllerFor(
  DwMediaItem item, {
  DwMediaConfig options = const DwMediaConfig(),
  DwMediaCallbacks callbacks = const DwMediaCallbacks(),
}) =>
    createDwMediaController(item: item, callbacks: callbacks, options: options);

/// Disposes [controller] and lets the engine's own teardown finish.
Future<void> release(WidgetTester tester, DwMediaController controller) async {
  var done = false;
  unawaited(controller.dispose().whenComplete(() => done = true));
  for (var round = 0; round < 20 && !done; round++) {
    await dwSettleMedia(tester, rounds: 1);
  }
  expect(done, isTrue, reason: 'the controller finished disposing');
}

/// Ends [session] and pumps the frame after which its engine goes.
Future<void> endSession(WidgetTester tester, DwMediaSession session) async {
  await session.dispose();
  await dwSettleMedia(tester);
}
