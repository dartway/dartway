import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the builder with an optional [Form] around it, so the tests can put
/// the guard exactly where apps now put it: under a button inside a form, and
/// under anything at all outside one.
Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  bool withForm = false,
  GlobalKey<FormState>? formKey,
  String? Function(String?)? validator,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: withForm
          ? Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(validator: validator),
                  child,
                ],
              ),
            )
          : child,
    ),
  ),
);

Widget _button(DwUiAction<void> action, {bool requireValidation = true}) =>
    DwActionBuilder(
      action: action,
      requireValidation: requireValidation,
      builder: (context, onPressed, busy) =>
          ElevatedButton(onPressed: onPressed, child: Text(busy ? '…' : 'Go')),
    );

void main() {
  // One DwFlutter per test process — the singleton forbids re-creation.
  // Registers itself as the ambient `dw`, so `testDw.action(...)` works.
  final testDw = DwFlutter(config: const DwConfig());

  group('DwActionBuilder with requireValidation', () {
    testWidgets('shouts at build time when there is no Form', (tester) async {
      // The regression this guards: `Form.maybeOf(context)?.validate() ?? false`
      // meant no form => never valid => the action never ran, with no exception,
      // no log, nothing. The button was simply dead. Since the guard can now sit
      // under any widget, drifting out of the Form is easy — so it must be loud,
      // and loud *before* the first tap that would have done nothing.
      await _pump(
        tester,
        child: _button(testDw.action((_) async {})),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('runs the action when the enclosing form is valid', (
      tester,
    ) async {
      var ran = false;
      await _pump(
        tester,
        withForm: true,
        validator: (_) => null,
        child: _button(testDw.action((_) async => ran = true)),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(ran, isTrue);
    });

    testWidgets('cancels the action when the enclosing form is invalid', (
      tester,
    ) async {
      var ran = false;
      await _pump(
        tester,
        withForm: true,
        validator: (_) => 'required',
        child: _button(testDw.action((_) async => ran = true)),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(ran, isFalse);
    });
  });

  group('DwActionBuilder', () {
    testWidgets('runs without a Form when validation is not required', (
      tester,
    ) async {
      var ran = false;
      await _pump(
        tester,
        child: _button(
          testDw.action((_) async => ran = true),
          requireValidation: false,
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(ran, isTrue);
    });

    testWidgets('blocks a re-entrant tap and reports busy', (tester) async {
      // The whole reason this widget exists: an in-flight action must not be
      // started twice by an impatient finger.
      final gate = Completer<void>();
      var runs = 0;

      await _pump(
        tester,
        child: _button(
          testDw.action((_) async {
            runs++;
            await gate.future;
          }),
          requireValidation: false,
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(runs, 1);
      expect(find.text('…'), findsOneWidget, reason: 'busy is reported');

      // The button is disabled while busy (onPressed is null), so a second tap
      // cannot even reach the handler.
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(runs, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Go'), findsOneWidget, reason: 'busy is cleared');
    });

    testWidgets('hands the builder a null onPressed when there is no action', (
      tester,
    ) async {
      await _pump(
        tester,
        child: DwActionBuilder(
          action: null,
          builder: (context, onPressed, busy) =>
              ElevatedButton(onPressed: onPressed, child: const Text('Go')),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });
}
