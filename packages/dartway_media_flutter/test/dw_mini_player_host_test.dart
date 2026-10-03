// How `DwMiniPlayerHost` places and sizes the player across gestures, a
// changing viewport and route changes. The settings one by one are in
// dw_media_settings_screen_test.dart.
import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;

  setUp(() => rig = MediaRig());

  const chrome = Key('chrome');
  final navigator = GlobalKey<NavigatorState>();
  Alignment? corner;

  /// An 800×600 app with the host over its navigator, a minimized video
  /// session (16:9) in it.
  Future<DwMediaSession> pumpHost(
    WidgetTester tester, {
    DwMediaConfig config = const DwMediaConfig(
      miniPlayerResize: DwMiniPlayerResize.always,
    ),
  }) async {
    corner = null;
    final manager = DwMediaSessionManager(config: config);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            DwMiniPlayerHost(
              sessionManager: manager,
              onExpand: (_) {},
              builder: (context, session, expand, close) {
                corner = DwMiniPlayerHost.resizeCornerOf(context);
                return const ColoredBox(key: chrome, color: Colors.black);
              },
            ),
          ],
        ),
        home: const SizedBox.expand(),
      ),
    );
    final session = manager.open(items: [videoItem('m')]);
    await rig.loadVideo(tester);
    session.minimize();
    await tester.pump();
    return session;
  }

  Rect player(WidgetTester tester) => tester.getRect(find.byKey(chrome));

  /// Drags from [from] by [by] in small steps, the way a hand does.
  Future<void> dragFrom(WidgetTester tester, Offset from, Offset by) async {
    final gesture = await tester.startGesture(from);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(by / 10);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    await tester.pump();
  }

  /// The handle: the top-left corner while the player sits bottom right.
  Offset handle(WidgetTester tester) =>
      player(tester).topLeft + const Offset(6, 6);

  testWidgets('a dragged player stays exactly where it is released', (
    tester,
  ) async {
    final session = await pumpHost(tester);
    expect(player(tester), const Rect.fromLTWH(560, 465, 240, 135));
    await dragFrom(tester, player(tester).center, const Offset(-300, -200));
    expect(player(tester), const Rect.fromLTWH(260, 265, 240, 135));
    await endSession(tester, session);
  });

  testWidgets('dragged past the edges, it stops at them — and comes straight '
      'back when dragged the other way', (tester) async {
    final session = await pumpHost(tester);
    await dragFrom(tester, player(tester).center, const Offset(-900, -700));
    expect(player(tester).topLeft, Offset.zero);
    await dragFrom(tester, player(tester).center, const Offset(100, 50));
    expect(player(tester).topLeft, const Offset(100, 50));
    await endSession(tester, session);
  });

  testWidgets('the system padding is outside the visible area', (tester) async {
    // Physical pixels: 40 logical at the test view's ratio of 3.
    tester.view.padding = const FakeViewPadding(bottom: 120);
    addTearDown(tester.view.resetPadding);
    final session = await pumpHost(tester);
    expect(player(tester).bottomRight, const Offset(800, 560));
    await dragFrom(tester, player(tester).center, const Offset(0, 300));
    expect(player(tester).bottom, 560);
    await endSession(tester, session);
  });

  group('resize by the handle', () {
    testWidgets('keeps the ratio, and the anchored corner stays put', (
      tester,
    ) async {
      final session = await pumpHost(tester);
      expect(corner, Alignment.topLeft);
      await dragFrom(tester, handle(tester), const Offset(-160, 0));
      expect(player(tester), const Rect.fromLTWH(400, 375, 400, 225));
      // Dragged mostly upward, the height leads.
      await dragFrom(tester, handle(tester), const Offset(-10, -45));
      expect(player(tester).size, const Size(480, 270));
      expect(player(tester).bottomRight, const Offset(800, 600));
      await endSession(tester, session);
    });

    testWidgets('stops at the maximum, 60 % of the viewport width', (
      tester,
    ) async {
      final session = await pumpHost(tester);
      await dragFrom(tester, handle(tester), const Offset(-700, 0));
      expect(player(tester).size, const Size(480, 270));
      await endSession(tester, session);
    });

    testWidgets('stops at the minimum, 240 px', (tester) async {
      final session = await pumpHost(
        tester,
        config: const DwMediaConfig(
          miniPlayerResize: DwMiniPlayerResize.always,
          miniPlayerInitialWidth: 400,
        ),
      );
      await dragFrom(tester, handle(tester), const Offset(400, 0));
      expect(player(tester).size, const Size(240, 135));
      expect(player(tester).bottomRight, const Offset(800, 600));
      await endSession(tester, session);
    });

    testWidgets('the handle is opposite the corner the player is anchored to', (
      tester,
    ) async {
      final session = await pumpHost(tester);
      expect(corner, Alignment.topLeft);
      await dragFrom(tester, player(tester).center, const Offset(-600, -500));
      expect(corner, Alignment.bottomRight);
      // Anchored top left now: the bottom-right handle grows it from there.
      await dragFrom(
        tester,
        player(tester).bottomRight - const Offset(6, 6),
        const Offset(80, 0),
      );
      expect(player(tester), const Rect.fromLTWH(0, 0, 320, 180));
      await endSession(tester, session);
    });
  });

  group('a changing viewport', () {
    testWidgets('a shrinking window pushes the player in; growing back '
        'returns it where it was put', (tester) async {
      addTearDown(tester.view.reset);
      final session = await pumpHost(tester);
      await dragFrom(tester, player(tester).center, const Offset(-60, -65));
      expect(player(tester), const Rect.fromLTWH(500, 400, 240, 135));
      await setViewport(tester, const Size(400, 300));
      expect(player(tester), const Rect.fromLTWH(160, 165, 240, 135));
      await setViewport(tester, const Size(800, 600));
      expect(player(tester), const Rect.fromLTWH(500, 400, 240, 135));
      await endSession(tester, session);
    });

    testWidgets('a shrinking window narrows the player to its new maximum; '
        'growing back restores the width', (tester) async {
      addTearDown(tester.view.reset);
      final session = await pumpHost(tester);
      await dragFrom(tester, handle(tester), const Offset(-240, 0));
      expect(player(tester).size, const Size(480, 270));
      await setViewport(tester, const Size(500, 400));
      // 60 % of 500 is 300.
      expect(player(tester), const Rect.fromLTWH(200, 231.25, 300, 168.75));
      await setViewport(tester, const Size(800, 600));
      expect(player(tester), const Rect.fromLTWH(320, 330, 480, 270));
      await endSession(tester, session);
    });

    testWidgets('a viewport narrower than the minimum still fits the player', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final session = await pumpHost(tester);
      await setViewport(tester, const Size(200, 400));
      expect(player(tester), const Rect.fromLTWH(0, 287.5, 200, 112.5));
      await endSession(tester, session);
    });
  });

  testWidgets('position and size survive route changes and the player '
      'hiding and showing again', (tester) async {
    final session = await pumpHost(tester);
    await dragFrom(tester, handle(tester), const Offset(-80, 0));
    await dragFrom(tester, player(tester).center, const Offset(-200, -100));
    final placed = player(tester);
    expect(placed, const Rect.fromLTWH(280, 320, 320, 180));

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    expect(player(tester), placed);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player(tester), placed);

    session.restore();
    await tester.pump();
    expect(find.byKey(chrome), findsNothing);
    session.minimize();
    await tester.pump();
    expect(player(tester), placed);
    await endSession(tester, session);
  });
}
