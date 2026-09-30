import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_uniformity_rules.dart';
import 'package:dartway_cli/src/lints_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

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

    test('a literal inside the condition is not a URI', () {
      expect(
        DwUniformityInspector.relativeImportsIn(
          "import 'package:acme/a.dart' "
          "if (dart.library.io == 'true') 'a_io.dart';",
        ).map((finding) => finding.$2),
        ['a_io.dart'],
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

  group('relativeImport, the edges', () {
    test('a URI with a scheme is not relative, whatever the scheme', () {
      expect(
        DwUniformityInspector.relativeImportsIn(
          "import 'file:///tmp/x.dart';\nimport 'dart:io';\n",
        ),
        isEmpty,
      );
    });

    test('a directive quoted in a multi-line string is not one', () {
      expect(
        DwUniformityInspector.relativeImportsIn(
          "const sample = '''\nimport 'widgets/x.dart';\n''';\n",
        ),
        isEmpty,
      );
    });

    test('--fix rewrites every alternative of a conditional import', () {
      final fixed = DwUniformityInspector.packageImportsFor(
        "import 'platform/io.dart' if (dart.library.js_interop) "
            "'platform/web.dart';\n",
        'core/platform.dart',
        'acme',
      );
      expect(
        fixed.content,
        "import 'package:acme/core/platform/io.dart' if "
        "(dart.library.js_interop) 'package:acme/core/platform/web.dart';\n",
      );
    });

    test('part and part of are left alone', () {
      const source =
          "import 'package:acme/a.dart';\npart 'kit.dw.dart';\n"
          "part of '../ui_kit.dart';\n";
      expect(DwUniformityInspector.relativeImportsIn(source), isEmpty);
      expect(
        DwUniformityInspector.packageImportsFor(source, 'x/y.dart', 'acme'),
        (content: source, lines: const <int>[]),
      );
    });

    test('the rewritten block is sorted as directives_ordering wants', () {
      expect(
        DwUniformityInspector.sortedImports(
          "import 'package:flutter/widgets.dart';\n"
          "import 'dart:async';\n\n"
          "import 'package:acme/core/a.dart' show A;\n"
          "\nclass B {}\n",
        ),
        "import 'dart:async';\n\n"
        "import 'package:acme/core/a.dart' show A;\n"
        "import 'package:flutter/widgets.dart';\n"
        "\nclass B {}\n",
      );
      const commented =
          "import 'package:b/b.dart';\n// why a is second\nimport 'package:a/a.dart';\n";
      expect(
        DwUniformityInspector.sortedImports(commented),
        commented,
        reason: 'a comment inside the block is left in its place',
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

  group('docCommentLanguage, the edges', () {
    test('a comment the skeleton wrote is the skeleton\'s', () {
      const content = '''
/// The member's own profile, as the server publishes it.
class Profile {}

/// A project's own English comment, in a Russian project.
class Other {}
''';
      expect(
        DwUniformityInspector.docCommentsNotIn(
          content,
          'ru',
          inherited: {"The member's own profile, as the server publishes it."},
        ),
        [4],
      );
    });

    test('macros, templates and indented code are not prose', () {
      expect(
        DwUniformityInspector.docCommentsNotIn('''
/// {@template acme.booking_card}
/// Карточка записи.
/// {@endtemplate}
class A {}

/// Пример:
///
///     final card = BookingCard(booking: booking, onCancel: cancel);
class B {}

/// {@macro acme.booking_card}
class C {}
''', 'ru'),
        isEmpty,
      );
    });

    test('an indented example is code, not the comment\'s language', () {
      expect(
        DwUniformityInspector.docCommentsNotIn('''
/// Example:
///
///     final label = Text(ruLabelЗаписатьсяНаТренировкуСейчасЖеПожалуйста);
class A {}
''', 'en'),
        isEmpty,
      );
    });

    test('in an English project, quoted Russian UI copy is not the prose', () {
      expect(
        DwUniformityInspector.docCommentsNotIn('''
/// Shows the "Записаться на тренировку" button until the session is full.
class A {}

/// Показывает кнопку «Записаться», пока есть места.
class B {}
''', 'en'),
        [4],
      );
    });

    test('a file a tool wrote is nobody\'s', () {
      expect(
        DwUniformityInspector.isGeneratedText(
          '// File generated by FlutterFire CLI.\n// ignore_for_file: x\n',
        ),
        isTrue,
      );
      expect(
        DwUniformityInspector.isGeneratedText('/// The app.\nclass App {}\n'),
        isFalse,
      );
    });
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

  group('testLayout, scenarios and the move', () {
    test('a scenario of a feature follows the <feature>_* naming', () {
      expect(
        DwUniformityInspector.testPathProblem(
          'src/chat/chat_attachments_acceptance_test.dart',
          libFileExists: (_) => false,
          libDirectoryExists: {'src/chat'}.contains,
        ),
        isNull,
      );
      expect(
        DwUniformityInspector.testPathProblem(
          'src/chat/attachments_acceptance_test.dart',
          libFileExists: (_) => false,
          libDirectoryExists: {'src/chat'}.contains,
        ),
        contains('named after it'),
      );
    });

    test('--fix moves a root acceptance test to its feature\'s mirror', () {
      final root = Directory.systemTemp.createTempSync('dw_tests_move');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String content) => File(p.join(root.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
      write('lib/src/chat/chat_feature.dart', '');
      write('lib/src/chat_files/chat_files_feature.dart', '');
      write(
        'test/chat_files_upload_acceptance_test.dart',
        "import 'package:test/test.dart';\n\n"
            "import 'support/app_harness.dart';\n",
      );
      write('test/chat_acceptance_test.dart', "import 'support/x.dart';\n");
      write('test/billing_acceptance_test.dart', '');
      expect(DwUniformityInspector.fixTestLayout([root]), [
        '${p.basename(root.path)}/test/chat_acceptance_test.dart → '
            'test/src/chat/chat_acceptance_test.dart',
        '${p.basename(root.path)}/test/chat_files_upload_acceptance_test.dart'
            ' → test/src/chat_files/chat_files_upload_acceptance_test.dart',
      ]);
      expect(
        File(
          p.join(
            root.path,
            'test/src/chat_files/chat_files_upload_acceptance_test.dart',
          ),
        ).readAsStringSync(),
        "import 'package:test/test.dart';\n\n"
        "import '../../support/app_harness.dart';\n",
      );
      expect(
        File(
          p.join(root.path, 'test/billing_acceptance_test.dart'),
        ).existsSync(),
        isTrue,
        reason: 'no lib/src/billing/ to mirror: left for its author',
      );
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
const d = EdgeInsets.symmetric(horizontal: 16, vertical: AppSpace.s8);
final e = EdgeInsets.only(top: first ? 6 : AppSpace.s4);
const f = EdgeInsetsDirectional.fromSTEB(AppSpace.s8, 0, 4, 0);
final g = SizedBox(width: wide ? AppSpace.s16 : 12);
'''),
        [
          'Gap(12)',
          'SizedBox(height: 16)',
          'EdgeInsets.all(8)',
          'EdgeInsets.symmetric(horizontal: 16, vertical: AppSpace.s8)',
          'EdgeInsets.only(top: first ? 6 : AppSpace.s4)',
          'EdgeInsetsDirectional.fromSTEB(AppSpace.s8, 0, 4, 0)',
          'SizedBox(width: wide ? AppSpace.s16 : 12)',
        ],
      );
    });

    test('the spacing of a flex, a Wrap and a grid is spacing too', () {
      expect(
        spacing('''
Row(spacing: 8, children: []);
Wrap(spacing: AppSpace.s8, runSpacing: dense ? 4 : AppSpace.s8);
GridView.count(mainAxisSpacing: 12, crossAxisSpacing: AppSpace.s12);
Column(spacing: AppSpace.s6, children: []);
'''),
        [
          'spacing: 8',
          'runSpacing: dense ? 4 : AppSpace.s8',
          'mainAxisSpacing: 12',
        ],
      );
    });

    test('tokens, zero, infinity and a dimension pass', () {
      expect(
        spacing('''
const a = Gap(AppSpace.s12);
const b = SizedBox(height: AppSpace.s16);
const c = EdgeInsets.all(AppSpace.s8);
const d = EdgeInsets.zero;
const e = EdgeInsets.only(bottom: 0);
const f = SizedBox(width: double.infinity, child: AppButton());
const g = SizedBox(height: 52, child: ChipStrip());
const h = SizedBox(width: 24, height: 24, key: ValueKey(3));
const i = SizedBox.square(dimension: 40);
const j = Row(spacing: 0);
// Gap(8) in a comment is prose.
'''),
        isEmpty,
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

    String? problem() => DwUniformityInspector.lintsPluginProblem(sandbox);

    /// The file still parses, and names the plugin exactly once.
    void parsesWithPlugin(File file, Object expected) {
      final document = loadYaml(file.readAsStringSync()) as YamlMap;
      expect((document['plugins'] as YamlMap)['dartway_lints'], expected);
      expect(problem(), isNull);
    }

    test('a Flutter package without the plugin is reported', () {
      expect(problem(), isNotNull);
      options('include: package:flutter_lints/flutter.yaml\n');
      expect(problem(), contains('dartway update'));
      options('plugins:\n  dartway_lints: ^0.5.0\n');
      expect(problem(), isNull);
      options('plugins:\n  dartway_lints:\n    path: ../lints\n');
      expect(problem(), isNull);
    });

    test('a pin that resolves to nothing is reported too', () {
      options('plugins:\n  dartway_lints:\n');
      expect(problem(), contains('neither a version nor a path'));
      options('plugins:\n  dartway_lints: latest-please\n');
      expect(problem(), contains('not a version constraint'));
      options('plugins:\n  dartway_lints:\n    path: ""\n');
      expect(problem(), contains('neither a version nor a path'));
    });

    test('update appends the section, keeping what the file says', () {
      final file = options(
        '# ours\ninclude: package:flutter_lints/flutter.yaml\n',
      );
      expect(wireLintsPlugin(file, '0.5.0').change, contains('enabled'));
      expect(
        file.readAsStringSync(),
        startsWith('# ours\ninclude: package:flutter_lints/flutter.yaml\n'),
      );
      parsesWithPlugin(file, '^0.5.0');
      expect(wireLintsPlugin(file, '0.5.0'), (change: null, manual: null));
    });

    test('update joins a block section at its entries\' indentation', () {
      final file = options(
        'plugins:\n    other_plugin: ^1.0.0\nlinter:\n  rules: []\n',
      );
      wireLintsPlugin(file, '0.5.0');
      expect(
        file.readAsStringSync(),
        'plugins:\n    dartway_lints: ^0.5.0\n    other_plugin: ^1.0.0\n'
        'linter:\n  rules: []\n',
      );
      parsesWithPlugin(file, '^0.5.0');
    });

    test('update fills an empty section: bare, commented, or {}', () {
      for (final section in [
        'plugins:\n',
        'plugins: # ours\n',
        'plugins: {}\n',
        'plugins: {} # ours\n',
      ]) {
        final file = options('include: x.yaml\n$section\nlinter: {}\n');
        expect(
          wireLintsPlugin(file, '0.5.0').change,
          isNotNull,
          reason: section,
        );
        parsesWithPlugin(file, '^0.5.0');
        if (section.contains('#')) {
          expect(file.readAsStringSync(), contains('# ours'));
        }
      }
    });

    test('a section it cannot edit safely is handed to the person', () {
      for (final source in [
        'plugins: {other_plugin: ^1.0.0}\n',
        'plugins: [other_plugin]\n',
        'plugins:\n  dartway_lints: latest-please\n',
        'plugins: [\n',
      ]) {
        final file = options(source);
        final wiring = wireLintsPlugin(file, '0.5.0');
        expect(wiring.change, isNull, reason: source);
        expect(
          wiring.manual,
          contains('dartway_lints: ^0.5.0'),
          reason: source,
        );
        expect(file.readAsStringSync(), source, reason: 'left as it was');
      }
    });

    test('a caret behind is raised, its comment and line ending kept', () {
      final file = options(
        'plugins:\r\n  dartway_lints: ^0.4.0 # pinned\r\nlinter: {}\r\n',
      );
      expect(wireLintsPlugin(file, '0.5.0').change, contains('raised'));
      expect(
        file.readAsStringSync(),
        'plugins:\r\n  dartway_lints: ^0.5.0 # pinned\r\nlinter: {}\r\n',
      );

      options('plugins:\n  dartway_lints:\n    version: ^0.4.0\n');
      expect(wireLintsPlugin(file, '0.5.0').change, contains('raised'));
      parsesWithPlugin(file, {'version': '^0.5.0'});
    });

    test('CRLF files get CRLF lines', () {
      final file = options('include: x.yaml\r\nplugins:\r\n  a: ^1.0.0\r\n');
      wireLintsPlugin(file, '0.5.0');
      expect(
        file.readAsStringSync(),
        'include: x.yaml\r\nplugins:\r\n  dartway_lints: ^0.5.0\r\n'
        '  a: ^1.0.0\r\n',
      );
    });

    test('a plugin taken from a path is a choice, and left alone', () {
      final file = options('plugins:\n  dartway_lints:\n    path: ../lints\n');
      expect(wireLintsPlugin(file, '0.5.0'), (change: null, manual: null));
    });

    test('with a checkout, the plugin is pinned to it by path', () {
      final file = options('plugins:\n  other_plugin: ^1.0.0\n');
      wireLintsPlugin(
        file,
        '0.5.0',
        path: '/work/dartway/packages/dartway_lints',
      );
      parsesWithPlugin(file, {'path': '/work/dartway/packages/dartway_lints'});
    });

    test('a missing file is created with flutter_lints and the plugin', () {
      final file = options();
      expect(wireLintsPlugin(file, '0.5.0').change, contains('created'));
      expect(
        file.readAsStringSync(),
        startsWith('include: package:flutter_lints/flutter.yaml\n'),
      );
      parsesWithPlugin(file, '^0.5.0');
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

  test('a quoted package name in pubspec.yaml is the same name', () {
    final root = Directory.systemTemp.createTempSync('dw_quoted');
    addTearDown(() => root.deleteSync(recursive: true));
    File(
      p.join(root.path, 'pubspec.yaml'),
    ).writeAsStringSync("name: 'acme_server' # quoted\n");
    File(p.join(root.path, 'lib', 'src', 'a.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync("import 'b.dart';\n");
    DwUniformityInspector.fixRelativeImports([root]);
    expect(
      File(p.join(root.path, 'lib', 'src', 'a.dart')).readAsStringSync(),
      "import 'package:acme_server/src/b.dart';\n",
    );
  });
}
