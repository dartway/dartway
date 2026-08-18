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

  test('the server package is checked too', () {
    final serverDir = Directory(p.join(sandbox.path, 'my_server'))
      ..createSync(recursive: true);
    for (final entry in ['lib/src/crud', 'lib/src/models', 'lib/src/utils']) {
      Directory(p.join(serverDir.path, entry)).createSync(recursive: true);
    }
    File(p.join(serverDir.path, 'lib', 'server.dart')).writeAsStringSync('');

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

    expect(inspector.findings, hasLength(1));
    expect(inspector.findings.single, contains('my_server/lib/src/utils'));
  });
}
