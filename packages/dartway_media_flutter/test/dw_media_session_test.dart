import 'package:dartway_media_flutter/dartway_media_flutter.dart';
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
    final first = rig.lastVideo;
    await session.next(autoplay: false);
    await rig.loadVideo(tester);
    expect(rig.video.videos, isNot(contains(first)));
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
    await rig.loadVideo(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    final firstView = session.videoView.value;
    await session.next(autoplay: false);
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    await rig.loadVideo(tester);
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
