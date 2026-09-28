import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/controller/dw_media_controller.dart';
import 'package:dartway_media_flutter/src/controller/dw_media_controller_factory.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:dartway_media_flutter/src/controller/dw_media_controller.dart';

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
  MediaRig({bool readyOnOpen = true})
    : video = DwFakeVideoPlayerPlatform.install(
        length: const Duration(seconds: 100),
        readyOnOpen: readyOnOpen,
      ),
      audio = DwFakeJustAudioPlatform.install(
        length: const Duration(seconds: 100),
      );

  final DwFakeVideoPlayerPlatform video;
  final DwFakeJustAudioPlatform audio;

  /// Lets the video opened last load, [duration] long.
  Future<DwFakeVideo> loadVideo(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 100),
  }) async {
    video.length = duration;
    await tester.pump();
    final opened = video.latest;
    opened.ready(length: duration);
    await tester.pump();
    await tester.pump();
    return opened;
  }

  /// Lets the track opened last load.
  Future<DwFakeAudio> loadAudio(WidgetTester tester) async {
    await dwSettleMedia(tester);
    return audio.latest;
  }

  /// Real playback of the video opened last, up to [position]: the platform
  /// reports it and `video_player`'s 100 ms poll picks it up.
  Future<void> playVideoTo(WidgetTester tester, Duration position) async {
    video.latest.advanceTo(position);
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
