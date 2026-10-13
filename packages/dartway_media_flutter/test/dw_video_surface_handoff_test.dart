import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/media_test_kit.dart';

final class _NativePausePlatform extends DwFakeVideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> nativeStreams = {};
  int initCalls = 0;
  final List<int> disposals = [];

  @override
  Future<void> init() async {
    initCalls++;
    for (final video in videos) {
      await super.dispose(video.id);
    }
  }

  @override
  Future<void> dispose(int playerId) {
    disposals.add(playerId);
    return super.dispose(playerId);
  }

  Completer<void>? playBarrier;
  bool attached = true;
  PlatformException? streamPlayError;
  @override
  Future<void> play(int playerId) async {
    final operationError = streamPlayError;
    final barrier = playBarrier;
    await super.play(playerId);
    if (operationError != null && operationError.code != 'AbortError') {
      await super.pause(playerId);
    } else {
      nativeStreams[playerId]!.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: true,
        ),
      );
    }
    if (!attached) {
      await super.pause(playerId);
      nativeStreams[playerId]!.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: false,
        ),
      );
    }
    await barrier?.future;
    if (operationError != null) {
      nativeStreams[playerId]!.addError(operationError);
    }
  }

  @override
  Future<void> pause(int playerId) async {
    await super.pause(playerId);
    nativeStreams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
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
    nativeStreams[playerId] = events;
    return events.stream;
  }

  Future<void> detachPausesVideo({int? playerId}) async {
    final target = playerId ?? latest.id;
    await super.pause(target);
    nativeStreams[target]!.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }
}

final class _BlockedPositionStore implements DwMediaPositionStore {
  final saved = Completer<void>();
  int writes = 0;
  @override
  Future<Duration?> read(String itemId) async => null;
  @override
  Future<void> write(String itemId, Duration position) {
    writes++;
    return saved.future;
  }

  @override
  Future<void> clear(String itemId) async {}
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
        config: DwMediaConfig(
          resume: null,
          wakelockWhilePlaying: false,
          autoRetryCount:
              guard.startsWith('stream') && guard != 'stream failure' ? 2 : 0,
          autoRetryDelay: const Duration(milliseconds: 100),
        ),
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
        expect(session.videoView.value!.value.isInitialized, isTrue);
        expect(session.videoView.value!.value.isPlaying, isFalse);
      }
      if (guard == 'refusal' || guard == 'stream refusal') {
        expect(session.status.value.intent, DwMediaPlayIntent.pause);
        expect(session.status.value.isError, isFalse);
      }
      if (guard == 'play failure' || guard == 'stream failure') {
        expect(session.status.value.isError, isTrue);
      }
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
  testWidgets(
    'typed bridge preserves foreign playback and isolates two owned streams',
    (tester) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final foreign = VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/foreign.mp4'),
      );
      await foreign.initialize();
      await foreign.play();
      final foreignVideo = platform.latest;
      expect(platform.initCalls, 1);
      final firstManager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final secondManager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final first = firstManager.open(items: [videoItem('first-owned')]);
      final second = secondManager.open(items: [videoItem('second-owned')]);
      Widget surfaces(String firstKey) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: DwVideoSurface(key: ValueKey(firstKey), session: first),
            ),
            Expanded(
              child: DwVideoSurface(
                key: const ValueKey('second'),
                session: second,
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(surfaces('main'));
      await dwSettleMedia(tester);
      await first.play();
      await second.play();
      final firstVideo = platform.opened[1];
      final secondVideo = platform.opened[2];
      expect(
        platform.initCalls,
        1,
        reason: 'adapter installation cannot reset an existing platform',
      );
      expect(platform.disposals, isEmpty);
      expect(foreignVideo.isPlaying, isTrue);
      platform.streamPlayError = PlatformException(
        code: 'NotAllowedError',
        message: 'gesture required',
      );
      await tester.pumpWidget(surfaces('mini'));
      await platform.detachPausesVideo(playerId: firstVideo.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(first.status.value.intent, DwMediaPlayIntent.pause);
      expect(first.status.value.isError, isFalse);
      expect(first.videoView.value!.value.isInitialized, isTrue);
      expect(first.videoView.value!.value.isPlaying, isFalse);
      expect(second.status.value.isError, isFalse);
      expect(secondVideo.isPlaying, isTrue);
      expect(secondVideo.playCalls, 1);
      expect(foreignVideo.isPlaying, isTrue);
      expect(foreignVideo.playCalls, 1);
      platform.nativeStreams[foreignVideo.id]!.addError(
        PlatformException(code: 'NotAllowedError', message: 'foreign refusal'),
      );
      await tester.pump();
      expect(
        foreign.value.hasError,
        isTrue,
        reason: 'unowned streams are forwarded unchanged',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, first);
      await endSession(tester, second);
      await foreign.dispose();
    },
  );

  testWidgets('explicit bridge init delegates restart and releases bindings', (
    tester,
  ) async {
    debugDwMediaIsWebOverride = true;
    final platform = _NativePausePlatform();
    VideoPlayerPlatform.instance = platform;
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
    );
    final session = manager.open(items: [videoItem('restart')]);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DwVideoSurface(session: session),
      ),
    );
    await dwSettleMedia(tester);
    await session.play();
    final before = platform.initCalls;
    await VideoPlayerPlatform.instance.init();
    expect(platform.initCalls, before + 1);
    expect(platform.latest.isReleased, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await endSession(tester, session);
  });

  testWidgets('native play acknowledgement ends restoration error capture', (
    tester,
  ) async {
    debugDwMediaIsWebOverride = true;
    final platform = _NativePausePlatform();
    VideoPlayerPlatform.instance = platform;
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
    );
    final session = manager.open(items: [videoItem('terminal-play')]);
    Widget surface(String key) => Directionality(
      textDirection: TextDirection.ltr,
      child: DwVideoSurface(key: ValueKey(key), session: session),
    );
    await tester.pumpWidget(surface('main'));
    await dwSettleMedia(tester);
    await session.play();
    await tester.pumpWidget(surface('mini'));
    await platform.detachPausesVideo();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(platform.latest.isPlaying, isTrue);
    platform.nativeStreams[platform.latest.id]!.addError(
      PlatformException(
        code: 'NotAllowedError',
        message: 'later unrelated failure',
      ),
    );
    await tester.pump();
    expect(
      session.status.value.isError,
      isTrue,
      reason: 'terminal native play ends the allowance',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await endSession(tester, session);
  });
  for (final code in ['AbortError', 'NotAllowedError']) {
    testWidgets('pause then resume retires delayed restoration $code', (
      tester,
    ) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(
          resume: null,
          wakelockWhilePlaying: false,
          autoRetryCount: 2,
          autoRetryDelay: Duration(milliseconds: 100),
        ),
      );
      final session = manager.open(items: [videoItem('user-resume-race')]);
      Widget surface(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: DwVideoSurface(key: ValueKey(key), session: session),
      );
      await tester.pumpWidget(surface('main'));
      await dwSettleMedia(tester);
      await session.play();
      final pending = Completer<void>();
      platform.playBarrier = pending;
      platform.streamPlayError = PlatformException(
        code: code,
        message: 'old operation rejected',
      );
      await tester.pumpWidget(surface('mini'));
      await platform.detachPausesVideo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await session.pause();
      platform.playBarrier = null;
      platform.streamPlayError = null;
      final resumed = session.play();
      await tester.pump();
      pending.complete();
      await tester.pump();
      await resumed;
      await tester.pump(const Duration(seconds: 1));
      expect(session.status.value.intent, DwMediaPlayIntent.play);
      expect(session.status.value.isError, isFalse);
      expect(session.videoView.value!.value.isInitialized, isTrue);
      expect(platform.latest.isPlaying, isTrue);
      expect(
        platform.opened,
        hasLength(1),
        reason: 'old rejection cannot reload the newer user play',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, session);
    });
  }
  for (final cancellation in [
    'pause',
    'seek',
    'source',
    'dispose',
    'stop',
    'restart',
    'timeout',
    'new refusal',
  ]) {
    testWidgets(
      'waiting resume respects $cancellation without stale native play',
      (tester) async {
        debugDwMediaIsWebOverride = true;
        final platform = _NativePausePlatform();
        VideoPlayerPlatform.instance = platform;
        final manager = DwMediaSessionManager(
          config: const DwMediaConfig(
            resume: null,
            wakelockWhilePlaying: false,
          ),
        );
        final session = manager.open(
          items: [videoItem('pending-resume'), videoItem('next-source')],
        );
        Widget surface(String key) => Directionality(
          textDirection: TextDirection.ltr,
          child: DwVideoSurface(key: ValueKey(key), session: session),
        );
        await tester.pumpWidget(surface('main'));
        await dwSettleMedia(tester);
        await session.play();
        final video = platform.latest;
        final pending = Completer<void>();
        platform.playBarrier = pending;
        platform.streamPlayError = PlatformException(
          code: 'AbortError',
          message: 'retired restoration',
        );
        await tester.pumpWidget(surface('mini'));
        await platform.detachPausesVideo();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await session.pause();
        platform.playBarrier = null;
        platform.streamPlayError = cancellation == 'new refusal'
            ? PlatformException(
                code: 'NotAllowedError',
                message: 'new user operation refused',
              )
            : null;
        final resumed = session.play();
        await tester.pump();
        expect(
          video.playCalls,
          2,
          reason: 'new native play waits for the old promise',
        );
        Future<void>? cancelled;
        if (cancellation == 'pause') await session.pause();
        if (cancellation == 'seek') {
          cancelled = session.seek(const Duration(seconds: 5));
        }
        if (cancellation == 'source') cancelled = session.next(autoplay: false);
        if (cancellation == 'dispose') await session.dispose();
        if (cancellation == 'stop') await session.closeFromMiniPlayer();
        if (cancellation == 'restart') {
          await VideoPlayerPlatform.instance.init();
        }
        if (cancellation == 'timeout') {
          await tester.pump(const Duration(seconds: 31));
          await resumed;
          expect(session.status.value.intent, DwMediaPlayIntent.pause);
          expect(session.status.value.isError, isFalse);
          await session.play();
          expect(
            video.playCalls,
            2,
            reason: 'timeout cannot issue overlapping native play',
          );
        }
        await tester.pump();
        pending.complete();
        await tester.pump();
        await resumed;
        if (cancelled != null) {
          await tester.pump();
          await cancelled;
        }
        await tester.pump(const Duration(milliseconds: 500));
        if (cancellation == 'new refusal') {
          expect(video.playCalls, 3);
          expect(
            session.status.value.isError,
            isTrue,
            reason:
                'new ordinary refusal is not swallowed with the retired one',
          );
        } else if (cancellation == 'seek') {
          expect(
            video.playCalls,
            3,
            reason: 'only the new seek may resume, not the stale play',
          );
          expect(session.position.value.position, const Duration(seconds: 5));
          expect(session.status.value.isError, isFalse);
        } else {
          expect(
            video.playCalls,
            2,
            reason: 'retired resume cannot issue stale native play',
          );
          expect(session.status.value.isError, isFalse);
        }
        if (cancellation == 'timeout') {
          await session.play();
          expect(
            video.playCalls,
            3,
            reason: 'manual retry after old settlement is safe',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await endSession(tester, session);
      },
    );
  }

  testWidgets(
    'ordinary initial native stream refusal remains outside handoff capture',
    (tester) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final session = manager.open(items: [videoItem('ordinary-refusal')]);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DwVideoSurface(session: session),
        ),
      );
      await dwSettleMedia(tester);
      platform.streamPlayError = PlatformException(
        code: 'NotAllowedError',
        message: 'ordinary stream refusal',
      );
      await session.play();
      await tester.pump();
      expect(
        session.status.value.isError,
        isTrue,
        reason: 'the adapter does not change ordinary stream error handling',
      );
      expect(platform.opened, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, session);
    },
  );
  testWidgets(
    'foreign initialized from an owned native callback cannot inherit its binding',
    (tester) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null, wakelockWhilePlaying: false),
      );
      final session = manager.open(items: [videoItem('callback-owner')]);
      Widget surface(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: DwVideoSurface(key: ValueKey(key), session: session),
      );
      await tester.pumpWidget(surface('main'));
      await dwSettleMedia(tester);
      await session.play();
      await tester.pump();
      final owned = platform.latest;
      owned.advanceTo(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      VideoPlayerController? foreign;
      Future<void>? initialized;
      void onStatus() {
        if (session.status.value.waiting && foreign == null) {
          foreign = VideoPlayerController.networkUrl(
            Uri.parse('https://example.test/from-callback.mp4'),
          );
          initialized = foreign!.initialize();
        }
      }

      session.status.addListener(onStatus);
      platform.nativeStreams[owned.id]!.add(
        VideoEvent(eventType: VideoEventType.bufferingStart),
      );
      await tester.pump();
      expect(foreign, isNotNull);
      await initialized;
      await foreign!.dispose();
      session.status.removeListener(onStatus);
      platform.nativeStreams[owned.id]!.add(
        VideoEvent(eventType: VideoEventType.bufferingEnd),
      );
      await tester.pump();
      await tester.pumpWidget(surface('mini'));
      await platform.detachPausesVideo(playerId: owned.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        owned.isPlaying,
        isTrue,
        reason: 'foreign disposal cannot release the original owner',
      );
      expect(owned.playCalls, 2);
      expect(session.status.value.isError, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, session);
    },
  );

  for (final check in ['overlap', 'original deadline']) {
    testWidgets(
      'unresolved restoration keeps ownership across a second handoff: $check',
      (tester) async {
        debugDwMediaIsWebOverride = true;
        final platform = _NativePausePlatform();
        VideoPlayerPlatform.instance = platform;
        final manager = DwMediaSessionManager(
          config: const DwMediaConfig(
            resume: null,
            wakelockWhilePlaying: false,
          ),
        );
        final session = manager.open(
          items: [videoItem('pending-second-handoff')],
        );
        Widget surface(String key) => Directionality(
          textDirection: TextDirection.ltr,
          child: DwVideoSurface(key: ValueKey(key), session: session),
        );
        await tester.pumpWidget(surface('main'));
        await dwSettleMedia(tester);
        await session.play();
        final pending = Completer<void>();
        platform.playBarrier = pending;
        platform.streamPlayError = PlatformException(
          code: 'AbortError',
          message: 'pending restore interrupted',
        );
        await tester.pumpWidget(surface('mini'));
        await platform.detachPausesVideo();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        if (check == 'original deadline')
          await tester.pump(const Duration(seconds: 29));
        await tester.pumpWidget(surface('main-again'));
        await platform.detachPausesVideo();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        if (check == 'overlap') {
          expect(
            platform.latest.playCalls,
            2,
            reason: 'a second surface cannot overlap the pending native play',
          );
        } else {
          await tester.pump(const Duration(seconds: 2));
          expect(
            session.status.value.intent,
            DwMediaPlayIntent.pause,
            reason: 'replacement must not extend the first 30-second deadline',
          );
        }
        platform.playBarrier = null;
        platform.streamPlayError = null;
        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(session.status.value.isError, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await endSession(tester, session);
      },
    );
  }

  for (final detachment in [
    'close before frame',
    'source before frame',
    'blocked storage error',
    'blocked storage reload',
  ]) {
    testWidgets('retired video emits no failure after $detachment', (
      tester,
    ) async {
      debugDwMediaIsWebOverride = true;
      final platform = _NativePausePlatform();
      VideoPlayerPlatform.instance = platform;
      final store = _BlockedPositionStore();
      final failures = <Object>[];
      final blocked = detachment.startsWith('blocked');
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          resume: blocked
              ? const DwMediaResumePolicy(saveOnPause: false)
              : null,
          positionStore: store,
          wakelockWhilePlaying: false,
          autoRetryCount: detachment.endsWith('reload') ? 2 : 0,
          autoRetryDelay: const Duration(milliseconds: 100),
        ),
      );
      final session = manager.open(
        items: [videoItem('retired-source'), videoItem('replacement')],
        callbacks: DwMediaCallbacks(onError: (_, error) => failures.add(error)),
      );
      Widget surface(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: DwVideoSurface(key: ValueKey(key), session: session),
      );
      await tester.pumpWidget(surface('main'));
      await dwSettleMedia(tester);
      await session.play();
      final video = platform.latest;
      video.advanceTo(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 100));
      final pending = Completer<void>();
      platform.playBarrier = pending;
      await tester.pumpWidget(surface('mini'));
      await platform.detachPausesVideo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      platform.playBarrier = null;
      if (detachment.startsWith('source')) {
        await session.next(autoplay: false);
      } else {
        await session.closeFromMiniPlayer();
      }
      if (blocked) {
        await tester.pump();
        await tester.pump();
        expect(
          store.writes,
          greaterThan(0),
          reason:
              'deferred owner disposal is actually waiting on resume storage',
        );
      }
      platform.nativeStreams[video.id]!.addError(
        PlatformException(
          code: 'AbortError',
          message: 'retired browser play rejected',
        ),
      );
      // Drain the asynchronous native stream without drawing the disposal frame.
      await Future<void>.value();
      await Future<void>.value();
      expect(failures, isEmpty, reason: 'a detached owner cannot call onError');
      pending.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(
        platform.opened,
        hasLength(detachment.startsWith('source') ? 2 : 1),
        reason: 'retired errors cannot trigger a reload',
      );
      store.saved.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, session);
    });
  }
}
