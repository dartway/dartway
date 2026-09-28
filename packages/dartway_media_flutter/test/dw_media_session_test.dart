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

  Future<void> initLast(WidgetTester tester, {Duration duration = const Duration(seconds: 60)}) async {
    await tester.pump();
    fake.emitInitialized(fake.livePlayers.last, duration: duration);
    await tester.pump();
  }

  testWidgets('singleActiveItem: opening B pauses A', (tester) async {
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    final a = manager.open(items: [item('a')]);
    await initLast(tester);
    await a.play();
    await tester.pump();
    expect(a.controller.state.value.isPlaying, isTrue);

    final b = manager.open(items: [item('b')]);
    await initLast(tester);
    await b.play();
    await tester.pump();

    expect(a.controller.state.value.isPlaying, isFalse, reason: 'opening/playing B pauses A');
    expect(manager.active.value, same(b));
    await a.dispose();
    await b.dispose();
  });

  testWidgets('singleActiveItem: false allows two sessions to play at once', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(singleActiveItem: false),
    );
    final a = manager.open(items: [item('a')]);
    await initLast(tester);
    await a.play();
    await tester.pump();

    final b = manager.open(items: [item('b')]);
    await initLast(tester);
    await b.play();
    await tester.pump();

    expect(a.controller.state.value.isPlaying, isTrue);
    expect(b.controller.state.value.isPlaying, isTrue);
    await a.dispose();
    await b.dispose();
  });

  testWidgets('next/previous/jumpTo move the queue and dispose the old controller', (tester) async {
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    final session = manager.open(items: [item('a'), item('b'), item('c')]);
    await initLast(tester);
    expect(session.currentItem.id, 'a');

    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.currentItem.id, 'b');
    expect(session.queue.value.currentIndex, 1);

    await session.previous(autoplay: false);
    await initLast(tester);
    expect(session.currentItem.id, 'a');

    await session.jumpTo(2, autoplay: false);
    await initLast(tester);
    expect(session.currentItem.id, 'c');
    expect(session.queue.value.hasNext, isFalse);
    await session.dispose();
  });

  testWidgets('autoplayNext advances the queue when the item reaches the end', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(autoplayNext: true, reachedEndTolerance: Duration.zero),
    );
    final session = manager.open(items: [item('a'), item('b')], callbacks: const DwMediaCallbacks());
    await initLast(tester);
    await session.play();
    await tester.pump();

    final firstPlayerId = fake.livePlayers.first;
    fake.emitCompleted(firstPlayerId);
    await tester.pump();

    expect(session.currentItem.id, 'b');
    await session.dispose();
  });

  testWidgets('autoplayNext off means reaching the end does not advance', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(reachedEndTolerance: Duration.zero),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    await session.play();
    await tester.pump();
    fake.emitCompleted(fake.livePlayers.first);
    await tester.pump();
    expect(session.currentItem.id, 'a');
    await session.dispose();
  });

  testWidgets('nextPreview shows within nextPreviewLeadTime of the end', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(
        nextPreview: true,
        nextPreviewLeadTime: Duration(seconds: 10),
      ),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    final playerId = fake.livePlayers.isEmpty ? null : fake.livePlayers.last;
    await initLast(tester, duration: const Duration(seconds: 60));
    await session.play();
    await tester.pump();
    expect(session.queue.value.showNextPreview, isFalse);

    fake.setPosition(fake.livePlayers.last, const Duration(seconds: 55));
    await tester.pump(const Duration(seconds: 1));
    expect(session.queue.value.showNextPreview, isTrue);
    expect(playerId, isA<int?>());
    await session.dispose();
  });

  testWidgets('nextPreview off keeps showNextPreview false even near the end', (tester) async {
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester, duration: const Duration(seconds: 60));
    await session.play();
    await tester.pump();
    fake.setPosition(fake.livePlayers.last, const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    expect(session.queue.value.showNextPreview, isFalse);
    await session.dispose();
  });

  testWidgets('autoplayCountdown counts down before advancing', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(
        autoplayNext: true,
        autoplayCountdown: true,
        autoplayCountdownDuration: Duration(seconds: 5),
      ),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester, duration: const Duration(seconds: 60));
    await session.play();
    await tester.pump();
    fake.setPosition(fake.livePlayers.last, const Duration(seconds: 57));
    await tester.pump(const Duration(seconds: 1));
    expect(session.queue.value.autoplayCountdownSeconds, isNotNull);
    await session.dispose();
  });

  testWidgets('rememberSpeedAcrossItems carries the speed to the next item', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(rememberSpeedAcrossItems: true),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    await session.setSpeed(1.5);
    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.controller.state.value.speed, 1.5);
    await session.dispose();
  });

  testWidgets('rememberSpeedAcrossItems off resets to defaultSpeed on the next item', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(rememberSpeedAcrossItems: false, defaultSpeed: 1.0),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    await session.setSpeed(2.0);
    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.controller.state.value.speed, 1.0);
    await session.dispose();
  });

  testWidgets('webRememberSoundChoice carries mute to the next item', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(webRememberSoundChoice: true),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    await session.setMuted(true);
    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.controller.state.value.muted, isTrue);
    await session.dispose();
  });

  testWidgets('keepFullscreenAcrossItems keeps isFullscreen true across next()', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(keepFullscreenAcrossItems: true),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    session.enterFullscreen();
    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.isFullscreen.value, isTrue);
    await session.dispose();
  });

  testWidgets('keepFullscreenAcrossItems off exits fullscreen on next()', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(keepFullscreenAcrossItems: false),
    );
    final session = manager.open(items: [item('a'), item('b')]);
    await initLast(tester);
    session.enterFullscreen();
    await session.next(autoplay: false);
    await initLast(tester);
    expect(session.isFullscreen.value, isFalse);
    await session.dispose();
  });

  testWidgets('skipBack/skipForward use their own configured durations', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(
        skipBack: Duration(seconds: 5),
        skipForward: Duration(seconds: 15),
      ),
    );
    final session = manager.open(items: [item('a')]);
    await initLast(tester, duration: const Duration(seconds: 60));
    await session.seek(const Duration(seconds: 20));
    await tester.pump();

    await session.skipForward();
    await tester.pump();
    expect(session.controller.state.value.position, const Duration(seconds: 35));

    await session.skipBack();
    await tester.pump();
    expect(session.controller.state.value.position, const Duration(seconds: 30));
    await session.dispose();
  });

  testWidgets('autoplayOnOpen starts playback without an explicit play() call', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(autoplayOnOpen: true),
    );
    final session = manager.open(items: [item('a')]);
    await initLast(tester);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);
    await session.dispose();
  });

  testWidgets('miniPlayerCloseStopsPlayback true disposes the session on close', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(miniPlayerCloseStopsPlayback: true),
    );
    final session = manager.open(items: [item('a')]);
    await initLast(tester);
    session.minimize();
    await session.closeFromMiniPlayer();
    await tester.pump();
    expect(session.isDisposed, isTrue);
  });

  testWidgets('miniPlayerCloseStopsPlayback false only pauses and hides', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(miniPlayerCloseStopsPlayback: false),
    );
    final session = manager.open(items: [item('a')]);
    await initLast(tester);
    await session.play();
    await tester.pump();
    session.minimize();
    await session.closeFromMiniPlayer();
    await tester.pump();
    expect(session.isDisposed, isFalse);
    expect(session.controller.state.value.isPlaying, isFalse);
    expect(manager.active.value, isNull);
    await session.dispose();
  });

  testWidgets('onItemChanged fires with the new current item on advance', (tester) async {
    DwMediaItem? changedTo;
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    final session = manager.open(
      items: [item('a'), item('b')],
      callbacks: DwMediaCallbacks(onItemChanged: (item) => changedTo = item),
    );
    await initLast(tester);
    await session.next(autoplay: false);
    await initLast(tester);
    expect(changedTo?.id, 'b');
    await session.dispose();
  });
}
