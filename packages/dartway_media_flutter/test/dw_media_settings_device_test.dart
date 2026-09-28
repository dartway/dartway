// One group per `DwMediaConfig` setting of resume, the background, the screen
// and sound: each shows the default and what turning it off or changing it
// does. The table in docs/3-flutter/media.md lists the same settings.
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
      final media = DwMedia(
        config: DwMediaConfig(
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
      media.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await tester.pump();
      final saved = await store.read('r');
      await media.dispose();
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
    Future<bool> playingInBackground(
      WidgetTester tester,
      DwMediaConfig config,
      AppLifecycleState state,
    ) async {
      final media = DwMedia(config: config);
      final session = media.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      media.didChangeAppLifecycleState(state);
      await tester.pump();
      final playing = session.playback.value.isPlaying;
      await media.dispose();
      await tester.pump();
      return playing;
    }

    testWidgets('on (default): a video pauses in the background', (
      tester,
    ) async {
      expect(
        await playingInBackground(
          tester,
          const DwMediaConfig(),
          AppLifecycleState.paused,
        ),
        isFalse,
      );
    });

    testWidgets('on: `inactive` is not the background', (tester) async {
      expect(
        await playingInBackground(
          tester,
          const DwMediaConfig(),
          AppLifecycleState.inactive,
        ),
        isTrue,
      );
    });

    testWidgets('off: the video plays on', (tester) async {
      expect(
        await playingInBackground(
          tester,
          const DwMediaConfig(pauseVideoInBackground: false),
          AppLifecycleState.paused,
        ),
        isTrue,
      );
    });
  });

  group('backgroundAudio', () {
    Future<bool> audioInBackground(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final media = DwMedia(config: config);
      final session = media.open(items: [audioItem('a')]);
      await rig.loadAudio(tester);
      await session.play();
      await tester.pump();
      media.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await tester.pump();
      final playing = session.playback.value.isPlaying;
      await media.dispose();
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
