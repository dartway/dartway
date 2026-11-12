import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'is a no-op outside design-check before settling the widget tree',
    (tester) async {
      const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
      if (output.isNotEmpty) return;
      expect(await captureDwDesign(tester, caseId: 'not-requested'), isNull);
    },
  );

  testWidgets('rejects a case id the command did not request', (tester) async {
    final output = Directory.systemTemp.createTempSync('dw-design-capture-');
    addTearDown(() => output.deleteSync(recursive: true));
    await expectLater(
      captureDwDesign(
        tester,
        caseId: 'not-requested',
        outputDirectory: output.path,
        requestedCases: {'requested'},
      ),
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
    final output = Directory.systemTemp.createTempSync('dw-design-capture-');
    addTearDown(() => output.deleteSync(recursive: true));
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
    final file = await captureDwDesign(
      tester,
      caseId: 'capture-fixture',
      outputDirectory: output.path,
    );
    final json = jsonDecode(file!.readAsStringSync()) as Map<String, Object?>;
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

  testWidgets('keeps a decorated label as separate paint and text nodes', (
    tester,
  ) async {
    final output = Directory.systemTemp.createTempSync('dw-design-capture-');
    addTearDown(() => output.deleteSync(recursive: true));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xff123456)),
            child: Padding(padding: EdgeInsets.all(12), child: Text('Badge')),
          ),
        ),
      ),
    );
    final file = await captureDwDesign(
      tester,
      caseId: 'decorated-label',
      outputDirectory: output.path,
    );
    final json = jsonDecode(file!.readAsStringSync()) as Map<String, Object?>;
    final nodes = (json['nodes']! as List).cast<Map<String, Object?>>();
    final paint = nodes.singleWhere((node) => node['fill'] != null);
    final text = nodes.singleWhere((node) => node['text'] == 'Badge');
    expect(paint['text'], isNull);
    expect(text['fill'], isNull);
    expect(
      (paint['rect']! as List)[2],
      greaterThan((text['rect']! as List)[2] as num),
    );
  });

  testWidgets('captures material paint and excludes invisible subtrees', (
    tester,
  ) async {
    final output = Directory.systemTemp.createTempSync('dw-design-capture-');
    addTearDown(() => output.deleteSync(recursive: true));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Card(child: Text('Visible card')),
              Icon(Icons.save),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color(0xff123456),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Color(0xffabcdef)),
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                ),
                child: SizedBox(width: 20, height: 20),
              ),
              Offstage(child: Text('Offstage text')),
              Opacity(opacity: 0, child: Text('Transparent text')),
            ],
          ),
        ),
      ),
    );
    final file = await captureDwDesign(
      tester,
      caseId: 'material-fixture',
      outputDirectory: output.path,
    );
    final json = jsonDecode(file!.readAsStringSync()) as Map<String, Object?>;
    final nodes = (json['nodes']! as List).cast<Map<String, Object?>>();
    expect(
      nodes.any((node) => node['path'].toString().startsWith('image#')),
      isTrue,
    );
    expect(
      nodes.any((node) => node['fill'] == 'rgba(18, 52, 86, 1.000)'),
      isTrue,
    );
    expect(nodes.any((node) => node['text'] == 'Offstage text'), isFalse);
    expect(nodes.any((node) => node['text'] == 'Transparent text'), isFalse);
  });
}
