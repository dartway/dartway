import 'package:dartway_starter_flutter/core/router/app_scaffold.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

void main() {
  testWidgets('each opening focuses input at the platform’s required time', (
    tester,
  ) async {
    final app = await TestApp.start(tester, FakeApp());
    late FocusNode input;
    late VoidCallback dismiss;
    await app.mountQuickEntry(
      tester,
      AppQuickSheetEntry(
        openLabel: 'Open entry',
        dismissLabel: 'Close entry',
        builder: (_, focus, close) {
          input = focus;
          dismiss = close;
          return TextField(focusNode: focus);
        },
      ),
    );
    for (var opening = 0; opening < 2; opening++) {
      await tester.tap(find.byTooltip('Open entry'));
      if (kIsWeb) {
        // Gesture focus reaches the already mounted primer before a frame.
        final primer = tester.widget<AppKeyboardPrimer>(
          find.byType(AppKeyboardPrimer),
        );
        expect(primer.focusNode.hasFocus, isTrue);
      }
      await tester.pump();
      if (kIsWeb) {
        await tester.pump();
        expect(input.hasFocus, isTrue);
      } else {
        expect(input.hasFocus, isFalse);
        await tester.pump(const Duration(milliseconds: 149));
        expect(input.hasFocus, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(input.hasFocus, isTrue);
      }
      await tester.pumpAndSettle();
      dismiss();
      await tester.pumpAndSettle();
      expect(input.hasFocus, isFalse);
      expect(find.byType(TextField), findsNothing);
    }
    await app.stop(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'navigation and footer reveal before the keyboard reaches zero without remounting',
    (tester) async {
      final app = await TestApp.start(tester, FakeApp());
      late VoidCallback dismiss;
      await app.mountQuickEntry(
        tester,
        AppQuickSheetEntry(
          openLabel: 'Open entry',
          dismissLabel: 'Close entry',
          builder: (_, focus, close) {
            dismiss = close;
            return TextField(focusNode: focus);
          },
        ),
      );
      final navigation = tester.element(find.byType(BottomNavigationBar));
      final footer = tester.element(find.byType(AppVersionLabel));
      final navRect = tester.getRect(find.byType(BottomNavigationBar));
      final footerRect = tester.getRect(find.byType(AppVersionLabel));
      await tester.tap(find.byTooltip('Open entry'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      final fades = find.descendant(
        of: find.byType(AppNavigationKeyboardScope),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fades.first).opacity.value, 0);
      dismiss();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      final opacity = tester.widget<FadeTransition>(fades.first).opacity.value;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(
        tester.element(find.byType(BottomNavigationBar)),
        same(navigation),
      );
      expect(tester.element(find.byType(AppVersionLabel)), same(footer));
      expect(tester.getRect(find.byType(BottomNavigationBar)), navRect);
      expect(tester.getRect(find.byType(AppVersionLabel)), footerRect);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await app.stop(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
