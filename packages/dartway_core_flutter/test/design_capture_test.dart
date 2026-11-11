import 'package:dartway_core_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires design-check output before settling the widget tree', (
    tester,
  ) async {
    const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
    if (output.isNotEmpty) return;
    await expectLater(
      captureDwDesign(tester, caseId: 'not-requested'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('must run through dartway design-check'),
        ),
      ),
    );
  });

  testWidgets('rejects a case id the command did not request', (tester) async {
    const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
    if (output.isEmpty) return;
    await expectLater(
      captureDwDesign(tester, caseId: 'not-requested'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unknown design-check case id'),
        ),
      ),
    );
  });
}
