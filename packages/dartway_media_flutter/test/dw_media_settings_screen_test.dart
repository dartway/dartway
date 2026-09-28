// One group per `DwMediaConfig` setting of fullscreen and the mini-player:
// each shows the default and what turning it off or changing it does. The
// table in docs/3-flutter/media.md lists the same settings.
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  late List<List<String>> orientationCalls;

  setUp(() {
    rig = MediaRig();
    orientationCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add([
              for (final name in call.arguments as List) '$name',
            ]);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const inline = Key('inline');
  const fullscreenPage = Key('fullscreen');

  /// A page with the inline player wrapped in the fullscreen host.
  Future<DwMediaSession> pumpPlayerPage(
    WidgetTester tester,
    List<DwMediaItem> items, {
    DwMediaConfig config = const DwMediaConfig(),
  }) async {
    final session = DwMediaSessionManager(config: config).open(items: items);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DwMediaFullscreenHost(
            session: session,
            builder: (_) => const SizedBox.expand(key: fullscreenPage),
            child: const SizedBox(key: inline, width: 320, height: 180),
          ),
        ),
      ),
    );
    await rig.loadVideo(tester);
    return session;
  }

  group('fullscreen', () {
    testWidgets('on (default): enterFullscreen pushes the route, '
        'exitFullscreen pops it', (tester) async {
      final session = await pumpPlayerPage(tester, [videoItem('v')]);
      session.enterFullscreen();
      await tester.pumpAndSettle();
      expect(find.byKey(fullscreenPage), findsOneWidget);
      session.exitFullscreen();
      await tester.pumpAndSettle();
      expect(find.byKey(fullscreenPage), findsNothing);
      await endSession(tester, session);
    });

    testWidgets('on: a back gesture ends fullscreen', (tester) async {
      final session = await pumpPlayerPage(tester, [videoItem('v')]);
      session.enterFullscreen();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(session.isFullscreen.value, isFalse);
      expect(find.byKey(fullscreenPage), findsNothing);
      await endSession(tester, session);
    });

    testWidgets('off: enterFullscreen does nothing', (tester) async {
      final session = await pumpPlayerPage(tester, [
        videoItem('v'),
      ], config: const DwMediaConfig(fullscreen: false));
      session.enterFullscreen();
      await tester.pumpAndSettle();
      expect(session.isFullscreen.value, isFalse);
      expect(find.byKey(fullscreenPage), findsNothing);
      await endSession(tester, session);
    });
  });

  group('fullscreenOrientations', () {
    Future<List<List<String>>> callsOnEnter(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final session = await pumpPlayerPage(tester, [
        videoItem('v'),
      ], config: config);
      orientationCalls.clear();
      session.enterFullscreen();
      await tester.pumpAndSettle();
      final calls = List.of(orientationCalls);
      await endSession(tester, session);
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('landscape (default)', (tester) async {
      expect(await callsOnEnter(tester, const DwMediaConfig()), [
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      ]);
    });

    testWidgets('portrait only', (tester) async {
      expect(
        await callsOnEnter(
          tester,
          const DwMediaConfig(
            fullscreenOrientations: [DeviceOrientation.portraitUp],
          ),
        ),
        [
          ['DeviceOrientation.portraitUp'],
        ],
      );
    });

    testWidgets('empty: orientations are left alone', (tester) async {
      expect(
        await callsOnEnter(
          tester,
          const DwMediaConfig(fullscreenOrientations: []),
        ),
        isEmpty,
      );
    });
  });

  group('exitOrientations', () {
    Future<List<String>> callOnExit(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final session = await pumpPlayerPage(tester, [
        videoItem('v'),
      ], config: config);
      session.enterFullscreen();
      await tester.pumpAndSettle();
      session.exitFullscreen();
      await tester.pumpAndSettle();
      final call = orientationCalls.last;
      await endSession(tester, session);
      return call;
    }

    testWidgets('portrait up (default)', (tester) async {
      expect(await callOnExit(tester, const DwMediaConfig()), [
        'DeviceOrientation.portraitUp',
      ]);
    });

    testWidgets('empty: every orientation', (tester) async {
      expect(
        await callOnExit(tester, const DwMediaConfig(exitOrientations: [])),
        isEmpty,
      );
    });
  });

  group('autoEnterFullscreenOnPlay', () {
    testWidgets('off (default): play stays inline', (tester) async {
      final session = await pumpPlayerPage(tester, [videoItem('v')]);
      await session.play();
      await tester.pumpAndSettle();
      expect(find.byKey(fullscreenPage), findsNothing);
      await endSession(tester, session);
    });

    testWidgets('on: playing a video goes fullscreen', (tester) async {
      final session = await pumpPlayerPage(tester, [
        videoItem('v'),
      ], config: const DwMediaConfig(autoEnterFullscreenOnPlay: true));
      await session.play();
      await tester.pumpAndSettle();
      expect(find.byKey(fullscreenPage), findsOneWidget);
      await endSession(tester, session);
      await tester.pumpAndSettle();
    });

    testWidgets('on: playing audio does not', (tester) async {
      final session = DwMediaSessionManager(
        config: const DwMediaConfig(autoEnterFullscreenOnPlay: true),
      ).open(items: [audioItem('a')]);
      await rig.loadAudio(tester);
      await session.play();
      expect(session.isFullscreen.value, isFalse);
      await endSession(tester, session);
    });
  });

  group('keepFullscreenAcrossItems', () {
    Future<bool> fullscreenAfterNext(
      WidgetTester tester,
      DwMediaConfig config,
    ) async {
      final session = await pumpPlayerPage(tester, [
        videoItem('a'),
        videoItem('b'),
      ], config: config);
      session.enterFullscreen();
      await tester.pumpAndSettle();
      await session.next(autoplay: false);
      await rig.loadVideo(tester);
      await tester.pumpAndSettle();
      final shown = find.byKey(fullscreenPage).evaluate().isNotEmpty;
      await endSession(tester, session);
      await tester.pumpAndSettle();
      return shown;
    }

    testWidgets('on (default): the next item stays fullscreen', (tester) async {
      expect(await fullscreenAfterNext(tester, const DwMediaConfig()), isTrue);
    });

    testWidgets('off: the next item leaves fullscreen', (tester) async {
      expect(
        await fullscreenAfterNext(
          tester,
          const DwMediaConfig(keepFullscreenAcrossItems: false),
        ),
        isFalse,
      );
    });
  });

  // --- The mini-player -----------------------------------------------------

  const chrome = Key('chrome');
  const close = Key('close');

  Future<(DwMediaSession, List<DwMediaItem>)> pumpMiniPlayer(
    WidgetTester tester, {
    DwMediaConfig config = const DwMediaConfig(),
  }) async {
    final manager = DwMediaSessionManager(config: config);
    final expanded = <DwMediaItem>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox.expand(),
            DwMiniPlayerHost(
              sessionManager: manager,
              onExpand: expanded.add,
              builder: (context, session, expand, onClose) => GestureDetector(
                onTap: expand,
                child: Container(
                  key: chrome,
                  color: const Color(0xFF000000),
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: const SizedBox(key: close, width: 20, height: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final session = manager.open(items: [videoItem('m')]);
    await rig.loadVideo(tester);
    session.minimize();
    await tester.pump();
    return (session, expanded);
  }

  testWidgets('the host shows a session only while it is minimized, and '
      'expand restores it and calls onExpand', (tester) async {
    final (session, expanded) = await pumpMiniPlayer(tester);
    expect(find.byKey(chrome), findsOneWidget);
    await tester.tap(find.byKey(chrome), warnIfMissed: false);
    await tester.pump();
    expect(expanded.single.id, 'm');
    expect(session.minimized.value, isFalse);
    expect(find.byKey(chrome), findsNothing);
    await endSession(tester, session);
  });

  group('miniPlayer', () {
    testWidgets('on (default): a minimized session shows', (tester) async {
      final (session, _) = await pumpMiniPlayer(tester);
      expect(find.byKey(chrome), findsOneWidget);
      await endSession(tester, session);
    });

    testWidgets('off: minimize does nothing', (tester) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: const DwMediaConfig(miniPlayer: false),
      );
      expect(session.minimized.value, isFalse);
      expect(find.byKey(chrome), findsNothing);
      await endSession(tester, session);
    });
  });

  group('miniPlayerInitialSize', () {
    testWidgets('160×90 (default)', (tester) async {
      final (session, _) = await pumpMiniPlayer(tester);
      expect(tester.getSize(find.byKey(chrome)), const Size(160, 90));
      await endSession(tester, session);
    });

    testWidgets('240×135', (tester) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: const DwMediaConfig(miniPlayerInitialSize: Size(240, 135)),
      );
      expect(tester.getSize(find.byKey(chrome)), const Size(240, 135));
      await endSession(tester, session);
    });
  });

  group('miniPlayerInitialAlignment', () {
    testWidgets('bottom right (default)', (tester) async {
      final (session, _) = await pumpMiniPlayer(tester);
      expect(tester.getBottomRight(find.byKey(chrome)), const Offset(800, 600));
      await endSession(tester, session);
    });

    testWidgets('top left', (tester) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: const DwMediaConfig(
          miniPlayerInitialAlignment: Alignment.topLeft,
        ),
      );
      expect(tester.getTopLeft(find.byKey(chrome)), Offset.zero);
      await endSession(tester, session);
    });
  });

  group('miniPlayerMinScale / miniPlayerMaxScale', () {
    Future<Size> pinch(
      WidgetTester tester,
      DwMediaConfig config, {
      required bool spread,
    }) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: DwMediaConfig(
          miniPlayerInitialAlignment: Alignment.center,
          miniPlayerSnapToEdges: false,
          miniPlayerMinScale: config.miniPlayerMinScale,
          miniPlayerMaxScale: config.miniPlayerMaxScale,
        ),
      );
      final center = tester.getCenter(find.byKey(chrome));
      final gap = spread ? 20.0 : 60.0;
      final first = await tester.startGesture(
        center - Offset(gap, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + Offset(gap, 0),
        pointer: 2,
      );
      await tester.pump();
      // In steps: the recognizer takes its starting span only once the
      // pointers have moved past the slop.
      final step = (spread ? 300.0 : -55.0) / 10;
      for (var i = 0; i < 10; i++) {
        await first.moveBy(Offset(-step, 0));
        await second.moveBy(Offset(step, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await tester.pump();
      final size = tester.getSize(find.byKey(chrome));
      await endSession(tester, session);
      return size;
    }

    testWidgets('max 2 (default): a wide spread stops at twice the size', (
      tester,
    ) async {
      expect(
        await pinch(tester, const DwMediaConfig(), spread: true),
        const Size(320, 180),
      );
    });

    testWidgets('max 3: the same spread grows to three times', (tester) async {
      expect(
        await pinch(
          tester,
          const DwMediaConfig(miniPlayerMaxScale: 3),
          spread: true,
        ),
        const Size(480, 270),
      );
    });

    testWidgets('min 0.75 (default): a tight pinch stops at three quarters', (
      tester,
    ) async {
      expect(
        await pinch(tester, const DwMediaConfig(), spread: false),
        const Size(120, 67.5),
      );
    });

    testWidgets('min 0.5: the same pinch shrinks to half', (tester) async {
      expect(
        await pinch(
          tester,
          const DwMediaConfig(miniPlayerMinScale: 0.5),
          spread: false,
        ),
        const Size(80, 45),
      );
    });
  });

  group('miniPlayerSnapToEdges', () {
    Future<double> leftAfterDrag(WidgetTester tester, bool snap) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: DwMediaConfig(
          miniPlayerInitialAlignment: Alignment.topLeft,
          miniPlayerSnapToEdges: snap,
        ),
      );
      await tester.drag(find.byKey(chrome), const Offset(100, 50));
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(find.byKey(chrome)).dx;
      await endSession(tester, session);
      return left;
    }

    testWidgets('on (default): released left of the middle, it goes back to '
        'the left edge', (tester) async {
      expect(await leftAfterDrag(tester, true), 0);
    });

    testWidgets('off: it stays where it was dropped', (tester) async {
      expect(await leftAfterDrag(tester, false), greaterThan(50));
    });
  });

  group('miniPlayerCloseStopsPlayback', () {
    testWidgets('on (default): close ends the session', (tester) async {
      final (session, _) = await pumpMiniPlayer(tester);
      await tester.tap(find.byKey(close));
      await tester.pump();
      expect(session.isDisposed, isTrue);
      expect(find.byKey(chrome), findsNothing);
      await tester.pump();
    });

    testWidgets('off: close pauses and hides it, the session lives', (
      tester,
    ) async {
      final (session, _) = await pumpMiniPlayer(
        tester,
        config: const DwMediaConfig(miniPlayerCloseStopsPlayback: false),
      );
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(close));
      await tester.pump();
      expect(session.isDisposed, isFalse);
      expect(session.playback.value.isPlaying, isFalse);
      expect(find.byKey(chrome), findsNothing);
      await endSession(tester, session);
    });
  });
}
