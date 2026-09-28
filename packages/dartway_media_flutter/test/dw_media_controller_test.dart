import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());

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
      await rig.loadVideo(tester);
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(controller.state.value.isPlaying, isTrue);
      await release(tester, controller);
    });
  });

  group('onStarted needs real playback', () {
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
      await tester.pump();
      expect(started, 0, reason: 'playing, but nothing has played yet');
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(started, 1);
      await controller.pause();
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      expect(started, 1);
      await release(tester, controller);
    });

    testWidgets('a play the browser refused is not a start', (tester) async {
      final refusing = _RefusingVideoPlatform(initializeOnCreate: false);
      VideoPlayerPlatform.instance = refusing;
      var started = 0;
      final controller = controllerFor(
        videoItem('v'),
        callbacks: DwMediaCallbacks(onStarted: (_) => started++),
      );
      await tester.pump();
      refusing.emitInitialized(
        refusing.livePlayers.single,
        duration: const Duration(seconds: 30),
      );
      await tester.pump();
      await tester.pump();
      await controller.play();
      await tester.pump(const Duration(milliseconds: 300));
      expect(started, 0);
      expect(controller.state.value.isPlaying, isFalse);
      expect(controller.state.value.isError, isFalse);
      await release(tester, controller);
    });
  });

  group('onReachedEnd needs real playback to the end', () {
    testWidgets('video: a scrub to the end does not count, nor does a later '
        'tick', (tester) async {
      var reached = 0;
      final controller = controllerFor(
        videoItem('v'),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await controller.seek(const Duration(seconds: 10));
      await tester.pump();
      expect(controller.state.value.isEnded, isTrue);
      await controller.setMuted(true);
      await tester.pump();
      expect(reached, 0);
      await release(tester, controller);
    });

    testWidgets('video: a scrub to the end while playing does not count', (
      tester,
    ) async {
      var reached = 0;
      final controller = controllerFor(
        videoItem('v'),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      await controller.seek(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 300));
      rig.video.emitCompleted(rig.lastVideo);
      await tester.pump();
      expect(reached, 0);
      await release(tester, controller);
    });

    testWidgets('video: playback reaching the end counts, once', (
      tester,
    ) async {
      var reached = 0;
      final controller = controllerFor(
        videoItem('v'),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 9));
      rig.video.emitCompleted(rig.lastVideo);
      await tester.pump();
      rig.video.emitCompleted(rig.lastVideo);
      await tester.pump();
      expect(reached, 1);
      await release(tester, controller);
    });

    testWidgets('audio: a paused seek to the end (the Android quirk) does '
        'not count', (tester) async {
      var reached = 0;
      final controller = controllerFor(
        audioItem('a'),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      final player = await rig.loadAudio(tester);
      await controller.seek(const Duration(seconds: 100));
      await dwSettleMedia(tester);
      player.emitCompleted();
      await dwSettleMedia(tester);
      expect(reached, 0);
      await release(tester, controller);
    });

    testWidgets('audio: playback reaching the end counts', (tester) async {
      var reached = 0;
      final controller = controllerFor(
        audioItem('a'),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reached++),
      );
      final player = await rig.loadAudio(tester);
      await controller.play();
      await dwSettleMedia(tester);
      player.emitPosition(const Duration(seconds: 50));
      await dwSettleMedia(tester);
      player.emitCompleted();
      await dwSettleMedia(tester);
      expect(reached, 1);
      await release(tester, controller);
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

  group('failures', () {
    testWidgets('retry re-resolves the source and returns to the position', (
      tester,
    ) async {
      var resolved = 0;
      final item = DwMediaItem(
        id: 'signed',
        kind: DwMediaKind.video,
        source: DwMediaSource.resolve(() async {
          resolved++;
          return Uri.parse('https://example.com/signed-$resolved.mp4');
        }),
      );
      Object? failure;
      final controller = controllerFor(
        item,
        callbacks: DwMediaCallbacks(onError: (_, error) => failure = error),
      );
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      await controller.play();
      await rig.playVideoTo(tester, const Duration(seconds: 20));
      rig.video.emitError(rig.lastVideo, 'link expired');
      await tester.pump();
      expect(controller.state.value.isError, isTrue);
      expect(failure, isNotNull);

      // Not awaited: `retry()` completes once the new link has loaded, and
      // this platform loads only when the test says so, below.
      unawaited(controller.retry());
      await rig.loadVideo(tester, duration: const Duration(seconds: 60));
      expect(resolved, 2, reason: 'the resolver was asked for a fresh link');
      expect(controller.state.value.isError, isFalse);
      expect(controller.state.value.position, const Duration(seconds: 20));
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
      final player = await rig.loadAudio(tester);
      player.emitError('network dropped');
      await dwSettleMedia(tester);
      expect(controller.state.value.isError, isTrue);
      expect(failure, isNotNull);
      await release(tester, controller);
    });

    testWidgets('a benign browser error is not an error state', (tester) async {
      final aborting = _AbortingSeekVideoPlatform(initializeOnCreate: false);
      VideoPlayerPlatform.instance = aborting;
      final controller = controllerFor(videoItem('v'));
      await tester.pump();
      aborting.emitInitialized(
        aborting.livePlayers.single,
        duration: const Duration(seconds: 30),
      );
      await tester.pump();
      await tester.pump();
      await controller.seek(const Duration(seconds: 5));
      await tester.pump();
      expect(controller.state.value.isError, isFalse);
      await release(tester, controller);
    });
  });

  testWidgets('speed, volume and mute round-trip through the state', (
    tester,
  ) async {
    final controller = controllerFor(videoItem('v'));
    await rig.loadVideo(tester);
    await controller.setSpeed(1.5);
    expect(controller.state.value.speed, 1.5);
    await controller.setVolume(0.4);
    expect(controller.state.value.volume, 0.4);
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

/// A browser refusing `play()` without a gesture.
final class _RefusingVideoPlatform extends DwFakeVideoPlayerPlatform {
  _RefusingVideoPlatform({super.initializeOnCreate});

  @override
  Future<void> play(int playerId) async => throw PlatformException(
    code: 'NotAllowedError',
    message:
        'NotAllowedError: play() failed because the user did not '
        'interact with the document first.',
  );
}

/// A browser aborting a seek interrupted by the next one.
final class _AbortingSeekVideoPlatform extends DwFakeVideoPlayerPlatform {
  _AbortingSeekVideoPlatform({super.initializeOnCreate});

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      throw PlatformException(
        code: 'AbortError',
        message: 'AbortError: The operation was aborted.',
      );
}
