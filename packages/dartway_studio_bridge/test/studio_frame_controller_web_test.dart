@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;

import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// The preview frame as the page holds it: a real iframe behind a real
/// platform view, read back through the registry the controller put it in.
void main() {
  late StudioFrameController controller;
  late web.HTMLIFrameElement frame;

  // The tester environment drops every platform message —
  // `flutter/platform_views` among them — so no `HtmlElementView` is ever
  // created and the registry holds nothing to read back. The engine answers
  // for itself here, which puts this controller's own view factory behind the
  // view, as in Studio.
  setUpAll(
    () => ui_web.TestEnvironment.setUp(
      const ui_web.TestEnvironment(
        forceTestFonts: true,
        disableFontFallbacks: true,
        keepSemanticsDisabledOnUpdate: true,
        defaultToTestUrlStrategy: true,
      ),
    ),
  );

  tearDownAll(
    () => ui_web.TestEnvironment.setUp(
      const ui_web.TestEnvironment.flutterTester(),
    ),
  );

  setUp(() {
    // Never loaded for real: the discard port answers nothing, and what is
    // under test is the element, not the page inside it.
    controller = createStudioFrameController(appUrl: 'http://127.0.0.1:9/');
  });

  tearDown(() => controller.dispose());

  Future<void> pumpFrame(WidgetTester tester) async {
    int? viewId;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HtmlElementView(
          viewType: controller.viewType,
          onPlatformViewCreated: (id) => viewId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(viewId, isNotNull, reason: 'the platform view was never created');
    frame =
        ui_web.platformViewRegistry.getViewById(viewId!)
            as web.HTMLIFrameElement;
  }

  testWidgets('a fresh frame is interactive', (tester) async {
    await pumpFrame(tester);
    // No inline value: the property keeps its initial value, `auto`. (The
    // tester composites nothing into the page, so there is no computed style
    // to read — the element is never attached.)
    expect(frame.style.pointerEvents, isEmpty);
  });

  testWidgets('setInteractive(false) stops the frame taking pointer input', (
    tester,
  ) async {
    await pumpFrame(tester);
    controller.setInteractive(false);
    expect(frame.style.pointerEvents, 'none');
  });

  testWidgets('setInteractive(true) gives the pointer back', (tester) async {
    await pumpFrame(tester);
    controller.setInteractive(false);
    controller.setInteractive(true);
    expect(frame.style.pointerEvents, 'auto');
  });

  testWidgets('works before the frame is laid out', (tester) async {
    controller.setInteractive(false);
    await pumpFrame(tester);
    expect(frame.style.pointerEvents, 'none');
  });

  testWidgets('does nothing after dispose', (tester) async {
    await pumpFrame(tester);
    controller.setInteractive(false);
    controller.dispose();
    controller.setInteractive(true);
    expect(frame.style.pointerEvents, 'none');
  });
}
