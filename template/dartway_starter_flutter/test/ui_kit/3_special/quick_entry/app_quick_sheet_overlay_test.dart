import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;
  bool ready = false;
  double keyboard = 0;

  void update({bool? isOpen, bool? isReady, double? inset}) => setState(() {
    open = isOpen ?? open;
    ready = isReady ?? ready;
    keyboard = inset ?? keyboard;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (_, child) => MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: Stack(
      children: [
        const SizedBox.expand(),
        AppQuickSheetOverlay(
          isOpen: open,
          onDismiss: () => setState(() => open = false),
          dismissLabel: 'Close entry',
          child: Column(
            key: const Key('content'),
            children: [
              Expanded(
                child: AppQuickSheetHistory(
                  isReady: ready,
                  loading: const Center(child: Text('Loading')),
                  itemCount: 40,
                  itemBuilder: (_, index) => Column(
                    children: [
                      Text('Entry $index'),
                      SizedBox(
                        height: 160,
                        child: Text('Dependent card $index'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48, child: Text('Composer')),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets(
    'delayed history reserves height and first appears at newest with its card; reopening resets the anchor',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const _Host());
      final host = tester.state<_HostState>(find.byType(_Host));
      host.update(isOpen: true);
      await tester.pumpAndSettle();
      final loadingRect = tester.getRect(find.byKey(const Key('content')));
      expect(loadingRect.height, 800 * 0.7 - 16);
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Composer'), findsOneWidget);
      // Both history and its dependent cards become ready together, after the
      // entrance. The first visible frame must already have the newest anchor.
      host.update(isReady: true);
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('content'))), loadingRect);
      final newestRect = tester.getRect(find.text('Entry 0'));
      final cardRect = tester.getRect(find.text('Dependent card 0'));
      expect(newestRect.top, greaterThan(loadingRect.top));
      expect(
        cardRect.bottom,
        lessThan(tester.getTopLeft(find.text('Composer')).dy),
      );
      final history = find.byType(ListView);
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: history, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.pixels, 0);
      await tester.pump();
      expect(tester.getRect(find.text('Entry 0')), newestRect);
      await tester.drag(history, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      host.update(isOpen: false);
      await tester.pumpAndSettle();
      host.update(isOpen: true);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Entry 0')), newestRect);
    },
  );

  testWidgets('dismissal freezes sheet height while keyboard frames change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _Host());
    final host = tester.state<_HostState>(find.byType(_Host));
    host.update(isOpen: true, inset: 300);
    await tester.pumpAndSettle();
    final content = find.byKey(const Key('content'));
    final height = tester.getSize(content).height;
    host.update(isOpen: false);
    await tester.pump();
    for (final keyboard in [240.0, 150.0, 40.0, 0.0]) {
      host.update(inset: keyboard);
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getSize(content).height, height);
    }
    await tester.pumpAndSettle();
    expect(content, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
