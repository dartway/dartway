import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/media_test_kit.dart';

final class _NativePausePlatform extends DwFakeVideoPlayerPlatform {
  StreamController<VideoEvent>? _native;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late StreamSubscription<VideoEvent> subscription;
    late StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
      onListen: () => subscription = super
          .videoEventsFor(playerId)
          .listen(events.add, onError: events.addError),
      onCancel: () => subscription.cancel(),
    );
    _native = events;
    return events.stream;
  }

  Future<void> detachPausesVideo() async {
    await super.pause(latest.id);
    _native!.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }
}

void main() {
  tearDown(() => debugDwMediaIsWebOverride = null);
  for (final detachFirst in [true, false]) {
    testWidgets('web surface handoff restores native detach pause '
        '(${detachFirst ? 'detach first' : 'attach first'})', (tester) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final session = manager.open(items: [videoItem('handoff')]);
      Widget surface(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: ValueKey(key),
          child: DwVideoSurface(session: session),
        ),
      );
      await tester.pumpWidget(surface('main'));
      await dwSettleMedia(tester);
      await session.play();
      platform.latest.advanceTo(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      final video = platform.latest;
      final plays = video.playCalls;
      final controller = session.videoView.value;
      if (detachFirst) {
        await tester.pumpWidget(const SizedBox.shrink());
        await platform.detachPausesVideo();
        await tester.pump();
      }
      await tester.pumpWidget(surface('mini'));
      if (!detachFirst) await platform.detachPausesVideo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(video.isPlaying, isTrue);
      expect(video.playCalls, plays + 1);
      expect(platform.opened, hasLength(1));
      expect(session.videoView.value, same(controller));
      for (var second = 2; second < 8; second++) {
        video.advanceTo(Duration(seconds: second));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        video.playCalls,
        plays + 1,
        reason: 'position ticks issue no play',
      );
      await endSession(tester, session);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
