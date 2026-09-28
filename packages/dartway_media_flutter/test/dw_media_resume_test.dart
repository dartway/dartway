import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late DwFakeVideoPlayerPlatform fake;

  setUp(() {
    fake = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  DwMediaItem item(String id) => DwMediaItem(
    id: id,
    kind: DwMediaKind.video,
    source: DwMediaSource.url('https://example.com/$id.mp4'),
  );

  Future<int> loadAndInit(WidgetTester tester, {Duration duration = const Duration(seconds: 100)}) async {
    await tester.pump();
    final playerId = fake.livePlayers.last;
    fake.emitInitialized(playerId, duration: duration);
    await tester.pump();
    return playerId;
  }

  testWidgets('a position under the minimum is never saved', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    final controller = DwMediaController.forItem(
      item: item('r1'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(
        resume: const DwMediaResumePolicy(minimum: Duration(seconds: 5)),
        positionStore: store,
      ),
    );
    final playerId = await loadAndInit(tester);
    await controller.play();
    await tester.pump();
    fake.setPosition(playerId, const Duration(seconds: 2));
    await controller.pause();
    await tester.pump();
    expect(await store.read('r1'), isNull);
    await controller.dispose();
  });

  testWidgets('pause saves immediately when saveOnLifecycleEvents is on (the default)', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    final controller = DwMediaController.forItem(
      item: item('r2'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(
        resume: const DwMediaResumePolicy(saveInterval: Duration(minutes: 10)),
        positionStore: store,
      ),
    );
    final playerId = await loadAndInit(tester);
    await controller.play();
    await tester.pump();
    fake.setPosition(playerId, const Duration(seconds: 30));
    await tester.pump();
    await controller.pause();
    await tester.pump();
    expect(await store.read('r2'), const Duration(seconds: 30));
    await controller.dispose();
  });

  testWidgets('saveOnLifecycleEvents off means pause does not save early', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    final controller = DwMediaController.forItem(
      item: item('r3'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(
        resume: const DwMediaResumePolicy(
          saveInterval: Duration(minutes: 10),
          saveOnLifecycleEvents: false,
        ),
        positionStore: store,
      ),
    );
    final playerId = await loadAndInit(tester);
    await controller.play();
    await tester.pump();
    fake.setPosition(playerId, const Duration(seconds: 30));
    await tester.pump();
    await controller.pause();
    await tester.pump();
    expect(await store.read('r3'), isNull);
    await controller.dispose();
  });

  testWidgets('the periodic saveInterval saves without a pause', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    final controller = DwMediaController.forItem(
      item: item('r4'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(
        resume: const DwMediaResumePolicy(saveInterval: Duration(seconds: 5)),
        positionStore: store,
      ),
    );
    final playerId = await loadAndInit(tester);
    await controller.play();
    await tester.pump();
    fake.setPosition(playerId, const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 5));
    expect(await store.read('r4'), const Duration(seconds: 20));
    await controller.dispose();
  });

  testWidgets('past clearPastFraction the position is cleared, not updated', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    await store.write('r5', const Duration(seconds: 40));
    final controller = DwMediaController.forItem(
      item: item('r5'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(
        resume: const DwMediaResumePolicy(clearPastFraction: 0.9),
        positionStore: store,
      ),
    );
    final playerId = await loadAndInit(tester, duration: const Duration(seconds: 100));
    await controller.play();
    await tester.pump();
    fake.setPosition(playerId, const Duration(seconds: 95));
    await controller.pause();
    await tester.pump();
    expect(await store.read('r5'), isNull);
    await controller.dispose();
  });

  testWidgets('resume off (null policy) never reads or writes the store', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    await store.write('r6', const Duration(seconds: 40));
    final controller = DwMediaController.forItem(
      item: item('r6'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(resume: null, positionStore: store),
    );
    await loadAndInit(tester);
    // Not resumed to the stored position — resume was off.
    expect(controller.state.value.position, Duration.zero);
    await controller.play();
    await tester.pump();
    await controller.pause();
    await tester.pump();
    // Still there, untouched — nothing was written either.
    expect(await store.read('r6'), const Duration(seconds: 40));
    await controller.dispose();
  });

  testWidgets('a saved position resumes on the next open of the same item', (tester) async {
    final store = DwMediaInMemoryPositionStore();
    await store.write('r7', const Duration(seconds: 42));
    final controller = DwMediaController.forItem(
      item: item('r7'),
      callbacks: const DwMediaCallbacks(),
      options: DwMediaConfig(positionStore: store),
    );
    await loadAndInit(tester);
    expect(controller.state.value.position, const Duration(seconds: 42));
    await controller.dispose();
  });
}
