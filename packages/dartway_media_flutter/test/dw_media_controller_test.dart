import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'support/fake_wakelock_platform.dart';
import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());
  tearDown(() => debugDwMediaIsWebOverride = null);

  group('states', () {
    testWidgets('video: loading, ready, playing, paused', (tester) async {
      final controller = controllerFor(videoItem('v'));
      expect(controller.state.value.playState, DwMediaPlayState.loading);
      await rig.loadVideo(tester, duration: const Duration(seconds: 30));
      expect(controller.state.value.playState, DwMediaPlayState.ready);
      expect(controller.state.value.duration, const Duration(seconds: 30));
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(controller.state.value.playState, DwMediaPlayState.playing);
      await controller.pause();
      await tester.pump();
      expect(controller.state.value.playState, DwMediaPlayState.paused);
      await release(tester, controller);
    });

    testWidgets('audio: loading, ready, playing', (tester) async {
      final controller = controllerFor(audioItem('a'));
      expect(controller.state.value.playState, DwMediaPlayState.loading);
      await rig.loadAudio(tester);
      expect(controller.state.value.playState, DwMediaPlayState.ready);
      expect(controller.state.value.duration, const Duration(seconds: 100));
      await controller.play();
      await tester.pump();
      expect(controller.state.value.playState, DwMediaPlayState.playing);
      await release(tester, controller);
    });

    testWidgets('play() before the item loaded plays once it has', (
      tester,
    ) async {
      final controller = controllerFor(videoItem('v'));
      await controller.play();
      expect(controller.wantsToPlay, isTrue);
      await rig.loadVideo(tester);
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(controller.state.value.isPlaying, isTrue);
      expect(controller.wantsToPlay, isFalse);
      await release(tester, controller);
    });
  });

  group('onStarted and onProgress need real playback', () {
    testWidgets('fires once, when the position moves while playing', (
      tester,
    ) async {
      var started = 0;
      final controller = controllerFor(
        videoItem('v'),
        callbacks: DwMediaCallbacks(onStarted: (_) => started++),
      );
      await rig.loadVideo(tester);
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(started, 1);
      await controller.pause();
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      expect(started, 1);
      await release(tester, controller);
    });

    testWidgets('a play that never moves — what a refused web play looks like '
        'to video_player — reads as playing, yet starts nothing', (
      tester,
    ) async {
      var started = 0;
      var progress = 0;
      final controller = controllerFor(
        videoItem('v'),
        callbacks: DwMediaCallbacks(
          onStarted: (_) => started++,
          onProgress: (_, _, _) => progress++,
        ),
      );
      await rig.loadVideo(tester);
      await controller.play();
      // video_player polls the platform every 100 ms; the position stays.
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state.value.isPlaying, isTrue);
      expect(started, 0);
      expect(progress, 0);
      await release(tester, controller);
    });
  });

  group('onReachedEnd needs real playback to the end', () {
    Future<int> videoEndings(
      WidgetTester tester,
      Future<void> Function(DwMediaController controller) script,
    ) async {
      var reached = 0;
      final controller = controllerFor(
        videoItem('v'),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await script(controller);
      await release(tester, controller);
      return reached;
    }

    testWidgets('video: a scrub to the end, then a mute tick, does not count', (
      tester,
    ) async {
      expect(
        await videoEndings(tester, (controller) async {
          await controller.seek(const Duration(seconds: 10));
          await tester.pump();
          expect(controller.state.value.isEnded, isTrue);
          await controller.setMuted(true);
          await tester.pump();
        }),
        0,
      );
    });

    testWidgets('video: play, pause, seek to the end does not count', (
      tester,
    ) async {
      expect(
        await videoEndings(tester, (controller) async {
          await controller.play();
          await rig.playVideoTo(tester, const Duration(seconds: 3));
          await controller.pause();
          await tester.pump();
          await controller.seek(const Duration(seconds: 10));
          await tester.pump();
          rig.video.latest.finish();
          await tester.pump();
        }),
        0,
      );
    });

    testWidgets('video: play, pause, seek near the end, then the platform '
        'reports completed — no playback since the seek, no end', (
      tester,
    ) async {
      expect(
        await videoEndings(tester, (controller) async {
          await controller.play();
          await rig.playVideoTo(tester, const Duration(seconds: 3));
          await controller.pause();
          await tester.pump();
          await controller.seek(const Duration(seconds: 9, milliseconds: 900));
          await tester.pump();
          rig.video.latest.finish();
          await tester.pump();
        }),
        0,
      );
    });

    testWidgets('video: a scrub to the end while playing does not count', (
      tester,
    ) async {
      expect(
        await videoEndings(tester, (controller) async {
          await controller.play();
          await rig.playVideoTo(tester, const Duration(seconds: 2));
          await controller.seek(const Duration(seconds: 10));
          await tester.pump(const Duration(milliseconds: 300));
          rig.video.latest.finish();
          await tester.pump();
        }),
        0,
      );
    });

    testWidgets('video: playback reaching the end counts, once', (
      tester,
    ) async {
      expect(
        await videoEndings(tester, (controller) async {
          await controller.play();
          await rig.playVideoTo(tester, const Duration(seconds: 9));
          rig.video.latest.finish();
          await tester.pump();
          rig.video.latest.finish();
          await tester.pump();
          expect(controller.endedByPlayback, isTrue);
        }),
        1,
      );
    });

    Future<int> audioEndings(
      WidgetTester tester,
      Future<void> Function(DwMediaController, DwFakeAudio) script,
    ) async {
      var reached = 0;
      final controller = controllerFor(
        audioItem('a'),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      final track = await rig.loadAudio(tester);
      await script(controller, track);
      await release(tester, controller);
      return reached;
    }

    testWidgets('audio: a paused seek to the end (the Android quirk), and a '
        'late completed after it, do not count', (tester) async {
      expect(
        await audioEndings(tester, (controller, track) async {
          await controller.seek(const Duration(seconds: 100));
          await dwSettleMedia(tester);
          track.finish();
          await dwSettleMedia(tester);
        }),
        0,
      );
    });

    testWidgets('audio: play, pause, seek to the end does not count', (
      tester,
    ) async {
      expect(
        await audioEndings(tester, (controller, track) async {
          await controller.play();
          await dwSettleMedia(tester);
          track.advanceTo(const Duration(seconds: 30));
          await dwSettleMedia(tester);
          // just_audio's pause completes outside the fake clock.
          unawaited(controller.pause());
          await dwSettleMedia(tester);
          await controller.seek(const Duration(seconds: 100));
          await dwSettleMedia(tester);
        }),
        0,
      );
    });

    testWidgets('audio: playback reaching the end counts', (tester) async {
      expect(
        await audioEndings(tester, (controller, track) async {
          await controller.play();
          await dwSettleMedia(tester);
          track.advanceTo(const Duration(seconds: 50));
          await dwSettleMedia(tester);
          track.finish();
          await dwSettleMedia(tester);
        }),
        1,
      );
    });
  });

  testWidgets('onCompleted counts a seek past the threshold', (tester) async {
    var completed = 0;
    final controller = controllerFor(
      videoItem('v'),
      callbacks: DwMediaCallbacks(onCompleted: (_) => completed++),
    );
    await rig.loadVideo(tester, duration: const Duration(seconds: 10));
    await controller.seek(const Duration(seconds: 8));
    await tester.pump();
    expect(completed, 0);
    await controller.seek(const Duration(seconds: 9, milliseconds: 500));
    await tester.pump();
    await controller.seek(const Duration(seconds: 9, milliseconds: 600));
    await tester.pump();
    expect(completed, 1);
    await release(tester, controller);
  });

  group('failures and retry', () {
    DwMediaItem signed(DwMediaKind kind, List<int> asked) => DwMediaItem(
      id: 'signed',
      kind: kind,
      source: DwMediaSource.resolve(() async {
        asked.add(asked.length + 1);
        return Uri.parse('https://example.com/signed-${asked.length}');
      }),
    );

    testWidgets('video: retry asks for the link again and returns to the '
        'position', (tester) async {
      final asked = <int>[];
      Object? failure;
      final controller = controllerFor(
        signed(DwMediaKind.video, asked),
        callbacks: DwMediaCallbacks(onError: (_, error) => failure = error),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 20));
      rig.video.latest.fail('link expired');
      await tester.pump();
      expect(controller.state.value.isError, isTrue);
      expect(failure, isNotNull);

      unawaited(controller.retry());
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      expect(asked, [1, 2]);
      expect(rig.video.latest.uri, 'https://example.com/signed-2');
      expect(controller.state.value.isError, isFalse);
      expect(controller.state.value.position, const Duration(seconds: 20));
      await release(tester, controller);
    });

    testWidgets('audio: retry asks for the link again and returns to the '
        'position', (tester) async {
      final asked = <int>[];
      final controller = controllerFor(signed(DwMediaKind.audio, asked));
      final track = await rig.loadAudio(tester);
      await controller.play();
      await dwSettleMedia(tester);
      track.advanceTo(const Duration(seconds: 40));
      await dwSettleMedia(tester);
      track.fail('link expired');
      await dwSettleMedia(tester);
      expect(controller.state.value.isError, isTrue);

      unawaited(controller.retry());
      await dwSettleMedia(tester, rounds: 12);
      expect(asked, [1, 2]);
      expect(rig.audio.latest.uri, 'https://example.com/signed-2');
      expect(controller.state.value.isError, isFalse);
      expect(controller.state.value.position, const Duration(seconds: 40));
      await release(tester, controller);
    });

    testWidgets('retry shows loading at once, and a second tap while it runs '
        'does not load again', (tester) async {
      final late = MediaRig(readyOnOpen: false);
      final asked = <int>[];
      final controller = controllerFor(signed(DwMediaKind.video, asked));
      await late.loadVideo(tester);
      late.video.latest.fail('link expired');
      await tester.pump();
      expect(controller.state.value.isError, isTrue);

      unawaited(controller.retry());
      expect(controller.state.value.playState, DwMediaPlayState.loading);
      await tester.pump();
      unawaited(controller.retry());
      await tester.pump();
      expect(controller.state.value.playState, DwMediaPlayState.loading);
      expect(asked, [1, 2], reason: 'the second tap joined the first');
      expect(late.video.opened, hasLength(2));

      late.video.latest.ready();
      await tester.pump();
      await tester.pump();
      expect(controller.state.value.playState, DwMediaPlayState.ready);
      await release(tester, controller);
    });

    testWidgets('a resolver that throws shows the error inside the player', (
      tester,
    ) async {
      final controller = controllerFor(
        DwMediaItem(
          id: 'broken',
          kind: DwMediaKind.video,
          source: DwMediaSource.resolve(() async => throw StateError('gone')),
        ),
      );
      await tester.pump();
      expect(controller.state.value.isError, isTrue);
      expect(controller.state.value.errorMessage, contains('gone'));
      await release(tester, controller);
    });

    testWidgets('audio: a failure after loading reaches the error state', (
      tester,
    ) async {
      Object? failure;
      final controller = controllerFor(
        audioItem('a'),
        callbacks: DwMediaCallbacks(onError: (_, error) => failure = error),
      );
      final track = await rig.loadAudio(tester);
      track.fail('network dropped');
      await dwSettleMedia(tester);
      expect(controller.state.value.isError, isTrue);
      expect(failure, isNotNull);
      await release(tester, controller);
    });

    Future<(DwMediaPlaybackState, Object?)> abortedSeek(
      WidgetTester tester, {
      required bool web,
    }) async {
      debugDwMediaIsWebOverride = web;
      Object? failure;
      final controller = controllerFor(
        videoItem('v'),
        callbacks: DwMediaCallbacks(onError: (_, error) => failure = error),
      );
      final video = await rig.loadVideo(tester);
      video.refuseSeekWith = PlatformException(
        code: 'AbortError',
        message: 'The operation was aborted.',
      );
      await controller.seek(const Duration(seconds: 5));
      await tester.pump();
      final state = controller.state.value;
      await release(tester, controller);
      return (state, failure);
    }

    testWidgets('on the web, a seek the browser aborted is not an error', (
      tester,
    ) async {
      final (state, failure) = await abortedSeek(tester, web: true);
      expect(state.isError, isFalse);
      expect(failure, isNull);
    });

    testWidgets('off the web, the same failure is an error and reported', (
      tester,
    ) async {
      final (state, failure) = await abortedSeek(tester, web: false);
      expect(state.isError, isTrue);
      expect(failure, isA<PlatformException>());
    });

    testWidgets('a message merely mentioning "interrupted" is an error even '
        'on the web', (tester) async {
      debugDwMediaIsWebOverride = true;
      final controller = controllerFor(videoItem('v'));
      final video = await rig.loadVideo(tester);
      video.refuseSeekWith = PlatformException(
        code: 'MEDIA_ERR_NETWORK',
        message: 'download interrupted',
      );
      await controller.seek(const Duration(seconds: 5));
      await tester.pump();
      expect(controller.state.value.isError, isTrue);
      await release(tester, controller);
    });

    Future<DwMediaPlaybackState> refusedPlay(
      WidgetTester tester, {
      required bool web,
    }) async {
      debugDwMediaIsWebOverride = web;
      final controller = controllerFor(videoItem('v'));
      final video = await rig.loadVideo(tester);
      video.refusePlayWith = PlatformException(
        code: 'NotAllowedError',
        message: 'play() failed because the user did not interact first.',
      );
      await controller.play();
      await tester.pump();
      final state = controller.state.value;
      await release(tester, controller);
      return state;
    }

    testWidgets('on the web, a refused play leaves the item paused', (
      tester,
    ) async {
      final state = await refusedPlay(tester, web: true);
      expect(state.isError, isFalse);
      expect(state.isPlaying, isFalse);
    });

    testWidgets('off the web, a refused play is an error', (tester) async {
      expect((await refusedPlay(tester, web: false)).isError, isTrue);
    });

    testWidgets('a failing video releases the wakelock', (tester) async {
      final wakelock = FakeWakelockPlatform();
      wakelockPlusPlatformInstance = wakelock;
      final controller = controllerFor(videoItem('v'));
      await rig.loadVideo(tester);
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(wakelock.isEnabled, isTrue);
      rig.video.latest.fail('decoder died');
      await tester.pump();
      expect(controller.state.value.isError, isTrue);
      expect(wakelock.isEnabled, isFalse);
      await release(tester, controller);
    });
  });

  testWidgets('volume and mute round-trip through the state', (tester) async {
    final controller = controllerFor(videoItem('v'));
    await rig.loadVideo(tester);
    await controller.setVolume(0.4);
    expect(controller.state.value.volume, 0.4);
    expect(rig.video.latest.volume, 0.4);
    await controller.setMuted(true);
    expect(controller.state.value.muted, isTrue);
    await controller.setMuted(false);
    expect(controller.state.value.volume, 0.4);
    await release(tester, controller);
  });

  testWidgets('seek and skip stay within [0, duration]', (tester) async {
    final controller = controllerFor(videoItem('v'));
    await rig.loadVideo(tester, duration: const Duration(seconds: 10));
    await controller.skip(const Duration(seconds: 100));
    await tester.pump();
    expect(controller.state.value.position, const Duration(seconds: 10));
    await controller.skip(const Duration(seconds: -100));
    await tester.pump();
    expect(controller.state.value.position, Duration.zero);
    await release(tester, controller);
  });
}
