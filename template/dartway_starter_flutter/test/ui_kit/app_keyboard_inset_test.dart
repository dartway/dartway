import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keyboard, as a test can state it: a step change in `viewInsets`.
///
/// That is how the system reports it — one step, or two on iOS — while the
/// keyboard itself travels for about 250 ms. Everything here is about the
/// distance between those two facts.
Widget _withKeyboard(double inset, Widget child) => MediaQuery(
  data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// A host for the sheet, which needs a `Navigator` and therefore an app.
///
/// The `MediaQuery` goes in through `builder:` and not around `MaterialApp`:
/// the app installs its own from the view, so one wrapped around it reaches
/// nothing — and a modal route is built above `home`, so only `builder:` is
/// seen by both.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.child});

  final Widget child;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  double keyboard = 0;

  void raiseKeyboard(double inset) => setState(() => keyboard = inset);

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(size: _screen, viewInsets: EdgeInsets.only(bottom: keyboard)),
      child: child!,
    ),
    home: Scaffold(body: widget.child),
  );
}

const _screen = Size(400, 800);
const _raised = 300.0;
const _sheetPadding = 16.0;

void main() {
  group('AppKeyboardInset', () {
    testWidgets('hands a step change over gradually, not at once', (
      tester,
    ) async {
      late double inset;
      Widget tree(double keyboard) => _withKeyboard(
        keyboard,
        AppKeyboardInset(
          builder: (_, value) {
            inset = value;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(tree(0));
      expect(inset, 0);

      await tester.pumpWidget(tree(_raised));
      await tester.pump(AppKeyboardInset.duration ~/ 2);

      // The point of the widget: halfway through the keyboard's travel the
      // layout is halfway too, instead of having arrived on the first frame.
      expect(inset, greaterThan(0));
      expect(inset, lessThan(_raised));

      await tester.pumpAndSettle();
      expect(inset, _raised);
    });

    testWidgets('delivers a keyboard that is already up without animating', (
      tester,
    ) async {
      final delivered = <double>[];
      await tester.pumpWidget(
        _withKeyboard(
          _raised,
          AppKeyboardInset(
            builder: (_, value) {
              delivered.add(value);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // A sheet opened over a raised keyboard must be in place, not slide into
      // it. The tween has no `begin`, so it starts at its end.
      expect(delivered, [_raised]);
    });
  });

  group('showAppBottomSheet', () {
    const childKey = Key('sheet-child');

    /// The inset as the sheet's own box and its own padding each report it —
    /// the two places that used to read `viewInsets` directly.
    ({double fromHeight, double fromPadding}) insetsInSheet(
      WidgetTester tester,
    ) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.byKey(childKey), matching: find.byType(Container))
            .first,
      );
      final padding = tester.widget<Padding>(
        find
            .ancestor(of: find.byKey(childKey), matching: find.byType(Padding))
            .first,
      );
      return (
        fromHeight: box.constraints!.maxHeight - _screen.height * 0.9,
        fromPadding: (padding.padding as EdgeInsets).bottom - _sheetPadding,
      );
    }

    testWidgets('moves its height and its padding on one travelling inset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _SheetHost(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.showAppBottomSheet(
                child: const SizedBox(key: childKey, height: 40),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      tester.state<_SheetHostState>(find.byType(_SheetHost)).raiseKeyboard(
        _raised,
      );
      await tester.pump();
      await tester.pump(AppKeyboardInset.duration ~/ 2);

      final midTravel = insetsInSheet(tester);
      expect(midTravel.fromPadding, greaterThan(0));
      expect(midTravel.fromPadding, lessThan(_raised));

      // The half that matters. Either value left on the raw inset arrives a
      // frame after the tap while the other is still travelling, and the two
      // halves of the sheet visibly slide apart — worse than the snap this
      // removes.
      expect(midTravel.fromHeight, closeTo(midTravel.fromPadding, 0.01));

      await tester.pumpAndSettle();
      final settled = insetsInSheet(tester);
      expect(settled.fromPadding, closeTo(_raised, 0.01));
      expect(settled.fromHeight, closeTo(_raised, 0.01));
    });
  });
}
