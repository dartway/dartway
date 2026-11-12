import 'dart:io';

import 'package:dartway_cli/src/commands/design_check_command.dart';
import 'package:dartway_cli/src/design_check/design_compare.dart';
import 'package:dartway_cli/src/design_check/design_spec.dart';
import 'package:test/test.dart';

void main() {
  final chrome = _chrome();
  test(
    'capture preserves literal entities and applies relative stylesheets',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dw-capture-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/style.css').writeAsStringSync(
        'p { color: rgb(12, 34, 56); background: rgb(210, 211, 212); }',
      );
      final html = File('${directory.path}/screen.html')
        ..writeAsStringSync('''<!doctype html><html><head>
<link rel="stylesheet" href="style.css"></head><body>
<p>&amp;lt;literal&amp;gt; <b>mixed</b></p></body></html>''');
      final output = Directory('${directory.path}/output')..createSync();

      final spec = await captureDesignReferenceForTesting(
        output,
        chrome!,
        'entity-style-375x812',
        html,
        (375, 812),
      );

      final paint = spec.nodes.singleWhere((node) => node.path == 'p');
      final paragraph = spec.nodes.singleWhere((node) => node.path == 'p-text');
      expect(paragraph.text, '&lt;literal&gt; mixed');
      expect(paint.fill, 'rgb(210, 211, 212)');
      expect(paragraph.fill, isNull);
      expect(paragraph.stroke, isNull);
      expect(paragraph.textStyle['color'], 'rgb(12, 34, 56)');
      expect(spec.nodes.where((node) => node.text != null), hasLength(1));
      final flutterText = DesignNode(
        path: 'RenderParagraph#0',
        rect: paragraph.rect,
        text: paragraph.text,
        textStyle: paragraph.textStyle,
      );
      expect(
        compareDesignSpecs(
          DesignSpec(viewport: spec.viewport, nodes: [paragraph]),
          DesignSpec(viewport: spec.viewport, nodes: [flutterText]),
        ),
        isEmpty,
      );
    },
    skip: chrome == null ? 'Chrome/Chromium is not installed.' : false,
  );
}

String? _chrome() {
  for (final name in ['google-chrome', 'chromium', 'chromium-browser']) {
    final result = Process.runSync('which', [name]);
    if (result.exitCode == 0) return (result.stdout as String).trim();
  }
  return null;
}
