import 'dart:async';

import 'package:dartway_media_flutter/src/platform/dw_video_event_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

final class _EventPlatform extends VideoPlayerPlatform {
  final source = StreamController<VideoEvent>();
  int restarts = 0;
  final disposed = <int>[];

  @override
  Future<void> init() async => restarts++;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => source.stream;
  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);
}

void main() {
  test(
    'owner release after singleton replacement rejects stale typed callbacks',
    () async {
      final first = _EventPlatform();
      VideoPlayerPlatform.instance = first;
      var oldCalls = 0;
      final binding = DwVideoEventBinding(
        onEvent: (_) => oldCalls++,
        onError: (_, _) {
          oldCalls++;
          return true;
        },
      );
      final forwarded = <Object>[];
      late StreamSubscription<VideoEvent> subscription;
      await binding.initialize(() async {
        await VideoPlayerPlatform.instance.init();
        subscription = VideoPlayerPlatform.instance
            .videoEventsFor(7)
            .listen((_) {}, onError: forwarded.add);
      });
      final oldBridge = VideoPlayerPlatform.instance;
      first.source.addError(
        PlatformException(code: 'NotAllowedError', message: 'owned'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(oldCalls, 1);
      expect(forwarded, isEmpty);
      final replacement = _EventPlatform();
      VideoPlayerPlatform.instance = replacement;
      binding.release();
      final stale = PlatformException(
        code: 'AbortError',
        message: 'retired source',
      );
      first.source.addError(stale);
      first.source.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        oldCalls,
        1,
        reason:
            'release belongs to the owner, independently of the current singleton',
      );
      expect(forwarded, [same(stale)]);
      await oldBridge.dispose(7);
      expect(first.disposed, [7]);
      expect(replacement.disposed, isEmpty);
      await subscription.cancel();
      await first.source.close();
      unawaited(replacement.source.close());
    },
  );

  test(
    'explicit restart releases old bindings and forwards later errors',
    () async {
      final platform = _EventPlatform();
      VideoPlayerPlatform.instance = platform;
      var calls = 0;
      final binding = DwVideoEventBinding(
        onEvent: (_) => calls++,
        onError: (_, _) {
          calls++;
          return true;
        },
      );
      final forwarded = <Object>[];
      late StreamSubscription<VideoEvent> subscription;
      await binding.initialize(() async {
        await VideoPlayerPlatform.instance.init();
        subscription = VideoPlayerPlatform.instance
            .videoEventsFor(3)
            .listen((_) {}, onError: forwarded.add);
      });
      expect(
        platform.restarts,
        0,
        reason: 'first adapter init preserves platform lifetime',
      );
      await VideoPlayerPlatform.instance.init();
      expect(platform.restarts, 1);
      final failure = PlatformException(
        code: 'NotAllowedError',
        message: 'old stream after restart',
      );
      platform.source.addError(failure);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      expect(forwarded, [same(failure)]);
      await subscription.cancel();
      await platform.source.close();
    },
  );
}
