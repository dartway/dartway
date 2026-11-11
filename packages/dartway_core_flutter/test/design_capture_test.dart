import 'dart:convert';

import 'package:dartway_core_flutter/testing.dart';
import 'package:flutter/material.dart';
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

  testWidgets('captures effective text, paint, and real ellipsis state', (
    tester,
  ) async {
    const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
    if (output.isEmpty) return;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'InheritedFamily',
            fontSize: 18,
            color: Color(0xff123456),
          ),
          child: ColoredBox(
            color: Color(0xffabcdef),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 30,
                child: Text(
                  'A deliberately long label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final file = await captureDwDesign(tester, caseId: 'capture-fixture');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final nodes = (json['nodes']! as List).cast<Map<String, Object?>>();
    final text = nodes.singleWhere((node) => node['text'] != null);
    expect(text['truncated'], isTrue);
    expect((text['textStyle']! as Map)['fontFamily'], 'InheritedFamily');
    expect((text['textStyle']! as Map)['fontSize'], 18.0);
    expect(
      nodes.any((node) => node['fill'] == 'rgba(171, 205, 239, 1.000)'),
      isTrue,
    );
  });
}
