import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A token declared `static const` does not depend on a context, so changing
/// `ThemeData` does not touch it: the theme switches and the kit stays as it
/// was. Nothing else says so — the analyzer is quiet, the tests are green —
/// and it surfaces on the day somebody asks for a light theme, as a rewrite of
/// every token read in the kit.
///
/// The exemption is `ui_kit/theme/`, and it comes with its pair below: a seed
/// colour has to be written down somewhere, and that is the one place in the
/// kit that does not read from a context.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_ui_kit_const');
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  Future<Set<DwCheckType>> findingsFor(String relative, String body) async {
    File(p.join(sandbox.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: sandbox_flutter\n');

    File(p.join(sandbox.path, 'lib', relative))
      ..createSync(recursive: true)
      ..writeAsStringSync("part of '../ui_kit.dart';\n\n$body");

    final inspector = DwFlutterInspector(packageDir: sandbox);
    await inspector.run();
    return inspector.findingTypes;
  }

  group('a token that will not survive a second theme', () {
    test('a const Color in a kit widget is reported', () async {
      final findings = await findingsFor('ui_kit/app_card.dart', '''
class _AppChrome {
  static const Color mutedColor = Color(0xFF888888);
}
''');

      expect(findings, contains(DwCheckType.uiKitConstStyle));
    });

    test('a const TextStyle is reported the same way', () async {
      final findings = await findingsFor('ui_kit/app_text.dart', '''
class AppTextStyles {
  static const TextStyle body = TextStyle(fontSize: 14);
}
''');

      expect(findings, contains(DwCheckType.uiKitConstStyle));
    });

    test('an inferred type is the same mistake, and the usual spelling',
        () async {
      // `static const muted = Color(0xFF888888)` is how this is written more
      // often than with the type spelled out; a rule that missed it would
      // report the rarer half of the problem.
      final findings = await findingsFor('ui_kit/app_tone.dart', '''
class AppTone {
  static const muted = Color(0xFF888888);
}
''');

      expect(findings, contains(DwCheckType.uiKitConstStyle));
    });

    test('a palette held in a collection is reported too', () async {
      final findings = await findingsFor('ui_kit/app_palette.dart', '''
class AppPalette {
  static const Map<String, Color> tones = {};
}
''');

      expect(findings, contains(DwCheckType.uiKitConstStyle));
    });

    test('it is a warning, not a failure — one theme is a legitimate state',
        () {
      expect(DwCheckType.uiKitConstStyle.severity, DwCheckSeverity.warning);
    });
  });

  group('what the rule must not punish', () {
    test('the theme folder may hold a seed colour', () async {
      // Where the theme is assembled is the one place in the kit that does not
      // read from a context. Without this exemption the rule fires on every
      // project's palette and gets switched off.
      final findings = await findingsFor('ui_kit/theme/app_theme.dart', '''
class AppTheme {
  static const Color _seed = Color.fromARGB(255, 4, 49, 57);
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitConstStyle)));
    });

    test('a colour taken from the context is the shape being asked for',
        () async {
      final findings = await findingsFor('ui_kit/app_card.dart', '''
class AppCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
      );
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitConstStyle)));
    });

    test('a name that merely contains the word is not a type', () async {
      // `iconColor` is a name. A rule that reported it would be narrowed
      // within a week, and a narrowed rule stops firing where it mattered.
      final findings = await findingsFor('ui_kit/app_icon.dart', '''
class AppIcon {
  static const double iconColorOpacity = 0.6;
  static const String colorKey = 'color';
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitConstStyle)));
    });

    test('a const that is neither a colour nor a text style is not the rule',
        () async {
      // Geometry does not depend on the theme and stays constant — the issue
      // says so explicitly, and a rule that swept it up would be wrong.
      final findings = await findingsFor('ui_kit/app_metrics.dart', '''
class AppMetrics {
  static const double cardRadius = 12;
  static const EdgeInsets pagePadding = EdgeInsets.all(16);
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitConstStyle)));
    });

    test('a mention inside a comment is prose, not a declaration', () async {
      final findings = await findingsFor('ui_kit/app_note.dart', '''
class AppNote {
  // static const Color legacy = Color(0xFF000000);
  static Color of(BuildContext context) => Theme.of(context).colorScheme.error;
}
''');

      expect(findings, isNot(contains(DwCheckType.uiKitConstStyle)));
    });
  });
}
