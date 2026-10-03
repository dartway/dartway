// How `DwMiniPlayerHost` places and sizes the player across gestures, a
// changing viewport and route changes. The settings one by one are in
// dw_media_settings_screen_test.dart.
import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;

  setUp(() => rig = MediaRig());

  const chrome = Key('chrome');
  final navigator = GlobalKey<NavigatorState>();
  Alignment? corner;
  var builds = 0;

  /// An 800×600 app with the host over its navigator, a minimized video
  /// session (16:9) in it.
  Future<DwMediaSession> pumpHost(
    WidgetTester tester, {
    DwMediaConfig config = const DwMediaConfig(
      miniPlayerResize: DwMiniPlayerResize.always,
    ),
  }) async {
    corner = null;
    builds = 0;
    final manager = DwMediaSessionManager(config: config);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => Stack(
          children: [
            ?child,
            DwMiniPlayerHost(
              sessionManager: manager,
              onExpand: (_) {},
              resizeHandleLabel: 'Resize',
              builder: (context, session, expand, close) {
                builds++;
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

    testWidgets('stops at the minimum, 160 px', (tester) async {
      final session = await pumpHost(
        tester,
        config: const DwMediaConfig(
          miniPlayerResize: DwMiniPlayerResize.always,
          miniPlayerInitialWidth: 400,
        ),
      );
      await dragFrom(tester, handle(tester), const Offset(400, 0));
      expect(player(tester).size, const Size(160, 90));
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
      await setViewport(tester, const Size(150, 400));
      expect(player(tester), const Rect.fromLTWH(0, 315.625, 150, 84.375));
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

  testWidgets('a drag after a narrow window does not forget the chosen '
      'width: growing back restores it', (tester) async {
    addTearDown(tester.view.reset);
    final session = await pumpHost(tester);
    await dragFrom(tester, handle(tester), const Offset(-240, 0));
    expect(player(tester).size, const Size(480, 270));
    await setViewport(tester, const Size(500, 400));
    expect(player(tester).width, 300);
    await dragFrom(tester, player(tester).center, const Offset(-50, -50));
    await setViewport(tester, const Size(800, 600));
    expect(player(tester).size, const Size(480, 270));
    await endSession(tester, session);
  });

  testWidgets('on release the handle moves to the corner the new place '
      'calls for', (tester) async {
    final session = await pumpHost(
      tester,
      config: const DwMediaConfig(
        miniPlayerResize: DwMiniPlayerResize.always,
        miniPlayerMaxWidthFraction: 1,
      ),
    );
    final gesture = await tester.startGesture(handle(tester));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
    }
    // Mid-resize the handle stays where the pointer took it…
    expect(player(tester), const Rect.fromLTWH(0, 150, 800, 450));
    expect(corner, Alignment.topLeft);
    await gesture.up();
    await tester.pump();
    // …and its centre is no longer in the right half: anchored left now.
    expect(corner, Alignment.topRight);
    await endSession(tester, session);
  });

  testWidgets('move-or-resize is decided where the pointer went down, not '
      'where the slop left it', (tester) async {
    final session = await pumpHost(tester);
    // 2 px inside the handle's inner edge, then one long move inward: past
    // the slop the pointer is far outside the square.
    final gesture = await tester.startGesture(
      player(tester).topLeft + const Offset(30, 30),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(player(tester), const Rect.fromLTWH(600, 487.5, 200, 112.5));
    await endSession(tester, session);
  });

  testWidgets('the resize cursor holds over the whole player while a resize '
      'runs', (tester) async {
    final session = await pumpHost(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(handle(tester));
    await tester.pump();
    final tracker = RendererBinding.instance.mouseTracker;
    // A test mouse is device 1.
    expect(
      tracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.resizeUpLeftDownRight,
    );
    await mouse.down(handle(tester));
    await mouse.moveBy(const Offset(20, 0));
    await tester.pump();
    // Past the minimum the player stops shrinking while the pointer goes on,
    // into the player and out of the handle's square.
    await mouse.moveBy(const Offset(130, 60));
    await tester.pump();
    expect(player(tester), const Rect.fromLTWH(640, 510, 160, 90));
    expect(
      tracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.resizeUpLeftDownRight,
    );
    await mouse.up();
    await tester.pump();
    await mouse.moveTo(player(tester).center);
    await tester.pump();
    expect(
      tracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.resizeUpLeftDownRight),
    );
    await endSession(tester, session);
  });

  testWidgets('hidden mid-resize, the player comes back with no gesture '
      'stuck in it', (tester) async {
    final session = await pumpHost(tester);
    final gesture = await tester.startGesture(handle(tester));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    session.restore();
    await tester.pump();
    await gesture.up();
    await tester.pump();
    session.minimize();
    await tester.pump();
    final shown = player(tester);
    expect(shown.size, const Size(340, 191.25));
    await dragFrom(tester, shown.center, const Offset(-100, -100));
    expect(player(tester).topLeft, shown.topLeft - const Offset(100, 100));
    expect(player(tester).size, shown.size);
    await endSession(tester, session);
  });

  testWidgets('a screen reader steps the width by the handle', (tester) async {
    final semantics = tester.ensureSemantics();
    final session = await pumpHost(tester);
    final node = tester.getSemantics(find.bySemanticsLabel('Resize'));
    expect(node.value, '240');
    // A fifth of 160…480.
    expect(node.increasedValue, '304');
    tester.semantics.increase(find.semantics.byLabel('Resize'));
    await tester.pump();
    expect(player(tester), const Rect.fromLTWH(496, 429, 304, 171));
    tester.semantics.decrease(find.semantics.byLabel('Resize'));
    await tester.pump();
    expect(player(tester).size, const Size(240, 135));
    await endSession(tester, session);
    semantics.dispose();
  });

  testWidgets('dragging against an edge rebuilds nothing', (tester) async {
    final session = await pumpHost(tester);
    await dragFrom(tester, player(tester).center, const Offset(300, 300));
    final before = builds;
    await dragFrom(tester, player(tester).center, const Offset(300, 300));
    // The release still rebuilds once — the handle's corner is recomputed.
    expect(builds - before, lessThanOrEqualTo(1));
    await endSession(tester, session);
  });
}
