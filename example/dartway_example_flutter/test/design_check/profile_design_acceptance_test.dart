import 'package:dartway_core_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_design.dart';

void main() {
  testWidgets('captures the published profile card', (tester) async {
    for (final captureCase in dwDesignCheckCases) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(captureCase.width, captureCase.height);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileDesign())),
      );

      await captureDwDesign(tester, caseId: captureCase.id);
    }
  });
}
