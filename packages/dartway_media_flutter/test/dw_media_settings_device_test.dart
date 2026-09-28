// One group per `DwMediaConfig` setting of resume, the background, the screen
// and sound: each shows the default and what turning it off or changing it
// does. The table in docs/3-flutter/media.md lists the same settings.
import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'support/fake_wakelock_platform.dart';
import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  late DwMediaInMemoryPositionStore store;

  setUp(() {
    rig = MediaRig();
    store = DwMediaInMemoryPositionStore();
  });

  /// A plugin started the way the app starts it — `init` registers it with
  /// the binding — torn down after the test, with the app back in front.
  Future<DwMedia> startMedia(WidgetTester tester, DwMediaConfig config) async {
    final media = DwMedia(config: config);
    final core = DwFlutterToolbox(config: DwFlutterConfig());
    await media.init(core);
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await media.dispose();
      await core.dispose();
    });
    return media;
  }

  /// Ends every session of [media] inside the test body: a playing video
  /// polls on a timer the test binding must not find pending.
  Future<void> endAll(WidgetTester tester, DwMedia media) async {
    await media.sessionManager.dispose();
    await dwSettleMedia(tester);
  }

  void goTo(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.handleAppLifecycleStateChanged(state);

  DwMediaSession open(
    DwMediaItem item, {
    DwMediaConfig config = const DwMediaConfig(),
    DwMediaOpenOptions? options,
  }) => DwMediaSessionManager(
    config: config,
  ).open(items: [item], options: options);

  /// Plays a 100 s video to [position] and pauses there.
  Future<DwMediaSession> playAndPause(
    WidgetTester tester,
    DwMediaResumePolicy? policy,
    Duration position, {
    String id = 'r',
  }) async {
    final session = open(
      videoItem(id),
      config: DwMediaConfig(resume: policy, positionStore: store),
    );
    await rig.loadVideo(tester, duration: const Duration(seconds: 100));
    await session.play();
    await rig.playVideoTo(tester, const Duration(milliseconds: 500));
    await rig.playVideoTo(tester, position);
    await session.pause();
    await tester.pump();
    return session;
  }

  group('resume', () {
    testWidgets('on (default): a saved position is where the item starts', (
      tester,
    ) async {
      await store.write('r', const Duration(seconds: 42));
      final session = open(
        videoItem('r'),
        config: DwMediaConfig(positionStore: store),
      );
      await rig.loadVideo(tester);
      expect(session.playback.value.position, const Duration(seconds: 42));
      await endSession(tester, session);
    });

    testWidgets('null: nothing is read and nothing is written', (tester) async {
      await store.write('r', const Duration(seconds: 42));
      final session = await playAndPause(
        tester,
        null,
        const Duration(seconds: 30),
      );
      expect(session.playback.value.position, const Duration(seconds: 30));
      expect(await store.read('r'), const Duration(seconds: 42));
      await endSession(tester, session);
      expect(await store.read('r'), const Duration(seconds: 42));
    });

    testWidgets('withoutResume turns it off for one session', (tester) async {
      await store.write('r', const Duration(seconds: 42));
      final session = open(
        videoItem('r'),
        config: DwMediaConfig(positionStore: store),
        options: const DwMediaOpenOptions(withoutResume: true),
      );
      await rig.loadVideo(tester);
      expect(session.playback.value.position, Duration.zero);
      await endSession(tester, session);
    });
  });

  group('resume.saveInterval', () {
    Future<Duration?> savedWhilePlaying(
      WidgetTester tester,
      Duration interval,
    ) async {
      final session = open(
        videoItem('r'),
        config: DwMediaConfig(
          resume: DwMediaResumePolicy(
            saveInterval: interval,
            saveOnPause: false,
            saveOnDispose: false,
          ),
          positionStore: store,
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await session.play();
      await rig.playVideoTo(tester, const Duration(milliseconds: 500));
      await rig.playVideoTo(tester, const Duration(seconds: 8));
      final saved = await store.read('r');
      await endSession(tester, session);
      return saved;
    }

    testWidgets('5 s (default): not saved 100 ms after the last save', (
      tester,
    ) async {
      expect(await savedWhilePlaying(tester, const Duration(seconds: 5)), null);
    });

    testWidgets('100 ms: saved on the next tick', (tester) async {
      expect(
        await savedWhilePlaying(tester, const Duration(milliseconds: 100)),
        const Duration(seconds: 8),
      );
    });
  });

  group('resume.minimum', () {
    testWidgets('5 s (default): a pause at 3 s saves nothing', (tester) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(),
        const Duration(seconds: 3),
      );
      expect(await store.read('r'), isNull);
      await endSession(tester, session);
    });

    testWidgets('1 s: a pause at 3 s is saved', (tester) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(minimum: Duration(seconds: 1)),
        const Duration(seconds: 3),
      );
      expect(await store.read('r'), const Duration(seconds: 3));
      await endSession(tester, session);
    });
  });

  group('resume.clearPastFraction', () {
    testWidgets('0.9 (default): a pause at 85 % is saved', (tester) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(),
        const Duration(seconds: 85),
      );
      expect(await store.read('r'), const Duration(seconds: 85));
      await endSession(tester, session);
    });

    testWidgets('0.8: a pause at 85 % clears the saved position', (
      tester,
    ) async {
      await store.write('r', const Duration(seconds: 40));
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(clearPastFraction: 0.8),
        const Duration(seconds: 85),
      );
      expect(await store.read('r'), isNull);
      await endSession(tester, session);
    });
  });

  group('resume.saveOnPause', () {
    testWidgets('on (default): pause saves', (tester) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(saveInterval: Duration(hours: 1)),
        const Duration(seconds: 30),
      );
      expect(await store.read('r'), const Duration(seconds: 30));
      await endSession(tester, session);
    });

    testWidgets('off: pause does not', (tester) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(
          saveInterval: Duration(hours: 1),
          saveOnPause: false,
          saveOnDispose: false,
        ),
        const Duration(seconds: 30),
      );
      expect(await store.read('r'), isNull);
      await endSession(tester, session);
    });
  });

  group('resume.saveOnDispose', () {
    Future<Duration?> savedAfterEnd(WidgetTester tester, bool onDispose) async {
      final session = await playAndPause(
        tester,
        DwMediaResumePolicy(
          saveInterval: const Duration(hours: 1),
          saveOnPause: false,
          saveOnDispose: onDispose,
        ),
        const Duration(seconds: 30),
      );
      expect(await store.read('r'), isNull);
      await endSession(tester, session);
      return store.read('r');
    }

    testWidgets('on (default): ending the session saves', (tester) async {
      expect(await savedAfterEnd(tester, true), const Duration(seconds: 30));
    });

    testWidgets('off: ending it does not', (tester) async {
      expect(await savedAfterEnd(tester, false), isNull);
    });
  });

  group('resume.saveOnBackground', () {
    Future<Duration?> savedInBackground(
      WidgetTester tester,
      bool onBackground,
    ) async {
      final media = await startMedia(
        tester,
        DwMediaConfig(
          resume: DwMediaResumePolicy(
            saveInterval: const Duration(hours: 1),
            saveOnPause: false,
            saveOnDispose: false,
            saveOnBackground: onBackground,
          ),
          positionStore: store,
          pauseVideoInBackground: false,
        ),
      );
      final session = media.open(items: [videoItem('r')]);
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await session.play();
      await rig.playVideoTo(tester, const Duration(milliseconds: 500));
      await rig.playVideoTo(tester, const Duration(seconds: 30));
      goTo(tester, AppLifecycleState.hidden);
      await tester.pump();
      final saved = await store.read('r');
      await session.dispose();
      await tester.pump();
      return saved;
    }

    testWidgets('on (default): going to the background saves', (tester) async {
      expect(
        await savedInBackground(tester, true),
        const Duration(seconds: 30),
      );
    });

    testWidgets('off: it does not', (tester) async {
      expect(await savedInBackground(tester, false), isNull);
    });
  });

  group('positionStore', () {
    testWidgets('null (default): positions live in memory across sessions', (
      tester,
    ) async {
      final first = open(
        videoItem('shared'),
        config: const DwMediaConfig(
          resume: DwMediaResumePolicy(minimum: Duration.zero),
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await first.seek(const Duration(seconds: 12));
      await first.pause();
      await endSession(tester, first);
      final second = open(videoItem('shared'));
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      expect(second.playback.value.position, const Duration(seconds: 12));
      await endSession(tester, second);
    });

    testWidgets('a store of the project\'s own receives the positions', (
      tester,
    ) async {
      final session = await playAndPause(
        tester,
        const DwMediaResumePolicy(),
        const Duration(seconds: 30),
        id: 'own',
      );
      expect(await store.read('own'), const Duration(seconds: 30));
      await endSession(tester, session);
    });
  });

  group('pauseVideoInBackground', () {
    late DwMedia media;

    Future<(DwMediaSession, DwFakeVideo)> playingVideo(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      media = await startMedia(tester, config);
      final session = media.open(items: [videoItem('v')]);
      final video = await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      return (session, video);
    }

    testWidgets('on (default): a playing video pauses in the background', (
      tester,
    ) async {
      final (session, video) = await playingVideo(
        tester,
        const DwMediaConfig(),
      );
      goTo(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(session.playback.value.isPlaying, isFalse);
      expect(video.isPlaying, isFalse);
      await endAll(tester, media);
    });

    testWidgets('on: `inactive` is not the background', (tester) async {
      final (session, video) = await playingVideo(
        tester,
        const DwMediaConfig(),
      );
      goTo(tester, AppLifecycleState.inactive);
      await tester.pump();
      expect(video.isPlaying, isTrue);
      expect(session.playback.value.isPlaying, isTrue);
      await endAll(tester, media);
    });

    testWidgets('on: a buffering video is stopped too', (tester) async {
      final (session, video) = await playingVideo(
        tester,
        const DwMediaConfig(),
      );
      video.startBuffering();
      await tester.pump();
      expect(session.playback.value.isBuffering, isTrue);
      goTo(tester, AppLifecycleState.hidden);
      await tester.pump();
      expect(video.isPlaying, isFalse);
      await endAll(tester, media);
    });

    testWidgets('on: a video waiting to load to play never starts', (
      tester,
    ) async {
      final slow = MediaRig(readyOnOpen: false);
      media = await startMedia(
        tester,
        const DwMediaConfig(autoplayOnOpen: true),
      );
      final session = media.open(items: [videoItem('v')]);
      await tester.pump();
      goTo(tester, AppLifecycleState.paused);
      await tester.pump();
      slow.video.latest.ready();
      await tester.pump(const Duration(seconds: 1));
      expect(slow.video.latest.isPlaying, isFalse);
      expect(session.playback.value.isPlaying, isFalse);
      await endAll(tester, media);
    });

    testWidgets('on: an ended video counting down to the next never moves', (
      tester,
    ) async {
      media = await startMedia(tester, const DwMediaConfig(autoplayNext: true));
      final session = media.open(items: [videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 8));
      rig.video.latest.finish();
      await tester.pump();
      expect(session.queue.value.autoplayCountdown, isNotNull);
      goTo(tester, AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 10));
      expect(session.queue.value.autoplayCountdown, isNull);
      expect(session.currentItem.id, 'a');
      expect(rig.video.videos.single.isPlaying, isFalse);
      await endAll(tester, media);
    });

    testWidgets('on: play() is refused while in the background', (
      tester,
    ) async {
      final (session, video) = await playingVideo(
        tester,
        const DwMediaConfig(),
      );
      goTo(tester, AppLifecycleState.paused);
      await tester.pump();
      await session.play();
      await tester.pump();
      expect(video.isPlaying, isFalse);
      goTo(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(video.isPlaying, isFalse, reason: 'coming back resumes nothing');
      await session.play();
      await tester.pump();
      expect(video.isPlaying, isTrue);
      await endAll(tester, media);
    });

    testWidgets('off: the video plays on — video_player\'s own pause on '
        '`paused` is out of the way', (tester) async {
      final (session, video) = await playingVideo(
        tester,
        const DwMediaConfig(pauseVideoInBackground: false),
      );
      goTo(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(video.isPlaying, isTrue);
      expect(session.playback.value.isPlaying, isTrue);
      await endAll(tester, media);
    });
  });

  group('backgroundAudio', () {
    Future<bool> audioInBackground(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final media = await startMedia(tester, config);
      final session = media.open(items: [audioItem('a')]);
      await rig.loadAudio(tester);
      await session.play();
      await tester.pump();
      goTo(tester, AppLifecycleState.hidden);
      await dwSettleMedia(tester);
      final playing = session.playback.value.isPlaying;
      unawaited(session.dispose());
      await dwSettleMedia(tester);
      return playing;
    }

    testWidgets('off (default): audio pauses in the background', (
      tester,
    ) async {
      expect(await audioInBackground(tester, const DwMediaConfig()), isFalse);
    });

    testWidgets('on: audio plays on', (tester) async {
      expect(
        await audioInBackground(
          tester,
          const DwMediaConfig(backgroundAudio: true),
        ),
        isTrue,
      );
    });
  });

  group('onLeaveWithoutMiniPlayer', () {
    Future<DwMediaSession> leftWhilePlaying(
      WidgetTester tester, {
      DwMediaConfig config = const DwMediaConfig(miniPlayer: false),
      DwMediaOpenOptions? options,
    }) async {
      final session = open(videoItem('v'), config: config, options: options);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      session.minimize();
      await tester.pump();
      return session;
    }

    testWidgets('pause (default): the page gone, playback stops', (
      tester,
    ) async {
      final session = await leftWhilePlaying(tester);
      expect(session.minimized.value, isFalse);
      expect(session.isDisposed, isFalse);
      expect(rig.video.latest.isPlaying, isFalse);
      await endSession(tester, session);
    });

    testWidgets('stop: the session ends and its engine goes', (tester) async {
      final session = await leftWhilePlaying(
        tester,
        config: const DwMediaConfig(
          miniPlayer: false,
          onLeaveWithoutMiniPlayer: DwMediaLeaveAction.stop,
        ),
      );
      await dwSettleMedia(tester);
      expect(session.isDisposed, isTrue);
      expect(rig.video.videos, isEmpty);
    });

    testWidgets('keepPlaying, per open: it plays on', (tester) async {
      final session = await leftWhilePlaying(
        tester,
        options: const DwMediaOpenOptions(
          onLeaveWithoutMiniPlayer: DwMediaLeaveAction.keepPlaying,
        ),
      );
      expect(rig.video.latest.isPlaying, isTrue);
      await endSession(tester, session);
    });

    testWidgets('with the mini-player on, leaving hands it over instead', (
      tester,
    ) async {
      final session = await leftWhilePlaying(
        tester,
        config: const DwMediaConfig(),
      );
      expect(session.minimized.value, isTrue);
      expect(rig.video.latest.isPlaying, isTrue);
      await endSession(tester, session);
    });
  });

  group('wakelockWhilePlaying', () {
    late FakeWakelockPlatform wakelock;
    setUp(() {
      wakelock = FakeWakelockPlatform();
      wakelockPlusPlatformInstance = wakelock;
    });

    testWidgets('on (default): held while a video plays, released on pause', (
      tester,
    ) async {
      final session = open(videoItem('v'));
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(wakelock.isEnabled, isTrue);
      await session.pause();
      await tester.pump();
      expect(wakelock.isEnabled, isFalse);
      await endSession(tester, session);
    });

    testWidgets('off: never taken', (tester) async {
      final session = open(
        videoItem('v'),
        config: const DwMediaConfig(wakelockWhilePlaying: false),
      );
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(wakelock.toggleCount, 0);
      await endSession(tester, session);
    });
  });

  group('webMutedStart', () {
    tearDown(() => debugDwMediaIsWebOverride = null);

    testWidgets('on (default), on the web: a video starts muted', (
      tester,
    ) async {
      debugDwMediaIsWebOverride = true;
      final session = open(videoItem('v'));
      await rig.loadVideo(tester);
      expect(session.playback.value.muted, isTrue);
      await endSession(tester, session);
    });

    testWidgets('off, on the web: it starts with sound', (tester) async {
      debugDwMediaIsWebOverride = true;
      final session = open(
        videoItem('v'),
        config: const DwMediaConfig(webMutedStart: false),
      );
      await rig.loadVideo(tester);
      expect(session.playback.value.muted, isFalse);
      await endSession(tester, session);
    });

    testWidgets('on, off the web: it starts with sound', (tester) async {
      debugDwMediaIsWebOverride = false;
      final session = open(videoItem('v'));
      await rig.loadVideo(tester);
      expect(session.playback.value.muted, isFalse);
      await endSession(tester, session);
    });
  });

  group('rememberSound', () {
    Future<bool> secondStartsMuted(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final manager = DwMediaSessionManager(config: config);
      final first = manager.open(items: [videoItem('a')]);
      await rig.loadVideo(tester);
      await first.setMuted(true);
      await endSession(tester, first);
      final second = manager.open(items: [videoItem('b')]);
      await rig.loadVideo(tester);
      final muted = second.playback.value.muted;
      await endSession(tester, second);
      return muted;
    }

    testWidgets('on (default): a mute carries to the next session', (
      tester,
    ) async {
      expect(await secondStartsMuted(tester, const DwMediaConfig()), isTrue);
    });

    testWidgets('off: every item starts with sound', (tester) async {
      expect(
        await secondStartsMuted(
          tester,
          const DwMediaConfig(rememberSound: false),
        ),
        isFalse,
      );
    });

    testWidgets('on the web, a remembered unmute beats webMutedStart', (
      tester,
    ) async {
      debugDwMediaIsWebOverride = true;
      addTearDown(() => debugDwMediaIsWebOverride = null);
      final manager = DwMediaSessionManager(config: const DwMediaConfig());
      final first = manager.open(items: [videoItem('a')]);
      await rig.loadVideo(tester);
      expect(first.playback.value.muted, isTrue);
      await first.setMuted(false);
      await endSession(tester, first);
      final second = manager.open(items: [videoItem('b')]);
      await rig.loadVideo(tester);
      expect(second.playback.value.muted, isFalse);
      await endSession(tester, second);
    });
  });
}
