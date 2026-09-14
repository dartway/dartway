import 'dart:io';

import 'package:dartway_cli/src/checker/dw_layout.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The top level of a DartWay app is a closed list, and this is the rule that
/// keeps it closed. It exists because the list had been written down in three
/// places — the docs, the agent toolkit and the checker — which then drifted
/// apart quietly: the docs put the admin panel inside `app/`, the toolkit and
/// the checker expected it at the top, and nothing ever compared them.
///
/// The two cases worth defending are at the ends: an undeclared folder (the
/// list stops being a list) and a declared name one level too deep (`app/admin`
/// compiles, runs and looks deliberate — nothing but this rule objects).
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_layout');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// Writes a Flutter package whose `lib/` holds [entries] — a folder for a
  /// path ending in `/`, a file otherwise — and returns what the rule says.
  List<String> findingsFor(List<String> entries, {String name = 'my_flutter'}) {
    final packageDir = Directory(p.join(sandbox.path, name))
      ..createSync(recursive: true);
    File(
      p.join(packageDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: $name\n');

    for (final entry in entries) {
      final path = p.join(packageDir.path, 'lib', entry);
      if (entry.endsWith('/')) {
        Directory(path).createSync(recursive: true);
      } else {
        File(path)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('');
      }
    }

    final inspector = DwLayoutInspector(flutterPackageDir: packageDir);
    inspector.run();
    return inspector.findings;
  }

  const declaredLayout = [
    'main.dart',
    'my_app.dart',
    'app/',
    'admin/',
    'auth/',
    'core/',
    'l10n/',
    'shared/',
    'ui_kit/',
  ];

  test('the declared layout passes, and `common/` may be absent', () {
    expect(findingsFor(declaredLayout), isEmpty);
  });

  test('an undeclared folder is reported', () {
    expect(
      findingsFor([...declaredLayout, 'features/']),
      contains(contains('lib/features')),
    );
  });

  test('`data/` and `domain/` are undeclared — they were once', () {
    final findings = findingsFor([...declaredLayout, 'data/', 'domain/']);
    expect(findings, hasLength(2));
    expect(findings.join(), allOf(contains('data'), contains('domain')));
  });

  test('a stray file at the root of lib/ is reported', () {
    expect(
      findingsFor([...declaredLayout, 'app_router.dart']),
      contains(contains('app_router.dart')),
    );
  });

  test('the wiring file carries the project name, and is required', () {
    expect(
      findingsFor(declaredLayout.where((e) => e != 'my_app.dart').toList()),
      contains(contains('my_app.dart')),
    );
  });

  test('a zone nested inside a zone is reported — `app/admin/`', () {
    final findings = findingsFor([...declaredLayout, 'app/admin/']);
    expect(findings, hasLength(1));
    expect(
      findings.single,
      allOf(contains('lib/app/admin'), contains('/admin')),
    );
  });

  test('a nested zone is found at any depth', () {
    expect(
      findingsFor([...declaredLayout, 'app/learning/lesson/common/']),
      contains(contains('lib/app/learning/lesson/common')),
    );
  });

  test('a feature keeps its own widgets/ and logic/', () {
    expect(
      findingsFor([
        ...declaredLayout,
        'app/bookings/widgets/',
        'app/bookings/logic/',
        'shared/widgets/',
      ]),
      isEmpty,
    );
  });

  /// A server package named `my_server` holding [entries] under `lib/`.
  Directory serverWith(List<String> entries) {
    final serverDir = Directory(p.join(sandbox.path, 'my_server'))
      ..createSync(recursive: true);
    File(
      p.join(serverDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: my_server\n');
    for (final entry in entries) {
      final path = p.join(serverDir.path, 'lib', entry);
      if (entry.endsWith('/')) {
        Directory(path).createSync(recursive: true);
      } else {
        File(path)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('');
      }
    }
    return serverDir;
  }

  List<String> serverFindings(Directory serverDir) {
    final packageDir = Directory(p.join(sandbox.path, 'my_flutter'))
      ..createSync(recursive: true);
    File(
      p.join(packageDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: my_flutter\n');
    final inspector = DwLayoutInspector(
      flutterPackageDir: packageDir,
      serverPackageDir: serverDir,
    );
    inspector.run();
    return inspector.findings;
  }

  const serverLayout = [
    'my_server.dart',
    'generated/dw_schema.dart',
    'src/entities/people.dart',
    'src/handlers/profile_handlers.dart',
    'src/chat/chat_files.dart',
    'src/auth.dart',
    'src/migrations/migrations.dart',
  ];

  test('the server package: its library, generated/ and src/, whatever src/ '
      'holds besides its migrations', () {
    expect(serverFindings(serverWith(serverLayout)), isEmpty);
  });

  test('the server package: anything else beside its library is reported, '
      'and so is the 0.x layout', () {
    final findings = serverFindings(
      serverWith([...serverLayout, 'server.dart', 'utils/']),
    );
    expect(findings, hasLength(2));
    expect(
      findings.join('\n'),
      allOf(
        contains('my_server/lib/server.dart'),
        contains('my_server/lib/utils'),
      ),
    );
  });

  test('the server package: its library and the migrations registry are '
      'fixed names', () {
    final findings = serverFindings(serverWith(['src/handlers/']));
    expect(findings, hasLength(2));
    expect(
      findings.join('\n'),
      allOf(
        contains('my_server/lib/my_server.dart is missing'),
        contains('lib/src/migrations/migrations.dart is missing'),
      ),
    );
  });
}
