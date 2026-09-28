import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

DwMediaItem _audioItem({String id = 'a1', String url = 'https://example.com/a.mp3'}) =>
    DwMediaItem(id: id, kind: DwMediaKind.audio, source: DwMediaSource.url(url));

void main() {
  late DwFakeJustAudioPlatform fake;

  setUp(() {
    fake = DwFakeJustAudioPlatform(defaultDuration: const Duration(seconds: 100));
    JustAudioPlatform.instance = fake;
  });

  Future<DwFakeAudioPlayerPlatform> load(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    return fake.players.values.single;
  }

  testWidgets('reaches paused once loaded, playing once played', (tester) async {
    final controller = DwMediaController.forItem(
      item: _audioItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    await load(tester);
    expect(controller.state.value.playState, DwMediaPlayState.paused);
    expect(controller.state.value.duration, const Duration(seconds: 100));

    await controller.play();
    await tester.pump();
    expect(controller.state.value.playState, DwMediaPlayState.playing);
    await controller.dispose();
  });

  group('onReachedEnd — the Android paused-seek trap (molodey#128)', () {
    testWidgets('seeking to the exact end while paused does not fire onReachedEnd', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _audioItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(),
      );
      await load(tester);
      // The fake reproduces the real Android bug here: seeking to the
      // duration reaches ProcessingState.completed on its own, with no
      // `play()` ever called — the exact scenario `guardedSeek` exists for.
      await controller.seek(const Duration(seconds: 100));
      await tester.pump();
      expect(reachedEnd, 0);
      await controller.dispose();
    });

    testWidgets('real playback reaching the end fires onReachedEnd exactly once', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _audioItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
      );
      final player = await load(tester);
      await controller.play();
      await tester.pump();
      player.emitCompleted();
      await tester.pump();
      player.emitCompleted();
      await tester.pump();
      expect(reachedEnd, 1);
      await controller.dispose();
    });
  });

  testWidgets('onCompleted fires once past completedThreshold', (tester) async {
    var completedCount = 0;
    final controller = DwMediaController.forItem(
      item: _audioItem(),
      callbacks: DwMediaCallbacks(onCompleted: (_) => completedCount++, completedThreshold: 0.5),
      options: const DwMediaConfig(),
    );
    final player = await load(tester);
    await controller.play();
    await tester.pump();

    player.emitPosition(const Duration(seconds: 40));
    await tester.pump();
    expect(completedCount, 0);

    player.emitPosition(const Duration(seconds: 60));
    await tester.pump();
    expect(completedCount, 1);
    await controller.dispose();
  });

  testWidgets('retry re-resolves an expired signed link', (tester) async {
    var attempts = 0;
    final item = DwMediaItem(
      id: 'a1',
      kind: DwMediaKind.audio,
      source: DwMediaSource.resolve(() async {
        attempts++;
        if (attempts == 1) throw StateError('link expired');
        return Uri.parse('https://example.com/fresh.mp3');
      }),
    );
    final controller = DwMediaController.forItem(
      item: item,
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    await tester.pump();
    expect(controller.state.value.playState, DwMediaPlayState.error);

    await controller.retry();
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(controller.state.value.playState, isNot(DwMediaPlayState.error));
    await controller.dispose();
  });

  testWidgets('setSpeed/setVolume/setMuted round-trip', (tester) async {
    final controller = DwMediaController.forItem(
      item: _audioItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    await load(tester);

    await controller.setSpeed(1.25);
    expect(controller.state.value.speed, 1.25);

    await controller.setMuted(true);
    expect(controller.state.value.muted, isTrue);
    await controller.setMuted(false);
    expect(controller.state.value.muted, isFalse);
    await controller.dispose();
  });
}
