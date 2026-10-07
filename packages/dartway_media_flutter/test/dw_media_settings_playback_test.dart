// One group per `DwMediaConfig` setting of playback and the queue: each shows
// the default and what turning it off or changing it does. The table in
// docs/3-flutter/media.md lists the same settings in the same order.
import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());

  DwMediaSession open(
    List<DwMediaItem> items, {
    DwMediaConfig config = const DwMediaConfig(),
    DwMediaOpenOptions? options,
    DwMediaCallbacks callbacks = const DwMediaCallbacks(),
  }) => DwMediaSessionManager(
    config: config,
  ).open(items: items, options: options, callbacks: callbacks);

  /// Plays the current video to its real end.
  Future<void> playToEnd(
    WidgetTester tester,
    DwMediaSession session, {
    Duration duration = const Duration(seconds: 10),
  }) async {
    await session.play();
    await rig.playVideoTo(tester, duration - const Duration(seconds: 2));
    rig.video.latest.finish();
    await tester.pump();
  }

  group('autoplayOnOpen', () {
    testWidgets('off (default): the item waits for play()', (tester) async {
      final session = open([videoItem('a')]);
      await rig.loadVideo(tester);
      expect(session.playback.value.isPlaying, isFalse);
      await endSession(tester, session);
    });

    testWidgets('on: the item plays as soon as it loads', (tester) async {
      final session = open([
        videoItem('a'),
      ], config: const DwMediaConfig(autoplayOnOpen: true));
      await rig.loadVideo(tester);
      expect(session.playback.value.isPlaying, isTrue);
      await endSession(tester, session);
    });
  });

  group('autoplayNext', () {
    testWidgets('off (default): the queue stays on the ended item', (
      tester,
    ) async {
      final session = open([videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      await tester.pump(const Duration(seconds: 10));
      expect(session.currentItem.id, 'a');
      await endSession(tester, session);
    });

    testWidgets('on: the queue moves to the next item', (tester) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          autoplayNext: true,
          autoplayCountdown: false,
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });

    testWidgets('a scrub to the end never moves the queue', (tester) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          autoplayNext: true,
          autoplayCountdown: false,
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await session.seek(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(session.currentItem.id, 'a');
      await endSession(tester, session);
    });
  });

  group('autoplayCountdown', () {
    testWidgets('on (default): the move waits for the countdown', (
      tester,
    ) async {
      final session = open([
        videoItem('a'),
        videoItem('b'),
      ], config: const DwMediaConfig(autoplayNext: true));
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      expect(session.currentItem.id, 'a');
      expect(session.queue.value.autoplayCountdown, const Duration(seconds: 5));
      expect(session.queue.value.showNextPreview, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(session.queue.value.autoplayCountdown, const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });

    testWidgets('off: the move is immediate', (tester) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          autoplayNext: true,
          autoplayCountdown: false,
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      expect(session.queue.value.autoplayCountdown, isNull);
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });

    testWidgets('cancelAutoplay() stops the countdown', (tester) async {
      final session = open([
        videoItem('a'),
        videoItem('b'),
      ], config: const DwMediaConfig(autoplayNext: true));
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      session.cancelAutoplay();
      await tester.pump(const Duration(seconds: 10));
      expect(session.currentItem.id, 'a');
      expect(session.queue.value.autoplayCountdown, isNull);
      await endSession(tester, session);
    });
  });

  group('autoplayCountdownDuration', () {
    testWidgets('2 s instead of 5 s: the move comes after 2 s', (tester) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          autoplayNext: true,
          autoplayCountdownDuration: Duration(seconds: 2),
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      expect(session.queue.value.autoplayCountdown, const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(session.currentItem.id, 'a');
      await tester.pump(const Duration(seconds: 1));
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });

    testWidgets('2.5 s: the move comes at 2.5 s, not at a whole second', (
      tester,
    ) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          autoplayNext: true,
          autoplayCountdownDuration: Duration(milliseconds: 2500),
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(session.currentItem.id, 'a');
      expect(
        session.queue.value.autoplayCountdown,
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });
  });

  group('autoplayCountdownTick', () {
    Future<List<Duration?>> shownOverOneSecond(
      WidgetTester tester,
      Duration tick,
    ) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: DwMediaConfig(autoplayNext: true, autoplayCountdownTick: tick),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await playToEnd(tester, session);
      final shown = <Duration?>[];
      void record() => shown.add(session.queue.value.autoplayCountdown);
      session.queue.addListener(record);
      await tester.pump(const Duration(seconds: 1));
      session.queue.removeListener(record);
      await endSession(tester, session);
      return shown;
    }

    testWidgets('1 s (default): one update in a second', (tester) async {
      expect(await shownOverOneSecond(tester, const Duration(seconds: 1)), [
        const Duration(seconds: 4),
      ]);
    });

    testWidgets('250 ms: four updates in the same second', (tester) async {
      expect(
        await shownOverOneSecond(tester, const Duration(milliseconds: 250)),
        [
          const Duration(milliseconds: 4750),
          const Duration(milliseconds: 4500),
          const Duration(milliseconds: 4250),
          const Duration(seconds: 4),
        ],
      );
    });
  });

  group('nextPreview', () {
    testWidgets('off (default): no preview near the end', (tester) async {
      final session = open([videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 55));
      expect(session.queue.value.showNextPreview, isFalse);
      await endSession(tester, session);
    });

    testWidgets('on: the preview shows within the lead time', (tester) async {
      final session = open([
        videoItem('a'),
        videoItem('b'),
      ], config: const DwMediaConfig(nextPreview: true));
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 45));
      expect(session.queue.value.showNextPreview, isFalse);
      await rig.playVideoTo(tester, const Duration(seconds: 55));
      expect(session.queue.value.showNextPreview, isTrue);
      await endSession(tester, session);
    });

    testWidgets('on, on the last item: nothing to preview', (tester) async {
      final session = open([
        videoItem('a'),
      ], config: const DwMediaConfig(nextPreview: true));
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 55));
      expect(session.queue.value.showNextPreview, isFalse);
      await endSession(tester, session);
    });
  });

  group('nextPreviewLeadTime', () {
    testWidgets('20 s instead of 10 s: the preview shows earlier', (
      tester,
    ) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: const DwMediaConfig(
          nextPreview: true,
          nextPreviewLeadTime: Duration(seconds: 20),
        ),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 45));
      expect(session.queue.value.showNextPreview, isTrue);
      await endSession(tester, session);
    });
  });

  group('completedThreshold', () {
    Future<int> completionsAt(
      WidgetTester tester,
      DwMediaConfig config,
      Duration position,
    ) async {
      var completed = 0;
      final session = open(
        [videoItem('a')],
        config: config,
        callbacks: DwMediaCallbacks(onCompleted: (_) => completed++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await session.play();
      await rig.playVideoTo(tester, position);
      await endSession(tester, session);
      return completed;
    }

    testWidgets('0.9 (default): 60 % is not completed', (tester) async {
      expect(
        await completionsAt(
          tester,
          const DwMediaConfig(),
          const Duration(seconds: 60),
        ),
        0,
      );
    });

    testWidgets('0.5: 60 % is completed', (tester) async {
      expect(
        await completionsAt(
          tester,
          const DwMediaConfig(completedThreshold: 0.5),
          const Duration(seconds: 60),
        ),
        1,
      );
    });
  });

  group('reachedEndTolerance', () {
    Future<int> reachedAt(WidgetTester tester, DwMediaConfig config) async {
      var reached = 0;
      final session = open(
        [videoItem('a')],
        config: config,
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 5));
      await rig.playVideoTo(
        tester,
        const Duration(seconds: 9, milliseconds: 800),
      );
      await endSession(tester, session);
      return reached;
    }

    testWidgets('500 ms (default): playback 200 ms before the end counts', (
      tester,
    ) async {
      expect(await reachedAt(tester, const DwMediaConfig()), 1);
    });

    testWidgets('zero: only the engine\'s own end event counts', (
      tester,
    ) async {
      expect(
        await reachedAt(
          tester,
          const DwMediaConfig(reachedEndTolerance: Duration.zero),
        ),
        0,
      );
    });
  });

  group('progressInterval', () {
    Future<int> reportsOverASecond(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      var reports = 0;
      final session = open(
        [videoItem('a')],
        config: config,
        callbacks: DwMediaCallbacks(onProgress: (_, _, _) => reports++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await session.play();
      for (var tenth = 1; tenth <= 10; tenth++) {
        await rig.playVideoTo(tester, Duration(milliseconds: 100 * tenth));
      }
      await endSession(tester, session);
      return reports;
    }

    testWidgets('1 s (default): one report in a second of playback', (
      tester,
    ) async {
      expect(await reportsOverASecond(tester, const DwMediaConfig()), 1);
    });

    testWidgets('200 ms: five reports in the same second', (tester) async {
      expect(
        await reportsOverASecond(
          tester,
          const DwMediaConfig(progressInterval: Duration(milliseconds: 200)),
        ),
        5,
      );
    });
  });

  group('speeds', () {
    testWidgets(
      'empty (default): the speed control is off — setSpeed refuses',
      (tester) async {
        final session = open([videoItem('a')]);
        await rig.loadVideo(tester);
        await expectLater(session.setSpeed(1.5), throwsArgumentError);
        expect(session.playback.value.speed, 1.0);
        expect(rig.video.latest.speed, 1.0);
        await endSession(tester, session);
      },
    );

    testWidgets('empty: the speed stays fixed at defaultSpeed', (tester) async {
      final session = open([
        videoItem('a'),
      ], config: const DwMediaConfig(defaultSpeed: 1.25));
      await rig.loadVideo(tester);
      await expectLater(session.setSpeed(1.25), throwsArgumentError);
      expect(session.playback.value.speed, 1.25);
      await endSession(tester, session);
    });

    test('a list must hold defaultSpeed — in the plugin config and in a '
        'session\'s resolved settings', () {
      expect(
        () => DwMediaSessionManager(
          config: const DwMediaConfig(speeds: [1.5, 2]),
        ),
        throwsAssertionError,
      );
      expect(
        () => const DwMediaConfig().merge(
          const DwMediaOpenOptions(speeds: [1.5, 2]),
        ),
        throwsAssertionError,
      );
      expect(
        const DwMediaConfig()
            .merge(
              const DwMediaOpenOptions(speeds: [1.5, 2], defaultSpeed: 1.5),
            )
            .defaultSpeed,
        1.5,
      );
    });

    testWidgets('a list: a listed speed is set, another is refused', (
      tester,
    ) async {
      final session = open([
        videoItem('a'),
      ], config: const DwMediaConfig(speeds: [1, 1.5, 2]));
      await rig.loadVideo(tester);
      await session.setSpeed(1.5);
      expect(session.playback.value.speed, 1.5);
      await expectLater(session.setSpeed(3), throwsArgumentError);
      expect(session.playback.value.speed, 1.5);
      await endSession(tester, session);
    });
  });

  group('defaultSpeed', () {
    testWidgets('1.0 (default)', (tester) async {
      final session = open([videoItem('a')]);
      await rig.loadVideo(tester);
      expect(session.playback.value.speed, 1.0);
      await endSession(tester, session);
    });

    testWidgets('1.25: the item starts at 1.25', (tester) async {
      final session = open([
        videoItem('a'),
      ], config: const DwMediaConfig(defaultSpeed: 1.25));
      await rig.loadVideo(tester);
      expect(session.playback.value.speed, 1.25);
      await endSession(tester, session);
    });
  });

  group('rememberSpeedAcrossItems', () {
    Future<double> speedOfSecond(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final session = open(
        [videoItem('a'), videoItem('b')],
        config: config,
        options: const DwMediaOpenOptions(speeds: [1, 1.5]),
      );
      await rig.loadVideo(tester);
      await session.setSpeed(1.5);
      await session.next(autoplay: false);
      await rig.loadVideo(tester);
      final speed = session.playback.value.speed;
      await endSession(tester, session);
      return speed;
    }

    testWidgets('on (default): the next item keeps 1.5', (tester) async {
      expect(await speedOfSecond(tester, const DwMediaConfig()), 1.5);
    });

    testWidgets('off: the next item starts at defaultSpeed', (tester) async {
      expect(
        await speedOfSecond(
          tester,
          const DwMediaConfig(rememberSpeedAcrossItems: false),
        ),
        1.0,
      );
    });
  });

  group('skipBack / skipForward', () {
    Future<List<Duration>> skips(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final session = open([videoItem('a')], config: config);
      await rig.loadVideo(tester, duration: const Duration(seconds: 100));
      await session.seek(const Duration(seconds: 50));
      await session.skipForward();
      await tester.pump();
      final forward = session.playback.value.position;
      await session.skipBack();
      await tester.pump();
      final back = session.playback.value.position;
      await endSession(tester, session);
      return [forward, back];
    }

    testWidgets('10 s each (default)', (tester) async {
      expect(await skips(tester, const DwMediaConfig()), [
        const Duration(seconds: 60),
        const Duration(seconds: 50),
      ]);
    });

    testWidgets('15 s forward, 5 s back', (tester) async {
      expect(
        await skips(
          tester,
          const DwMediaConfig(
            skipForward: Duration(seconds: 15),
            skipBack: Duration(seconds: 5),
          ),
        ),
        [const Duration(seconds: 65), const Duration(seconds: 60)],
      );
    });
  });

  group('singleActiveItem', () {
    Future<bool> firstStillPlaying(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final manager = DwMediaSessionManager(config: config);
      final first = manager.open(items: [videoItem('a')]);
      await rig.loadVideo(tester);
      await first.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final second = manager.open(items: [videoItem('b')]);
      await rig.loadVideo(tester);
      await second.play();
      await tester.pump(const Duration(milliseconds: 100));
      final playing = first.playback.value.isPlaying;
      await endSession(tester, first);
      await endSession(tester, second);
      return playing;
    }

    testWidgets('on (default): playing the second pauses the first', (
      tester,
    ) async {
      expect(await firstStillPlaying(tester, const DwMediaConfig()), isFalse);
    });

    testWidgets('off: both play', (tester) async {
      expect(
        await firstStillPlaying(
          tester,
          const DwMediaConfig(singleActiveItem: false),
        ),
        isTrue,
      );
    });
  });

  group('autoRetryCount', () {
    DwMediaItem flaky(int failures, List<int> attempts) => DwMediaItem(
      id: 'flaky',
      kind: DwMediaKind.video,
      source: DwMediaSource.resolve(() async {
        attempts.add(attempts.length + 1);
        if (attempts.length <= failures) throw StateError('link expired');
        return Uri.parse('https://example.com/fresh.mp4');
      }),
    );

    testWidgets('0 (default): the first failure is the error state', (
      tester,
    ) async {
      final attempts = <int>[];
      final session = open([flaky(1, attempts)]);
      await tester.pump(const Duration(seconds: 10));
      expect(session.playback.value.isError, isTrue);
      expect(attempts, hasLength(1));
      await endSession(tester, session);
    });

    testWidgets('2: two failures are retried away', (tester) async {
      final attempts = <int>[];
      final session = open([
        flaky(2, attempts),
      ], config: const DwMediaConfig(autoRetryCount: 2));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await rig.loadVideo(tester);
      expect(attempts, hasLength(3));
      expect(session.playback.value.isError, isFalse);
      await endSession(tester, session);
    });
  });

  group('autoRetryDelay', () {
    DwMediaItem failingOnce(List<int> attempts) => DwMediaItem(
      id: 'once',
      kind: DwMediaKind.video,
      source: DwMediaSource.resolve(() async {
        attempts.add(attempts.length + 1);
        if (attempts.length == 1) throw StateError('link expired');
        return Uri.parse('https://example.com/fresh.mp4');
      }),
    );

    testWidgets('3 s (default): no retry after 1 s', (tester) async {
      final attempts = <int>[];
      final session = open([
        failingOnce(attempts),
      ], config: const DwMediaConfig(autoRetryCount: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(attempts, hasLength(2));
      await endSession(tester, session);
    });

    testWidgets('200 ms: retried within the first second', (tester) async {
      final attempts = <int>[];
      final session = open(
        [failingOnce(attempts)],
        config: const DwMediaConfig(
          autoRetryCount: 1,
          autoRetryDelay: Duration(milliseconds: 200),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(attempts, hasLength(2));
      await endSession(tester, session);
    });
  });

  group('loadTimeout', () {
    DwMediaItem hanging(List<int> asked, {int hangs = 1}) => DwMediaItem(
      id: 'hanging',
      kind: DwMediaKind.video,
      source: DwMediaSource.resolve(() {
        asked.add(asked.length + 1);
        if (asked.length <= hangs) return Completer<Uri>().future;
        return Future.value(Uri.parse('https://example.com/fresh.mp4'));
      }),
    );

    testWidgets('30 s (default): a load that never settles is an error at '
        '30 s, and retry works after it', (tester) async {
      final asked = <int>[];
      Object? failure;
      final session = open([
        hanging(asked),
      ], callbacks: DwMediaCallbacks(onError: (_, error) => failure = error));
      await tester.pump(const Duration(seconds: 29));
      expect(session.playback.value.playState, DwMediaPlayState.loading);
      await tester.pump(const Duration(seconds: 1));
      expect(session.playback.value.isError, isTrue);
      expect(failure, isA<TimeoutException>());

      unawaited(session.retry());
      await rig.loadVideo(tester);
      expect(asked, [1, 2]);
      expect(session.playback.value.playState, DwMediaPlayState.ready);
      await endSession(tester, session);
    });

    testWidgets('5 s: the error comes at 5 s', (tester) async {
      final session = open([
        hanging([]),
      ], config: const DwMediaConfig(loadTimeout: Duration(seconds: 5)));
      await tester.pump(const Duration(seconds: 5));
      expect(session.playback.value.isError, isTrue);
      await endSession(tester, session);
    });

    testWidgets('a retry joined to a hanging reload settles at the timeout, '
        'and the next retry loads', (tester) async {
      final asked = <int>[];
      final session = open([
        hanging(asked, hangs: 2),
      ], config: const DwMediaConfig(loadTimeout: Duration(seconds: 5)));
      await tester.pump(const Duration(seconds: 5));
      expect(session.playback.value.isError, isTrue);
      var settled = 0;
      unawaited(session.retry().whenComplete(() => settled++));
      unawaited(session.retry().whenComplete(() => settled++));
      await tester.pump(const Duration(seconds: 1));
      expect(asked, [1, 2], reason: 'the second tap joined the first');
      await tester.pump(const Duration(seconds: 4));
      expect(settled, 2);
      expect(session.playback.value.isError, isTrue);
      unawaited(session.retry());
      await rig.loadVideo(tester);
      expect(asked, [1, 2, 3]);
      expect(session.playback.value.isError, isFalse);
      await endSession(tester, session);
    });

    testWidgets('a retry while the first load still hangs joins it: one '
        'load, one timeout, and the next retry loads', (tester) async {
      final asked = <int>[];
      Object? failure;
      final session = open(
        [hanging(asked)],
        config: const DwMediaConfig(loadTimeout: Duration(seconds: 5)),
        callbacks: DwMediaCallbacks(onError: (_, error) => failure = error),
      );
      await tester.pump(const Duration(seconds: 2));
      var settled = false;
      unawaited(session.retry().whenComplete(() => settled = true));
      await tester.pump(const Duration(seconds: 1));
      expect(asked, [1], reason: 'the retry joined the load in flight');
      await tester.pump(const Duration(seconds: 2));
      expect(settled, isTrue);
      expect(session.playback.value.isError, isTrue);
      expect(failure, isA<TimeoutException>());

      unawaited(session.retry());
      await rig.loadVideo(tester);
      expect(asked, [1, 2]);
      expect(session.playback.value.playState, DwMediaPlayState.ready);
      await endSession(tester, session);
    });

    testWidgets('withoutLoadTimeout: it waits for ever', (tester) async {
      final session = open([
        hanging([]),
      ], options: const DwMediaOpenOptions(withoutLoadTimeout: true));
      await tester.pump(const Duration(minutes: 10));
      expect(session.playback.value.playState, DwMediaPlayState.loading);
      await endSession(tester, session);
    });
  });

  group('controlsAutoHideDelay', () {
    Future<List<bool>> visibleAt(
      WidgetTester tester,
      DwMediaConfig config,
      List<Duration> checkpoints,
    ) async {
      final session = open([videoItem('a')], config: config);
      await rig.loadVideo(tester);
      final seen = [session.controlsVisible.value];
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      for (final wait in checkpoints) {
        await tester.pump(wait);
        seen.add(session.controlsVisible.value);
      }
      await session.pause();
      await tester.pump();
      seen.add(session.controlsVisible.value);
      await endSession(tester, session);
      return seen;
    }

    testWidgets('3 s (default): up until 3 s of playback, then hidden; '
        'back on pause', (tester) async {
      expect(
        await visibleAt(tester, const DwMediaConfig(), const [
          Duration(seconds: 2),
          Duration(seconds: 1),
        ]),
        [true, true, false, true],
      );
    });

    testWidgets('7 s: still up at 3 s', (tester) async {
      expect(
        await visibleAt(
          tester,
          const DwMediaConfig(controlsAutoHideDelay: Duration(seconds: 7)),
          const [Duration(seconds: 3), Duration(seconds: 4)],
        ),
        [true, true, false, true],
      );
    });

    testWidgets('zero: never hidden', (tester) async {
      expect(
        await visibleAt(
          tester,
          const DwMediaConfig(controlsAutoHideDelay: Duration.zero),
          const [Duration(seconds: 30)],
        ),
        [true, true, true],
      );
    });

    testWidgets('showControls brings them back for another delay; '
        'toggleControls hides shown ones', (tester) async {
      final session = open([videoItem('a')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(session.controlsVisible.value, isFalse);
      session.toggleControls();
      expect(session.controlsVisible.value, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(session.controlsVisible.value, isTrue);
      session.toggleControls();
      expect(session.controlsVisible.value, isFalse);
      await endSession(tester, session);
    });
  });

  group('DwMediaOpenOptions', () {
    testWidgets('overrides the plugin default for one session only', (
      tester,
    ) async {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(skipForward: Duration(seconds: 10)),
      );
      final custom = manager.open(
        items: [videoItem('a')],
        options: const DwMediaOpenOptions(skipForward: Duration(seconds: 30)),
      );
      final plain = manager.open(items: [videoItem('b')]);
      expect(custom.options.skipForward, const Duration(seconds: 30));
      expect(plain.options.skipForward, const Duration(seconds: 10));
      await endSession(tester, custom);
      await endSession(tester, plain);
    });

    test('every field of an override reaches the resolved settings', () {
      final store = DwMediaInMemoryPositionStore();
      Future<void> delivery(DwMediaPlaybackReport report) async {}
      Widget transition(
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondary,
        Widget child,
      ) => child;
      const policy = DwMediaResumePolicy(minimum: Duration(seconds: 9));
      final options = DwMediaOpenOptions(
        autoplayOnOpen: true,
        autoplayNext: true,
        autoplayCountdown: false,
        autoplayCountdownDuration: const Duration(seconds: 11),
        autoplayCountdownTick: const Duration(milliseconds: 250),
        nextPreview: true,
        nextPreviewLeadTime: const Duration(seconds: 12),
        completedThreshold: 0.5,
        reachedEndTolerance: const Duration(milliseconds: 750),
        progressInterval: const Duration(seconds: 2),
        resume: policy,
        speeds: const [0.5, 1],
        defaultSpeed: 0.5,
        rememberSpeedAcrossItems: false,
        skipBack: const Duration(seconds: 13),
        skipForward: const Duration(seconds: 14),
        fullscreen: false,
        fullscreenOrientations: const [DeviceOrientation.portraitDown],
        exitOrientations: const [DeviceOrientation.landscapeLeft],
        autoEnterFullscreenOnPlay: true,
        keepFullscreenAcrossItems: false,
        fullscreenTransitionDuration: const Duration(milliseconds: 450),
        fullscreenTransitionBuilder: transition,
        fallbackAspectRatio: 4 / 3,
        miniPlayer: false,
        miniPlayerInitialWidth: 200,
        miniPlayerInitialAlignment: Alignment.topLeft,
        miniPlayerMinWidth: 180,
        miniPlayerMaxWidthFraction: 0.4,
        miniPlayerResize: DwMiniPlayerResize.never,
        miniPlayerResizeHandleExtent: 44,
        miniPlayerSnapToEdges: true,
        miniPlayerSnapEdges: DwMiniPlayerSnapEdges.all,
        miniPlayerSnapThreshold: 40,
        miniPlayerCloseStopsPlayback: false,
        onLeaveWithoutMiniPlayer: DwMediaLeaveAction.stop,
        pauseVideoInBackground: false,
        backgroundAudio: true,
        wakelockWhilePlaying: false,
        singleActiveItem: false,
        webMutedStart: false,
        rememberSound: false,
        autoRetryCount: 4,
        autoRetryDelay: const Duration(seconds: 15),
        loadTimeout: const Duration(seconds: 17),
        controlsAutoHideDelay: const Duration(seconds: 16),
        positionStore: store,
        playbackDelivery: delivery,
      );
      final r = const DwMediaConfig().merge(options);
      expect(r.autoplayOnOpen, isTrue);
      expect(r.autoplayNext, isTrue);
      expect(r.autoplayCountdown, isFalse);
      expect(r.autoplayCountdownDuration, const Duration(seconds: 11));
      expect(r.autoplayCountdownTick, const Duration(milliseconds: 250));
      expect(r.nextPreview, isTrue);
      expect(r.nextPreviewLeadTime, const Duration(seconds: 12));
      expect(r.completedThreshold, 0.5);
      expect(r.reachedEndTolerance, const Duration(milliseconds: 750));
      expect(r.progressInterval, const Duration(seconds: 2));
      expect(r.resume, same(policy));
      expect(r.speeds, [0.5, 1]);
      expect(r.defaultSpeed, 0.5);
      expect(r.rememberSpeedAcrossItems, isFalse);
      expect(r.skipBack, const Duration(seconds: 13));
      expect(r.skipForward, const Duration(seconds: 14));
      expect(r.fullscreen, isFalse);
      expect(r.fullscreenOrientations, [DeviceOrientation.portraitDown]);
      expect(r.exitOrientations, [DeviceOrientation.landscapeLeft]);
      expect(r.autoEnterFullscreenOnPlay, isTrue);
      expect(r.keepFullscreenAcrossItems, isFalse);
      expect(r.fullscreenTransitionDuration, const Duration(milliseconds: 450));
      expect(r.fullscreenTransitionBuilder, same(transition));
      expect(r.fallbackAspectRatio, 4 / 3);
      expect(r.miniPlayer, isFalse);
      expect(r.miniPlayerInitialWidth, 200);
      expect(r.miniPlayerInitialAlignment, Alignment.topLeft);
      expect(r.miniPlayerMinWidth, 180);
      expect(r.miniPlayerMaxWidthFraction, 0.4);
      expect(r.miniPlayerResize, DwMiniPlayerResize.never);
      expect(r.miniPlayerResizeHandleExtent, 44);
      expect(r.miniPlayerSnapToEdges, isTrue);
      expect(r.miniPlayerSnapEdges, DwMiniPlayerSnapEdges.all);
      expect(r.miniPlayerSnapThreshold, 40);
      expect(r.miniPlayerCloseStopsPlayback, isFalse);
      expect(r.onLeaveWithoutMiniPlayer, DwMediaLeaveAction.stop);
      expect(r.pauseVideoInBackground, isFalse);
      expect(r.backgroundAudio, isTrue);
      expect(r.wakelockWhilePlaying, isFalse);
      expect(r.singleActiveItem, isFalse);
      expect(r.webMutedStart, isFalse);
      expect(r.rememberSound, isFalse);
      expect(r.autoRetryCount, 4);
      expect(r.autoRetryDelay, const Duration(seconds: 15));
      expect(r.loadTimeout, const Duration(seconds: 17));
      expect(r.controlsAutoHideDelay, const Duration(seconds: 16));
      expect(r.positionStore, same(store));
      expect(r.playbackDelivery, same(delivery));
      expect(
        DwMediaConfig(playbackDelivery: delivery)
            .merge(const DwMediaOpenOptions(withoutPlaybackDelivery: true))
            .playbackDelivery,
        isNull,
      );

      expect(
        const DwMediaConfig()
            .merge(const DwMediaOpenOptions(withoutResume: true))
            .resume,
        isNull,
      );
      expect(
        const DwMediaConfig()
            .merge(const DwMediaOpenOptions(withoutLoadTimeout: true))
            .loadTimeout,
        isNull,
      );
    });
  });
}
