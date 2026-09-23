import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:dartway_lints/dartway_lints.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ForbiddenUiStyleUsageTest);
    defineReflectiveTests(DeepRelativeImportTest);
    defineReflectiveTests(ForbiddenProviderScopeTest);
  });
}

/// Stand-ins for the Flutter types the rules name: they match by name, and by
/// `BuildContext` as a static type, so no Flutter is needed to prove them.
const _flutter = '''
class Color { const Color(int value); }
class TextStyle { const TextStyle(); }
class BorderRadius {
  const BorderRadius();
  factory BorderRadius.circular(double r) => const BorderRadius();
}
class Colors { static const red = Color(0); }
class ThemeData {}
class Theme { static ThemeData of(BuildContext context) => ThemeData(); }
class BuildContext {}
extension Kit on BuildContext { ThemeData get theme => ThemeData(); }
''';

/// Offset and length of [snippet] in [source], for `lint(...)`.
(int, int) _at(String source, String snippet) {
  final offset = source.indexOf(snippet);
  if (offset < 0) throw ArgumentError('`$snippet` is not in the source');
  return (offset, snippet.length);
}

@reflectiveTest
class ForbiddenUiStyleUsageTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ForbiddenUiStyleUsageRule();
    super.setUp();
    // In ui_kit/, where the rule does not look: the stand-ins construct
    // styles themselves.
    newFile('$testPackageLibPath/ui_kit/flutter.dart', _flutter);
  }

  Future<void> test_every_form_outside_ui_kit() async {
    const source = """
import '../ui_kit/flutter.dart';

final a = Color(1);
final b = TextStyle();
final c = Colors.red;
final d = BorderRadius.circular(8);
ThemeData e(BuildContext ctx) => ctx.theme;
ThemeData f(BuildContext context) => Theme.of(context);
""";
    final path = '$testPackageLibPath/app/screen.dart';
    newFile(path, source);
    await assertDiagnosticsInFile(path, [
      for (final snippet in const [
        'Color(1)',
        'TextStyle()',
        'Colors.red',
        'BorderRadius.circular(8)',
        'ctx.theme',
        'Theme.of(context)',
      ])
        () {
          final (offset, length) = _at(source, snippet);
          return lint(offset, length);
        }(),
    ]);
  }

  Future<void> test_ui_kit_may_use_them() async {
    final path = '$testPackageLibPath/ui_kit/palette.dart';
    newFile(path, """
import 'flutter.dart';

final a = Color(1);
final c = Colors.red;
""");
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_a_variable_named_context_that_is_not_one() async {
    final path = '$testPackageLibPath/app/screen.dart';
    newFile(path, """
class Settings { int get theme => 1; }
int f(Settings context) => context.theme;
""");
    await assertNoDiagnosticsInFile(path);
  }
}

@reflectiveTest
class DeepRelativeImportTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = DeepRelativeImportRule();
    super.setUp();
  }

  Future<void> test_three_levels_up_is_reported_two_are_not() async {
    newFile('$testPackageLibPath/ui_kit/kit.dart', '');
    newFile('$testPackageLibPath/app/group/sibling/sibling.dart', '');
    const source = '''
// ignore_for_file: unused_import
import '../../../ui_kit/kit.dart';
import '../sibling/sibling.dart';
''';
    final path = '$testPackageLibPath/app/group/feature/feature.dart';
    newFile(path, source);
    final (offset, length) = _at(source, "'../../../ui_kit/kit.dart'");
    await assertDiagnosticsInFile(path, [lint(offset, length)]);
  }
}

@reflectiveTest
class ForbiddenProviderScopeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ForbiddenProviderScopeRule();
    super.setUp();
  }

  static const _scope = '''
class ProviderScope { const ProviderScope({Object? child}); }
''';

  /// The test package lives under `/home/test`: a folder named `test` above
  /// the project does not make the project's files tests.
  Future<void> test_the_app_may_not_write_one() async {
    const source = '''
$_scope
final scope = ProviderScope(child: null);
''';
    final path = '$testPackageLibPath/app/screen.dart';
    newFile(path, source);
    final (offset, length) = _at(source, 'ProviderScope(child');
    await assertDiagnosticsInFile(path, [
      lint(offset, length - '(child'.length),
    ]);
  }

  Future<void> test_a_test_may() async {
    final path = '$testPackageRootPath/test/screen_test.dart';
    newFile(path, '''
$_scope
final scope = ProviderScope(child: null);
''');
    await assertNoDiagnosticsInFile(path);
  }
}
