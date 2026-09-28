import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'support/dw_fake_wakelock_platform.dart';

void main() {
  late DwFakeVideoPlayerPlatform fake;

  setUp(() {
    fake = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  DwMediaItem videoItem(String id) => DwMediaItem(
    id: id,
    kind: DwMediaKind.video,
    source: DwMediaSource.url('https://example.com/$id.mp4'),
  );

  group('wakelockWhilePlaying', () {
    late DwFakeWakelockPlatform fakeWakelock;

    setUp(() {
      fakeWakelock = DwFakeWakelockPlatform();
      wakelockPlusPlatformInstance = fakeWakelock;
    });

    testWidgets('on: held while a video plays, released on pause', (tester) async {
      final controller = DwMediaController.forItem(
        item: videoItem('w1'),
        callbacks: const DwMediaCallbacks(),
        options: const DwMediaConfig(wakelockWhilePlaying: true),
      );
      await tester.pump();
      fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 30));
      await tester.pump();

      await controller.play();
      await tester.pump();
      expect(fakeWakelock.isEnabled, isTrue);

      await controller.pause();
      await tester.pump();
      expect(fakeWakelock.isEnabled, isFalse);
      await controller.dispose();
    });

    testWidgets('off: never toggled even while playing', (tester) async {
      final controller = DwMediaController.forItem(
        item: videoItem('w2'),
        callbacks: const DwMediaCallbacks(),
        options: const DwMediaConfig(wakelockWhilePlaying: false),
      );
      await tester.pump();
      fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 30));
      await tester.pump();

      await controller.play();
      await tester.pump();
      expect(fakeWakelock.toggleCount, 0);
      await controller.dispose();
    });
  });

  group('speeds', () {
    test('empty by default — the knob for "no speed control" a controls widget reads', () {
      const config = DwMediaConfig();
      expect(config.speeds, isEmpty);
    });

    test('a configured list is carried on DwMediaSession.options', () {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(speeds: [1.0, 1.5, 2.0]),
      );
      final session = manager.open(items: [videoItem('s1')]);
      expect(session.options.speeds, [1.0, 1.5, 2.0]);
    });
  });

  group('controlsAutoHideDelay', () {
    test('published on the resolved options a controls widget reads', () {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(controlsAutoHideDelay: Duration(seconds: 7)),
      );
      final session = manager.open(items: [videoItem('c1')]);
      expect(session.options.controlsAutoHideDelay, const Duration(seconds: 7));
    });
  });

  group('DwMediaOpenOptions overrides one open() without touching the global default', () {
    test('merge() overrides only the fields given', () {
      const base = DwMediaConfig(autoplayNext: false, speeds: [1.0]);
      final merged = base.merge(const DwMediaOpenOptions(autoplayNext: true));
      expect(merged.autoplayNext, isTrue);
      expect(merged.speeds, [1.0], reason: 'untouched fields fall back to the base config');
    });

    test('resume: null is a real override, distinct from "not overridden"', () {
      const base = DwMediaConfig();
      expect(base.resume, isNotNull);
      final merged = base.merge(const DwMediaOpenOptions(resume: null));
      expect(merged.resume, isNull);
      final untouched = base.merge(const DwMediaOpenOptions(autoplayNext: true));
      expect(untouched.resume, isNotNull, reason: 'resume was not named in this override');
    });

    testWidgets('DwMedia.open() applies a per-open override', (tester) async {
      final media = DwMedia(config: const DwMediaConfig(autoplayOnOpen: false));
      final session = media.open(
        items: [videoItem('o1')],
        options: const DwMediaOpenOptions(autoplayOnOpen: true),
      );
      await tester.pump();
      fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 30));
      await tester.pump();
      expect(session.controller.state.value.isPlaying, isTrue);
      await media.dispose();
    });
  });

  group('mini-player mechanics', () {
    testWidgets('drag moves the mini-player within the screen', (tester) async {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(
          miniPlayerInitialAlignment: Alignment.topLeft,
          miniPlayerSnapToEdges: false,
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Stack(
          children: [
            DwMiniPlayerHost(
              sessionManager: manager,
              onExpand: (_) {},
              builder: (context, session, expand, close) =>
                  Container(key: const Key('chrome'), color: const Color(0xFFFF0000)),
            ),
          ],
        ),
      ));
      final session = manager.open(items: [videoItem('m1')]);
      session.minimize();
      await tester.pump();

      final before = tester.getTopLeft(find.byKey(const Key('chrome')));
      await tester.drag(find.byKey(const Key('chrome')), const Offset(50, 40));
      await tester.pump();
      final after = tester.getTopLeft(find.byKey(const Key('chrome')));

      expect(after.dx, greaterThan(before.dx));
      expect(after.dy, greaterThan(before.dy));
      await session.dispose();
    });

    testWidgets('snapToEdges snaps horizontally on release', (tester) async {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(
          miniPlayerInitialAlignment: Alignment.topLeft,
          miniPlayerSnapToEdges: true,
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Stack(
          children: [
            DwMiniPlayerHost(
              sessionManager: manager,
              onExpand: (_) {},
              builder: (context, session, expand, close) =>
                  Container(key: const Key('chrome'), color: const Color(0xFFFF0000)),
            ),
          ],
        ),
      ));
      final session = manager.open(items: [videoItem('m2')]);
      session.minimize();
      await tester.pump();

      // Drag a little to the right, but not past the midpoint — should snap
      // back to the left edge.
      await tester.drag(find.byKey(const Key('chrome')), const Offset(30, 0));
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(find.byKey(const Key('chrome')));
      expect(left.dx, 0);
      await session.dispose();
    });
  });
}
