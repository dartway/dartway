import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A parent that owns the value the way a real screen does: it holds state,
/// rebuilds when the field reports a change, and can be made to rebuild for
/// reasons of its own.
class _Host extends StatefulWidget {
  const _Host({this.deliverChanges = true});

  /// When false the parent ignores `onChanged` — which is how a value lagging
  /// behind the field is reproduced deterministically.
  final bool deliverChanges;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String value = '';

  void setValue(String newValue) => setState(() => value = newValue);

  void rebuildWithoutChangingValue() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AppTextFormField(
          value: value,
          onChanged: (text) {
            if (widget.deliverChanges) setValue(text);
          },
        ),
      ),
    );
  }
}

void main() {
  final field = find.byType(TextFormField);

  String fieldText(WidgetTester tester) =>
      tester.widget<TextFormField>(field).controller!.text;

  _HostState host(WidgetTester tester) =>
      tester.state<_HostState>(find.byType(_Host));

  group('AppTextFormField', () {
    testWidgets('reports what was typed', (tester) async {
      await tester.pumpWidget(const _Host());

      await tester.enterText(field, 'Fitness Club');
      await tester.pumpAndSettle();

      expect(host(tester).value, 'Fitness Club');
    });

    testWidgets('a stale parent value does not truncate what is typed', (
      tester,
    ) async {
      // The regression this replaced: `onChanged` reaches the parent a frame
      // late, so between a keystroke and the parent catching up `widget.value`
      // is stale. A rebuild landing in that window looked like an external
      // change and overwrote the field, cursor to the end — typing then
      // continued on a truncated prefix, and "Fitness Club" reached the
      // database as "Fitne".
      //
      // Both halves have to be here: a parent whose value lags, **and** a
      // rebuild while it lags. Typing alone never reproduced it, because with
      // no rebuild `didUpdateWidget` does not run at all.
      await tester.pumpWidget(const _Host(deliverChanges: false));

      for (final text in ['F', 'Fi', 'Fit', 'Fitn', 'Fitne', 'Fitness']) {
        await tester.enterText(field, text);
        await tester.pump();
        host(tester).rebuildWithoutChangingValue();
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'Fitness');
    });

    testWidgets('an unrelated rebuild leaves the field alone', (tester) async {
      await tester.pumpWidget(const _Host(deliverChanges: false));
      await tester.enterText(field, 'typed');
      await tester.pumpAndSettle();

      host(tester).rebuildWithoutChangingValue();
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'typed');
    });

    testWidgets('adopts a value the parent really changed', (tester) async {
      await tester.pumpWidget(const _Host(deliverChanges: false));
      await tester.enterText(field, 'typed');
      await tester.pumpAndSettle();

      host(tester).setValue('from the parent');
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'from the parent');
    });
  });
}
