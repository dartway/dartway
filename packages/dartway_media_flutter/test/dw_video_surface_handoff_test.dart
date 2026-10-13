import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/media_test_kit.dart';

final class _NativePausePlatform extends DwFakeVideoPlayerPlatform {
  StreamController<VideoEvent>? _native;
  Completer<void>? playBarrier;
  bool attached = true;
  PlatformException? streamPlayError;
  @override
  Future<void> play(int playerId) async {
    await super.play(playerId);
    if (!attached) {
      await super.pause(playerId);
      _native!.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: false,
        ),
      );
    }
    await playBarrier?.future;
    if (streamPlayError case final error?) {
      await super.pause(playerId);
      _native!.addError(error);
    }
  }

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
  for (final guard in [
    'no handoff',
    'no destination',
    'disposed',
    'initial refusal',
    'before position evidence',
    'no native pause',
    'native platform',
    'manual pause',
    'background',
    'error',
    'refusal',
    'play failure',
    'expired handoff',
    'second native pause',
    'pause during restoration',
    'background during restoration',
    'stream refusal',
    'stream cancellation pause during restoration',
    'stream cancellation background during restoration',
    'stream failure',
  ]) {
    testWidgets('surface restoration respects $guard', (tester) async {
      debugDwMediaIsWebOverride = guard != 'native platform';
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final session = manager.open(items: [videoItem('guard')]);
      Widget surface(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: ValueKey(key),
          child: DwVideoSurface(session: session),
        ),
      );
      await tester.pumpWidget(surface('main'));
      await dwSettleMedia(tester);
      if (guard == 'initial refusal') {
        platform.latest.refusePlayWith = PlatformException(
          code: 'NotAllowedError',
        );
      }
      await session.play();
      final video = platform.latest;
      if (guard != 'before position evidence' && guard != 'initial refusal') {
        video.advanceTo(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 100));
      final plays = video.playCalls;
      if (guard == 'no destination') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else if (guard != 'no handoff') {
        await tester.pumpWidget(surface('mini'));
      }
      if (guard == 'disposed') await session.dispose();
      if (guard == 'manual pause') await session.pause();
      if (guard == 'background') {
        manager.handleAppLifecycle(AppLifecycleState.paused);
        await tester.pump();
      }
      if (guard == 'error') {
        video.fail('engine failed');
        await tester.pump();
      }
      if (guard == 'refusal') {
        video.refusePlayWith = PlatformException(code: 'NotAllowedError');
      }
      if (guard == 'play failure') {
        video.refusePlayWith = PlatformException(code: 'VideoError');
      }
      if (guard.startsWith('stream')) {
        platform.streamPlayError = PlatformException(
          code: guard == 'stream refusal'
              ? 'NotAllowedError'
              : guard == 'stream failure'
              ? 'VideoError'
              : 'AbortError',
          message: 'Browser rejected the operation',
        );
      }
      if (guard == 'expired handoff') {
        await tester.pump(const Duration(seconds: 1));
      }
      if (guard.contains('during restoration')) {
        platform.playBarrier = Completer<void>();
      }
      if (guard != 'no native pause') await platform.detachPausesVideo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final attempted = [
        'before position evidence',
        'refusal',
        'play failure',
        'second native pause',
        'pause during restoration',
        'background during restoration',
        'stream refusal',
        'stream cancellation pause during restoration',
        'stream cancellation background during restoration',
        'stream failure',
      ].contains(guard);
      expect(video.playCalls, plays + (attempted ? 1 : 0));
      if (guard.contains('during restoration')) {
        if (guard.contains('pause during restoration')) {
          await session.pause();
        } else {
          manager.handleAppLifecycle(AppLifecycleState.paused);
          await tester.pump();
        }
        platform.playBarrier!.complete();
        await tester.pump();
        expect(video.isPlaying, isFalse);
        expect(session.status.value.intent, DwMediaPlayIntent.pause);
        expect(session.status.value.isError, isFalse);
      }
      if (guard == 'refusal' || guard == 'stream refusal') {
        expect(session.status.value.intent, DwMediaPlayIntent.pause);
        expect(session.status.value.isError, isFalse);
      }
      if (guard == 'play failure' || guard == 'stream failure')
        expect(session.status.value.isError, isTrue);
      if (guard == 'second native pause') {
        await platform.detachPausesVideo();
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 2));
      expect(
        video.playCalls,
        plays + (attempted ? 1 : 0),
        reason: 'one attempt, no retry loop',
      );
      expect(platform.opened, hasLength(1));
      await endSession(tester, session);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'repeated handoffs wait for rendered attachment before one play',
    (tester) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final session = manager.open(items: [videoItem('rendered')]);
      Widget surface(int key) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          key: ValueKey(key),
          child: DwVideoSurface(session: session),
        ),
      );
      await tester.pumpWidget(surface(0));
      await dwSettleMedia(tester);
      await session.play();
      final video = platform.latest;
      final controller = session.videoView.value;
      video.advanceTo(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      for (var transfer = 1; transfer <= 20; transfer++) {
        final plays = video.playCalls;
        platform.attached = false;
        await tester.pumpWidget(surface(transfer));
        await platform.detachPausesVideo();
        await tester.pump();
        expect(
          video.playCalls,
          plays,
          reason: 'the first Flutter frame still has a detached DOM view',
        );
        platform.attached = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(video.isPlaying, isTrue);
        expect(video.playCalls, plays + 1);
        expect(session.videoView.value, same(controller));
        video.advanceTo(Duration(seconds: transfer + 1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(video.playCalls, plays + 1, reason: 'ticks do not retry');
      }
      expect(platform.opened, hasLength(1));
      await endSession(tester, session);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
