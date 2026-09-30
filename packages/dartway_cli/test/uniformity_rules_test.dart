import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_uniformity_rules.dart';
import 'package:dartway_cli/src/lints_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One way to write the ordinary things (dartway/dartway#391, #379, #396):
/// each rule proved on the shape it refuses and on the shapes beside it that
/// it must leave alone — a rule that fires on its neighbour is the one people
/// learn to skip.
void main() {
  group('relativeImport', () {
    test('a relative import or export in lib/ is found, with its line', () {
      expect(
        DwUniformityInspector.relativeImportsIn('''
import 'package:flutter/material.dart';
import 'dart:async';
import '../core/dw_core.dart';
export 'widgets/body.dart' show Body;
'''),
        [(3, '../core/dw_core.dart'), (4, 'widgets/body.dart')],
      );
    });

    test('a conditional import is judged in every alternative', () {
      expect(
        DwUniformityInspector.relativeImportsIn(
          "import 'package:acme/a.dart' if (dart.library.js_interop) 'a_web.dart';",
        ).map((finding) => finding.$2),
        ['a_web.dart'],
      );
    });

    test('an import written in a comment or a string is not one', () {
      expect(
        DwUniformityInspector.relativeImportsIn('''
/// Write `import 'widgets/x.dart';` and the check fails.
// import '../old.dart';
const example = "import 'nope.dart';";
'''),
        isEmpty,
      );
    });

    test('--fix writes the package: form of the same file', () {
      final fixed = DwUniformityInspector.packageImportsFor(
        "import '../../core/dw_core.dart';\nimport 'widgets/body.dart';\n"
            "import 'package:flutter/material.dart';\n",
        'app/profile/profile_page.dart',
        'acme_flutter',
      );
      expect(fixed.lines, [1, 2]);
      expect(
        fixed.content,
        "import 'package:acme_flutter/core/dw_core.dart';\n"
        "import 'package:acme_flutter/app/profile/widgets/body.dart';\n"
        "import 'package:flutter/material.dart';\n",
      );
    });

    test('a path that climbs out of lib/ is left for its author', () {
      expect(
        DwUniformityInspector.packageUriFor('../../x.dart', 'a.dart', 'acme'),
        isNull,
      );
    });
  });

  group('docCommentLanguage', () {
    const english = '''
/// Shows the member's bookings for the week, newest first.
class Bookings {}
''';
    const russian = '''
/// Показывает записи участника на неделю, свежие сверху.
class Bookings {}
''';

    test('an English doc comment in a Russian project is reported', () {
      expect(DwUniformityInspector.docCommentsNotIn(english, 'ru'), [1]);
      expect(DwUniformityInspector.docCommentsNotIn(russian, 'ru'), isEmpty);
    });

    test('a Russian doc comment in an English project is reported', () {
      expect(DwUniformityInspector.docCommentsNotIn(russian, 'en'), [1]);
      expect(DwUniformityInspector.docCommentsNotIn(english, 'en'), isEmpty);
    });

    test('code, references and names are not words of a language', () {
      expect(
        DwUniformityInspector.docCommentsNotIn('''
/// Запись: [BookingRow] → `ListMyBookings(weekStart: monday)`.
class A {}

/// See [DwFeatureSpec].
class B {}
''', 'ru'),
        isEmpty,
      );
    });

    test(
      'a checker warning, never an error: a guess must not fail a build',
      () {
        expect(
          DwCheckType.docCommentLanguage.severity,
          DwCheckSeverity.warning,
        );
      },
    );
  });

  group('testLayout', () {
    String? problem(
      String rel, {
      Set<String> files = const {},
      Set<String> folders = const {},
    }) => DwUniformityInspector.testPathProblem(
      rel,
      libFileExists: files.contains,
      libDirectoryExists: folders.contains,
    );

    test('a test at the mirror of a lib/ file passes', () {
      expect(
        problem(
          'app/profile/profile_page/profile_page_test.dart',
          files: {'app/profile/profile_page/profile_page.dart'},
        ),
        isNull,
      );
    });

    test('a test that mirrors nothing is reported', () {
      expect(problem('contract_test.dart'), contains('mirrors nothing'));
      expect(
        problem(
          'profile_page_test.dart',
          files: {'app/profile/profile_page/profile_page.dart'},
        ),
        contains('mirrors nothing'),
      );
    });

    test('an acceptance test names the folder it sits at the mirror of', () {
      expect(
        problem('src/chat/chat_acceptance_test.dart', folders: {'src/chat'}),
        isNull,
      );
      expect(
        problem('chat_acceptance_test.dart', folders: {'src/chat'}),
        contains('acceptance test'),
      );
      expect(
        problem(
          'src/chat/messages_acceptance_test.dart',
          folders: {'src/chat'},
        ),
        contains('acceptance test'),
      );
    });

    test('helpers live in test/support/, and only helpers do', () {
      expect(problem('support/app_harness.dart'), isNull);
      expect(problem('support/deep/fixtures.dart'), isNull);
      expect(problem('src/chat/chat_support.dart'), contains('helper'));
      expect(problem('support/harness_test.dart'), contains('test/support/'));
    });
  });

  group('testHarnessBypassed', () {
    test('a widget test building its own scope or fake server', () {
      expect(
        DwUniformityInspector.harnessBypassesIn('''
await tester.pumpWidget(ProviderScope(child: App()));
final server = DwFakeServer(protocol: appProtocol);
''', server: false).map((finding) => finding.$2),
        ['ProviderScope', 'DwFakeServer'],
      );
    });

    test('reading the scope the harness built is not building one', () {
      expect(
        DwUniformityInspector.harnessBypassesIn(
          'final router = ProviderScope.containerOf(context).read(p);',
          server: false,
        ),
        isEmpty,
      );
    });

    test('a server test starting a server of its own', () {
      expect(
        DwUniformityInspector.harnessBypassesIn('''
final server = await DwTestServer.start(DwAppServer(features: const []));
''', server: true).map((finding) => finding.$2),
        ['DwTestServer.start', 'DwAppServer'],
      );
      expect(
        DwUniformityInspector.harnessBypassesIn(
          'final club = await AppHarness.start();',
          server: true,
        ),
        isEmpty,
      );
    });
  });

  group('rawSpacing', () {
    List<String> spacing(String code) => [
      for (final finding in DwUniformityInspector.rawSpacingIn(code))
        finding.$2,
    ];

    test('a number as a gap or an inset is reported', () {
      expect(
        spacing('''
const a = Gap(12);
const b = SizedBox(height: 16);
const c = EdgeInsets.all(8);
const d = EdgeInsets.symmetric(horizontal: 16, vertical: AppSpace.s);
final e = EdgeInsets.only(top: first ? 6 : AppSpace.xs);
const f = EdgeInsetsDirectional.fromSTEB(AppSpace.s, 0, 4, 0);
'''),
        [
          'Gap(12)',
          'SizedBox(height: 16)',
          'EdgeInsets.all(8)',
          'EdgeInsets.symmetric(horizontal: 16, vertical: AppSpace.s)',
          'EdgeInsets.only(top: first ? 6 : AppSpace.xs)',
          'EdgeInsetsDirectional.fromSTEB(AppSpace.s, 0, 4, 0)',
        ],
      );
    });

    test('tokens, zero, infinity and a sized child pass', () {
      expect(
        spacing('''
const a = Gap(AppSpace.m);
const b = SizedBox(height: AppSpace.l);
const c = EdgeInsets.all(AppSpace.s);
const d = EdgeInsets.zero;
const e = EdgeInsets.only(bottom: 0);
const f = SizedBox(width: double.infinity, child: AppButton());
const g = SizedBox(height: 52, child: ChipStrip());
const h = SizedBox(width: 24, height: 24, key: ValueKey(3));
// Gap(8) in a comment is prose.
'''),
        ['SizedBox(width: 24, height: 24, key: ValueKey(3))'],
      );
    });
  });

  group('lintsPluginMissing', () {
    late Directory sandbox;
    setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_lints'));
    tearDown(() => sandbox.deleteSync(recursive: true));

    File options([String? content]) {
      final file = File(p.join(sandbox.path, 'analysis_options.yaml'));
      if (content != null) file.writeAsStringSync(content);
      return file;
    }

    test('a Flutter package without the plugin is reported', () {
      expect(DwUniformityInspector.lintsPluginProblem(sandbox), isNotNull);
      options('include: package:flutter_lints/flutter.yaml\n');
      expect(
        DwUniformityInspector.lintsPluginProblem(sandbox),
        contains('dartway update'),
      );
      options('plugins:\n  dartway_lints: ^0.5.0\n');
      expect(DwUniformityInspector.lintsPluginProblem(sandbox), isNull);
      options('plugins:\n  dartway_lints:\n    path: ../lints\n');
      expect(DwUniformityInspector.lintsPluginProblem(sandbox), isNull);
    });

    test('update wires it pinned, keeping what the file says', () {
      final file = options(
        '# ours\ninclude: package:flutter_lints/flutter.yaml\n',
      );
      expect(wireLintsPlugin(file, '0.5.0'), contains('enabled'));
      expect(
        file.readAsStringSync(),
        allOf(
          startsWith('# ours\ninclude: package:flutter_lints/flutter.yaml\n'),
          contains('plugins:\n  dartway_lints: ^0.5.0\n'),
        ),
      );
      expect(DwUniformityInspector.lintsPluginProblem(sandbox), isNull);
      expect(wireLintsPlugin(file, '0.5.0'), isNull, reason: 'idempotent');
    });

    test('update joins an existing plugins section, and raises a caret', () {
      final file = options('plugins:\n  other_plugin: ^1.0.0\n');
      wireLintsPlugin(file, '0.5.0');
      expect(
        file.readAsStringSync(),
        'plugins:\n  dartway_lints: ^0.5.0\n  other_plugin: ^1.0.0\n',
      );

      options('plugins:\n  dartway_lints: ^0.4.0\n');
      expect(wireLintsPlugin(file, '0.5.0'), contains('raised'));
      expect(file.readAsStringSync(), 'plugins:\n  dartway_lints: ^0.5.0\n');
    });

    test('a plugin taken from a path is a choice, and left alone', () {
      final file = options('plugins:\n  dartway_lints:\n    path: ../lints\n');
      expect(wireLintsPlugin(file, '0.5.0'), isNull);
    });

    test('a missing file is created with the plugin', () {
      final file = options();
      expect(wireLintsPlugin(file, '0.5.0'), contains('created'));
      expect(file.readAsStringSync(), 'plugins:\n  dartway_lints: ^0.5.0\n');
    });
  });

  group('the inspector over a project', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('dw_uniformity'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) {
      final file = File(p.join(root.path, path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    Directory dir(String name) => Directory(p.join(root.path, name));

    test('judges every package, and each rule where it belongs', () {
      write('acme_flutter/pubspec.yaml', 'name: acme_flutter\n');
      write(
        'acme_flutter/analysis_options.yaml',
        'plugins:\n  dartway_lints: ^0.5.0\n',
      );
      write('acme_flutter/lib/app/home/home_page.dart', '''
import '../../core/dw_core.dart';
const gap = Gap(8);
''');
      write('acme_flutter/lib/core/dw_core.dart', '');
      write('acme_flutter/lib/ui_kit/app_card.dart', 'const p = Gap(8);');
      write('acme_flutter/lib/l10n/gen/app_l10n.dart', "import 'en.dart';");
      write(
        'acme_flutter/test/app/home/home_page_test.dart',
        'final s = ProviderScope(child: null);',
      );
      write('acme_flutter/test/support/app_test_app.dart', '');
      write('acme_server/pubspec.yaml', 'name: acme_server\n');
      write('acme_server/lib/src/chat/chat_feature.dart', '');
      write('acme_server/lib/generated/dw_schema.dart', "import '../x.dart';");
      write('acme_server/test/chat_acceptance_test.dart', '');
      write('acme_shared/pubspec.yaml', 'name: acme_shared\n');
      write('acme_shared/lib/acme_shared.dart', "export 'src/chat.dart';");
      write('acme_shared/test/acme_shared_test.dart', '');

      final inspector = DwUniformityInspector(
        projectRoot: root,
        flutterPackageDir: dir('acme_flutter'),
        serverPackageDir: dir('acme_server'),
        sharedPackageDir: dir('acme_shared'),
      );
      expect(inspector.run(), 5);
      expect(
        [
          for (final finding in inspector.findings)
            '${finding.type.name} ${finding.path}',
        ],
        unorderedEquals([
          'relativeImport acme_flutter/lib/app/home/home_page.dart',
          'rawSpacing acme_flutter/lib/app/home/home_page.dart',
          'testHarnessBypassed acme_flutter/test/app/home/home_page_test.dart',
          'testLayout acme_server/test/chat_acceptance_test.dart',
          'relativeImport acme_shared/lib/acme_shared.dart',
        ]),
      );
      expect(inspector.notes.single, contains('docCommentLanguage'));
    });

    test('fixRelativeImports rewrites lib/ and leaves generated code', () {
      write('acme_server/pubspec.yaml', 'name: acme_server\n');
      write('acme_server/lib/src/a.dart', "import 'b.dart';\n");
      write(
        'acme_server/lib/generated/dw_schema.dart',
        "import '../a.dart';\n",
      );
      expect(DwUniformityInspector.fixRelativeImports([dir('acme_server')]), [
        'acme_server/lib/src/a.dart:1',
      ]);
      expect(
        File(
          p.join(root.path, 'acme_server/lib/src/a.dart'),
        ).readAsStringSync(),
        "import 'package:acme_server/src/b.dart';\n",
      );
      expect(
        File(
          p.join(root.path, 'acme_server/lib/generated/dw_schema.dart'),
        ).readAsStringSync(),
        "import '../a.dart';\n",
      );
    });

    test('reads the language the toolkit install recorded', () {
      write('.claude/dartway-toolkit.json', '''
{"source": "x", "cliVersion": "0", "installedAt": "0", "settings": {"language": "Russian"}}
''');
      write('acme_flutter/pubspec.yaml', 'name: acme_flutter\n');
      write(
        'acme_flutter/analysis_options.yaml',
        'plugins:\n  dartway_lints: ^0.5.0\n',
      );
      write('acme_flutter/lib/core/app_version.dart', '''
/// The version of the app as the store knows it, with its build number.
class AppVersion {}
''');
      final inspector = DwUniformityInspector(
        projectRoot: root,
        flutterPackageDir: dir('acme_flutter'),
      );
      expect(inspector.run(), 0);
      expect(inspector.findings.single.type, DwCheckType.docCommentLanguage);
      expect(inspector.findings.single.message, contains('not in ru'));
    });
  });
}
