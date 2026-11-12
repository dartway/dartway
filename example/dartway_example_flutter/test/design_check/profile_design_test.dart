import 'package:dartway_core_flutter/testing.dart';
import 'package:dartway_example_flutter/design_check/profile_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captures the published profile card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileDesign())),
    );

    await captureDwDesign(tester, caseId: 'profile-compact-375x812');
  });
}
