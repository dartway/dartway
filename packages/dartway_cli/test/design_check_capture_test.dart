import 'dart:io';

import 'package:dartway_cli/src/commands/design_check_command.dart';
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
<p>&amp;lt;literal&amp;gt;</p></body></html>''');
      final output = Directory('${directory.path}/output')..createSync();

      final spec = await captureDesignReferenceForTesting(
        output,
        chrome!,
        'entity-style-375x812',
        html,
        (375, 812),
      );

      final paragraph = spec.nodes.singleWhere((node) => node.path == 'p');
      expect(paragraph.text, '&lt;literal&gt;');
      expect(paragraph.fill, 'rgb(210, 211, 212)');
      expect(paragraph.textStyle['color'], 'rgb(12, 34, 56)');
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
