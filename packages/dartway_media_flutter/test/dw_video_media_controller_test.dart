import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

DwMediaItem _videoItem({String id = 'v1', String url = 'https://example.com/a.mp4'}) =>
    DwMediaItem(id: id, kind: DwMediaKind.video, source: DwMediaSource.url(url));

void main() {
  late DwFakeVideoPlayerPlatform fake;

  setUp(() {
    fake = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  Future<int> loadAndInit(
    WidgetTester tester,
    DwMediaController controller, {
    Duration duration = const Duration(seconds: 100),
  }) async {
    await tester.pump();
    final playerId = fake.livePlayers.single;
    fake.emitInitialized(playerId, duration: duration);
    await tester.pump();
    return playerId;
  }

  testWidgets('reports loading, then paused once initialized, then playing', (tester) async {
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    expect(controller.state.value.playState, DwMediaPlayState.loading);
    await loadAndInit(tester, controller);
    expect(controller.state.value.playState, DwMediaPlayState.paused);
    expect(controller.state.value.duration, const Duration(seconds: 100));

    await controller.play();
    await tester.pump();
    expect(controller.state.value.playState, DwMediaPlayState.playing);

    await controller.pause();
    await tester.pump();
    expect(controller.state.value.playState, DwMediaPlayState.paused);
    await controller.dispose();
  });

  testWidgets('onStarted fires once, on the first real play', (tester) async {
    var startedCount = 0;
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: DwMediaCallbacks(onStarted: (_) => startedCount++),
      options: const DwMediaConfig(),
    );
    await loadAndInit(tester, controller);
    await controller.play();
    await tester.pump();
    await controller.pause();
    await controller.play();
    await tester.pump();
    expect(startedCount, 1);
    await controller.dispose();
  });

  testWidgets('onProgress is throttled to progressInterval', (tester) async {
    final positions = <Duration>[];
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: DwMediaCallbacks(
        onProgress: (item, position, duration) => positions.add(position),
        progressInterval: const Duration(seconds: 1),
      ),
      options: const DwMediaConfig(),
    );
    final playerId = await loadAndInit(tester, controller);
    await controller.play();
    await tester.pump();
    expect(positions, hasLength(1), reason: 'the first playing tick always reports progress');

    fake.setPosition(playerId, const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(positions, hasLength(1), reason: 'under progressInterval since the last report');

    fake.setPosition(playerId, const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(positions.length, greaterThanOrEqualTo(2));
    await controller.dispose();
  });

  group('onReachedEnd — the isCompleted trap', () {
    testWidgets('a scrub to the exact end does not fire onReachedEnd', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _videoItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
      );
      await loadAndInit(tester, controller, duration: const Duration(seconds: 10));
      await controller.seek(const Duration(seconds: 10));
      await tester.pump();
      expect(controller.state.value.position, const Duration(seconds: 10));
      expect(reachedEnd, 0);
      await controller.dispose();
    });

    testWidgets('the engine\'s own completed event fires onReachedEnd exactly once', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _videoItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
      );
      final playerId = await loadAndInit(tester, controller, duration: const Duration(seconds: 10));
      await controller.play();
      await tester.pump();
      fake.emitCompleted(playerId);
      await tester.pump();
      fake.emitCompleted(playerId);
      await tester.pump();
      expect(reachedEnd, 1);
      await controller.dispose();
    });

    testWidgets('reachedEndTolerance lets real, still-playing ticks near the end count', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _videoItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(
          reachedEndTolerance: Duration(milliseconds: 500),
        ),
      );
      final playerId = await loadAndInit(tester, controller, duration: const Duration(seconds: 10));
      await controller.play();
      await tester.pump();
      fake.setPosition(playerId, const Duration(seconds: 9, milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
      expect(reachedEnd, 1);
      await controller.dispose();
    });

    testWidgets('with tolerance zero, a near-but-not-exact position does not count', (tester) async {
      var reachedEnd = 0;
      final controller = DwMediaController.forItem(
        item: _videoItem(),
        callbacks: DwMediaCallbacks(onReachedEnd: (_) => reachedEnd++),
        options: const DwMediaConfig(reachedEndTolerance: Duration.zero),
      );
      final playerId = await loadAndInit(tester, controller, duration: const Duration(seconds: 10));
      await controller.play();
      await tester.pump();
      fake.setPosition(playerId, const Duration(seconds: 9, milliseconds: 999));
      await tester.pump(const Duration(milliseconds: 100));
      expect(reachedEnd, 0);
      await controller.dispose();
    });
  });

  testWidgets('onCompleted fires once past completedThreshold', (tester) async {
    var completedCount = 0;
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: DwMediaCallbacks(
        onCompleted: (_) => completedCount++,
        completedThreshold: 0.9,
      ),
      options: const DwMediaConfig(),
    );
    final playerId = await loadAndInit(tester, controller, duration: const Duration(seconds: 10));
    await controller.play();
    await tester.pump();

    fake.setPosition(playerId, const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completedCount, 0);

    fake.setPosition(playerId, const Duration(seconds: 9, milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completedCount, 1);

    fake.setPosition(playerId, const Duration(seconds: 9, milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completedCount, 1, reason: 'fires once, not on every later tick past threshold');
    await controller.dispose();
  });

  testWidgets('retry re-resolves the source and recovers from a failed resolve', (tester) async {
    var attempt = 0;
    final item = DwMediaItem(
      id: 'v1',
      kind: DwMediaKind.video,
      source: DwMediaSource.resolve(() async {
        attempt++;
        if (attempt == 1) throw StateError('link expired');
        return Uri.parse('https://example.com/fresh-$attempt.mp4');
      }),
    );
    Object? lastError;
    final controller = DwMediaController.forItem(
      item: item,
      callbacks: DwMediaCallbacks(onError: (_, error) => lastError = error),
      options: const DwMediaConfig(),
    );
    await tester.pump();
    expect(controller.state.value.playState, DwMediaPlayState.error);
    expect(lastError, isNotNull);

    await controller.retry();
    await tester.pump();
    expect(attempt, 2);
    expect(controller.state.value.playState, isNot(DwMediaPlayState.error));
    await controller.dispose();
  });

  testWidgets('autoRetryCount retries a failing load before surfacing the error', (tester) async {
    var attempt = 0;
    var errorCount = 0;
    final item = DwMediaItem(
      id: 'v1',
      kind: DwMediaKind.video,
      source: DwMediaSource.resolve(() async {
        attempt++;
        if (attempt <= 2) throw StateError('transient');
        return Uri.parse('https://example.com/ok.mp4');
      }),
    );
    final controller = DwMediaController.forItem(
      item: item,
      callbacks: DwMediaCallbacks(onError: (_, __) => errorCount++),
      options: const DwMediaConfig(
        autoRetryCount: 2,
        autoRetryDelay: Duration(milliseconds: 50),
      ),
    );
    await tester.pump();
    expect(errorCount, 0, reason: 'first failure is retried automatically, not surfaced');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(attempt, 3);
    expect(controller.state.value.playState, isNot(DwMediaPlayState.error));
    expect(errorCount, 0);
    await controller.dispose();
  });

  testWidgets('speed, volume and mute round-trip through state', (tester) async {
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    await loadAndInit(tester, controller);

    await controller.setSpeed(1.5);
    expect(controller.state.value.speed, 1.5);

    await controller.setVolume(0.4);
    expect(controller.state.value.volume, 0.4);
    expect(controller.state.value.muted, isFalse);

    await controller.setMuted(true);
    expect(controller.state.value.muted, isTrue);
    expect(controller.state.value.volume, 0);

    await controller.setMuted(false);
    expect(controller.state.value.muted, isFalse);
    expect(controller.state.value.volume, 0.4, reason: 'unmuting restores the volume before mute');
    await controller.dispose();
  });

  testWidgets('skip clamps to [0, duration]', (tester) async {
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(),
    );
    await loadAndInit(tester, controller, duration: const Duration(seconds: 10));

    await controller.skip(const Duration(seconds: 5));
    await tester.pump();
    expect(controller.state.value.position, lessThanOrEqualTo(const Duration(seconds: 10)));

    await controller.skip(const Duration(seconds: 100));
    await tester.pump();
    expect(controller.state.value.position, const Duration(seconds: 10));

    await controller.skip(const Duration(seconds: -100));
    await tester.pump();
    expect(controller.state.value.position, Duration.zero);
    await controller.dispose();
  });

  testWidgets('defaultSpeed / initialSpeed applies before anything plays', (tester) async {
    final controller = DwMediaController.forItem(
      item: _videoItem(),
      callbacks: const DwMediaCallbacks(),
      options: const DwMediaConfig(defaultSpeed: 1.75),
    );
    await loadAndInit(tester, controller);
    expect(controller.state.value.speed, 1.75);
    await controller.dispose();
  });
}
