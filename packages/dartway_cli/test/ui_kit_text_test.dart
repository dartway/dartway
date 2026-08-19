import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `uiKitContainsText` guesses, and it is allowed to because a kit file has no
/// content to speak of. The guess still has to tell a typeface from a label: a
/// font family is read by the platform's font matcher and by nobody else, it is
/// never translated, and the kit is exactly where fonts belong — so the finding
/// named a line with no fix behind it, and the only route to a green check was
/// to make the style worse.
///
/// Every exemption here comes with its pair. Narrowing a rule is easy to
/// overdo, and a check that quietly stops firing costs more than the false
/// positive it was narrowed for.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_ui_kit_text');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// Writes one kit file and returns the inspector that has read it.
  Future<DwFlutterInspector> checkKitFile(String body) async {
    File(p.join(sandbox.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: sandbox_flutter\n');

    File(p.join(sandbox.path, 'lib', 'ui_kit', 'app_text_styles.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync("part of '../ui_kit.dart';\n\n$body");

    final inspector = DwFlutterInspector(packageDir: sandbox);
    await inspector.run();
    return inspector;
  }

  Future<Set<DwCheckType>> kitFindings(String body) async =>
      (await checkKitFile(body)).findingTypes;

  group('a font family is not a label', () {
    test('fontFamily and fontFamilyFallback on one line', () async {
      final findings = await kitFindings('''
class AppTextStyles {
  static const logLine = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Courier New', 'monospace'],
  );
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitContainsText)));
    });

    test('a fallback list dart format broke across lines', () async {
      final findings = await kitFindings('''
class AppTextStyles {
  static const logLine = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: [
      'SF Mono',
      'Courier New',
    ],
  );
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitContainsText)));
    });
  });

  group('the rule still catches what it exists for', () {
    test('a label sharing the line that closes the fallback list', () async {
      final findings = await kitFindings('''
class AppTextStyles {
  static const logLine = TextStyle(
    fontFamilyFallback: [
      'SF Mono',
      'Courier New',
    ], // Save changes
  );
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitContainsText)));
    });

    test('a label after the bracket that closes the list is reported', () async {
      // The list opened on an earlier line, so there is no `[` on this one to
      // measure the exemption against — it ends at the `]` instead. Carrying it
      // to the end of the line would swallow everything written after the list.
      final inspector = await checkKitFile('''
class AppTextStyles {
  static const logLine = TextStyle(
    fontFamilyFallback: [
      'SF Mono',
      'Courier New',
    ], debugLabel: 'Nothing here yet',
  );
}
''');

      expect(inspector.findingTypes, contains(DwCheckType.uiKitContainsText));
      expect(
        inspector.findingMessages,
        contains(contains('"Nothing here yet"')),
      );
    });

    test('a label in the kit is reported', () async {
      final findings = await kitFindings('''
class AppEmptyState {
  static const title = 'Nothing here yet';
}
''');

      expect(findings, contains(DwCheckType.uiKitContainsText));
    });

    test(
      'the file goes on being read after the fallback list closes',
      () async {
        final findings = await kitFindings('''
class AppTextStyles {
  static const logLine = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: [
      'Courier New',
    ],
  );

  static const emptyState = 'Nothing here yet';
}
''');

        expect(findings, contains(DwCheckType.uiKitContainsText));
      },
    );

    test('a label beside a font family is reported, and it is the label that '
        'gets named', () async {
      // The exemption is positional rather than per line: the literal in the
      // `fontFamily` argument is stepped over and the reading continues, so a
      // label sharing the line is still found — and the message quotes the
      // label rather than the first string it happened to see.
      final inspector = await checkKitFile('''
class AppTextStyles {
  static const logLine =
      TextStyle(fontFamily: 'monospace', debugLabel: 'Nothing here yet');
}
''');

      expect(inspector.findingTypes, contains(DwCheckType.uiKitContainsText));
      expect(
        inspector.findingMessages,
        contains(contains('"Nothing here yet"')),
      );
    });
  });
}
