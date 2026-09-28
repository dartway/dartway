import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  late DwMediaSessionManager manager;

  setUp(() {
    rig = MediaRig();
    manager = DwMediaSessionManager(config: const DwMediaConfig());
  });

  test('a session needs an item, and a start inside the queue', () {
    expect(() => manager.open(items: []), throwsArgumentError);
    expect(
      () => manager.open(items: [videoItem('a')], startIndex: 1),
      throwsRangeError,
    );
  });

  testWidgets('next, previous and jumpTo move the queue and report the item', (
    tester,
  ) async {
    final changes = <String>[];
    final session = manager.open(
      items: [videoItem('a'), videoItem('b'), videoItem('c')],
      callbacks: DwMediaCallbacks(
        onItemChanged: (item) => changes.add(item.id),
      ),
    );
    await rig.loadVideo(tester);
    await session.next(autoplay: false);
    await rig.loadVideo(tester);
    await session.jumpTo(2, autoplay: false);
    await rig.loadVideo(tester);
    expect(session.queue.value.hasNext, isFalse);
    await session.previous(autoplay: false);
    await rig.loadVideo(tester);
    expect(session.currentItem.id, 'b');
    expect(changes, ['b', 'c', 'b']);
    await endSession(tester, session);
  });

  testWidgets('next() plays the next item unless told not to', (tester) async {
    final session = manager.open(items: [videoItem('a'), videoItem('b')]);
    await rig.loadVideo(tester);
    await session.next();
    await rig.loadVideo(tester);
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    expect(session.playback.value.isPlaying, isTrue);
    await endSession(tester, session);
  });

  testWidgets('the old item\'s engine goes after the frame, the new one '
      'stays', (tester) async {
    final session = manager.open(items: [videoItem('a'), videoItem('b')]);
    await rig.loadVideo(tester);
    final first = rig.video.latest;
    await session.next(autoplay: false);
    await rig.loadVideo(tester);
    expect(first.isReleased, isTrue);
    expect(rig.video.videos, hasLength(1));
    await endSession(tester, session);
    expect(rig.video.videos, isEmpty);
  });

  testWidgets('playback follows the queue from item to item', (tester) async {
    final session = manager.open(items: [videoItem('a'), videoItem('b')]);
    await rig.loadVideo(tester, duration: const Duration(seconds: 30));
    expect(session.playback.value.duration, const Duration(seconds: 30));
    await session.next(autoplay: false);
    expect(session.playback.value.playState, DwMediaPlayState.loading);
    await rig.loadVideo(tester, duration: const Duration(seconds: 45));
    expect(session.playback.value.duration, const Duration(seconds: 45));
    await endSession(tester, session);
  });

  testWidgets('DwVideoSurface draws the current video and follows the queue', (
    tester,
  ) async {
    final slow = MediaRig(readyOnOpen: false);
    final session = manager.open(items: [videoItem('a'), videoItem('b')]);
    await tester.pumpWidget(
      MaterialApp(
        home: DwVideoSurface(
          session: session,
          placeholder: const Text('loading'),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    await slow.loadVideo(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    final firstView = session.videoView.value;
    await session.next(autoplay: false);
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    await slow.loadVideo(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(session.videoView.value, isNot(same(firstView)));
    await endSession(tester, session);
    expect(find.text('loading'), findsOneWidget);
  });

  testWidgets('an audio item has no video to draw', (tester) async {
    final session = manager.open(items: [audioItem('a')]);
    await rig.loadAudio(tester);
    expect(session.videoView.value, isNull);
    await endSession(tester, session);
  });

  testWidgets('the manager keeps the active session and forgets an ended one', (
    tester,
  ) async {
    final first = manager.open(items: [videoItem('a')]);
    final second = manager.open(items: [videoItem('b')]);
    expect(manager.active.value, same(second));
    expect(manager.sessions, [first, second]);
    await endSession(tester, second);
    expect(manager.active.value, isNull);
    expect(manager.sessions, [first]);
    await first.play();
    expect(manager.active.value, same(first));
    await endSession(tester, first);
  });

  testWidgets('an ended session ignores commands', (tester) async {
    final session = manager.open(items: [videoItem('a'), videoItem('b')]);
    await rig.loadVideo(tester);
    await endSession(tester, session);
    await session.play();
    await session.next();
    session.enterFullscreen();
    session.minimize();
    expect(session.currentItem.id, 'a');
    expect(session.isFullscreen.value, isFalse);
    expect(session.minimized.value, isFalse);
  });

  group('one item, one engine', () {
    testWidgets('opening an item a session stands on returns that session', (
      tester,
    ) async {
      final first = manager.open(items: [videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester);
      final again = manager.open(items: [videoItem('a')]);
      expect(again, same(first));
      expect(rig.video.opened, hasLength(1));
      await endSession(tester, first);
    });

    testWidgets('opening without autoplay does not take the mini-player from '
        'a playing session', (tester) async {
      final playing = manager.open(items: [videoItem('a')]);
      await rig.loadVideo(tester);
      await playing.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final other = manager.open(items: [videoItem('b')]);
      await rig.loadVideo(tester);
      expect(manager.active.value, same(playing));
      expect(playing.playback.value.isPlaying, isTrue);
      await other.play();
      expect(manager.active.value, same(other));
      await endSession(tester, playing);
      await endSession(tester, other);
    });

    testWidgets('a session the mini-player\'s close only hid comes back on '
        'opening its item, and ends when another opens', (tester) async {
      final hiddenManager = DwMediaSessionManager(
        config: const DwMediaConfig(miniPlayerCloseStopsPlayback: false),
      );
      final first = hiddenManager.open(items: [videoItem('a')]);
      await rig.loadVideo(tester);
      first.minimize();
      await first.closeFromMiniPlayer();
      await tester.pump();
      expect(hiddenManager.active.value, isNull);
      expect(first.isDisposed, isFalse);

      expect(hiddenManager.open(items: [videoItem('a')]), same(first));
      expect(hiddenManager.active.value, same(first));
      expect(rig.video.opened, hasLength(1));

      first.minimize();
      await first.closeFromMiniPlayer();
      final other = hiddenManager.open(items: [videoItem('b')]);
      await rig.loadVideo(tester);
      await dwSettleMedia(tester);
      expect(first.isDisposed, isTrue);
      expect(rig.video.videos, hasLength(1), reason: 'no unreachable engine');
      await endSession(tester, other);
    });
  });

  testWidgets('the engine survives page → mini-player → page → fullscreen', (
    tester,
  ) async {
    final session = manager.open(items: [videoItem('a')]);
    Widget page() => MaterialApp(
      home: Scaffold(
        body: DwMediaFullscreenHost(
          session: session,
          builder: (_) => DwVideoSurface(session: session),
          child: DwVideoSurface(session: session),
        ),
      ),
    );
    Widget elsewhere() => MaterialApp(
      home: Stack(
        children: [
          const SizedBox.expand(),
          DwMiniPlayerHost(
            sessionManager: manager,
            onExpand: (_) {},
            builder: (context, session, expand, close) =>
                DwVideoSurface(session: session),
          ),
        ],
      ),
    );
    await tester.pumpWidget(page());
    final engine = await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));

    session.minimize();
    await tester.pumpWidget(elsewhere());
    await tester.pump();
    expect(find.byType(VideoPlayer), findsOneWidget);

    session.restore();
    await tester.pumpWidget(page());
    await tester.pump();
    session.enterFullscreen();
    await tester.pumpAndSettle();
    await rig.playVideoTo(tester, const Duration(seconds: 2));

    expect(rig.video.opened, [engine], reason: 'one engine all along');
    expect(engine.isReleased, isFalse);
    expect(session.playback.value.position, const Duration(seconds: 2));
    expect(session.playback.value.isPlaying, isTrue);
    await endSession(tester, session);
    await tester.pumpAndSettle();
  });

  group('autoplay needs a real end since the last seek', () {
    late DwMediaSession session;

    Future<void> openQueue(WidgetTester tester, DwMediaConfig config) async {
      session = DwMediaSessionManager(
        config: config,
      ).open(items: [videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester, duration: const Duration(seconds: 10));
    }

    testWidgets('real end → cancel → scrub back → scrub to the end: no '
        'autoplay', (tester) async {
      await openQueue(tester, const DwMediaConfig(autoplayNext: true));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 9));
      rig.video.latest.finish();
      await tester.pump();
      expect(session.queue.value.autoplayCountdown, isNotNull);
      session.cancelAutoplay();
      await session.seek(const Duration(seconds: 3));
      await tester.pump();
      await session.seek(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(session.queue.value.autoplayCountdown, isNull);
      expect(session.currentItem.id, 'a');
      await endSession(tester, session);
    });

    testWidgets('an end by tolerance → skip back and pause → drag to the '
        'end: no autoplay', (tester) async {
      await openQueue(
        tester,
        const DwMediaConfig(autoplayNext: true, autoplayCountdown: false),
      );
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 5));
      await rig.playVideoTo(
        tester,
        const Duration(seconds: 9, milliseconds: 800),
      );
      await session.skipBack();
      await session.pause();
      await tester.pump();
      await session.seek(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(session.currentItem.id, 'a');
      await endSession(tester, session);
    });

    testWidgets('a real end after a scrub back does move on', (tester) async {
      await openQueue(
        tester,
        const DwMediaConfig(autoplayNext: true, autoplayCountdown: false),
      );
      await session.seek(const Duration(seconds: 5));
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 9));
      rig.video.latest.finish();
      await tester.pump();
      expect(session.currentItem.id, 'b');
      await endSession(tester, session);
    });
  });

  group('DwMediaSource', () {
    test('url: resolves to the address, every time', () async {
      const source = DwMediaSource.url('https://example.com/a.mp4');
      expect(await source.resolve(), Uri.parse('https://example.com/a.mp4'));
    });

    test('resolve: asks the resolver on every load', () async {
      var calls = 0;
      final source = DwMediaSource.resolve(() async {
        calls++;
        return Uri.parse('https://example.com/$calls.mp4');
      });
      await source.resolve();
      expect(await source.resolve(), Uri.parse('https://example.com/2.mp4'));
    });
  });

  test('DwMediaItem is identified by its id alone', () {
    final a = DwMediaItem(
      id: 'x',
      kind: DwMediaKind.video,
      source: const DwMediaSource.url('https://example.com/1.mp4'),
      title: 'One',
    );
    final b = DwMediaItem(
      id: 'x',
      kind: DwMediaKind.video,
      source: const DwMediaSource.url('https://example.com/2.mp4'),
      title: 'Two',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
