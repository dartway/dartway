import 'dart:io';

import 'package:dartway_cli/src/checker/dw_analysis_options.dart';
import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A stored row's id is `int`, so `row.id!` hides the `!` that guards a real
/// null (D-113). The server and the shared package raise the analyzer's
/// `unnecessary_non_null_assertion` to an error, and the checker holds that
/// they do.
void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_analysis'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  Directory package(String name, {String? options, Map<String, String>? more}) {
    final dir = Directory(p.join(sandbox.path, name))..createSync();
    if (options != null) {
      File(
        p.join(dir.path, 'analysis_options.yaml'),
      ).writeAsStringSync(options);
    }
    for (final MapEntry(:key, :value) in (more ?? const {}).entries) {
      File(p.join(dir.path, key))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(value);
    }
    return dir;
  }

  const raised = '''
include: package:lints/recommended.yaml

analyzer:
  errors:
    unnecessary_non_null_assertion: error
''';

  DwAnalysisOptionsInspector inspect(List<Directory?> dirs) =>
      DwAnalysisOptionsInspector(packageDirs: dirs);

  test('the template raises it in both packages', () {
    final repo = Directory.current.parent.parent;
    final inspector = inspect([
      Directory(p.join(repo.path, 'template', 'dartway_starter_server')),
      Directory(p.join(repo.path, 'template', 'dartway_starter_shared')),
    ]);
    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
  });

  test('raised to error in both packages: nothing to report', () {
    final inspector = inspect([
      package('app_server', options: raised),
      package('app_shared', options: raised),
    ]);
    final tally = DwCheckTally();
    expect(inspector.run(tally: tally), 0);
    expect(tally.errors, 0);
  });

  test('left at its default, set lower, or no file at all: an error each', () {
    final inspector = inspect([
      package(
        'app_server',
        options: 'include: package:lints/recommended.yaml\n',
      ),
      package(
        'app_shared',
        options:
            'analyzer:\n  errors:\n    unnecessary_non_null_assertion: warning\n',
      ),
      package('app_tools'),
    ]);
    final tally = DwCheckTally();
    expect(inspector.run(tally: tally), 3);
    expect(tally.errors, 3);
    expect(inspector.findings, [
      allOf(contains('app_server/'), contains('does not set')),
      allOf(contains('app_shared/'), contains('sets `warning`')),
      allOf(contains('app_tools/'), contains('does not set')),
    ]);
  });

  test('a local file it includes counts, the package file winning', () {
    final shared = package(
      'app_shared',
      options: 'include: ../analysis/strict.yaml\n',
    );
    Directory(p.join(sandbox.path, 'analysis')).createSync();
    File(
      p.join(sandbox.path, 'analysis', 'strict.yaml'),
    ).writeAsStringSync(raised);
    final server = package(
      'app_server',
      options:
          'include: ../analysis/strict.yaml\n'
          'analyzer:\n  errors:\n    unnecessary_non_null_assertion: ignore\n',
    );
    final inspector = inspect([server, shared]);
    expect(inspector.run(), 1);
    expect(inspector.findings.single, contains('app_server/'));
  });

  test('a package not found is not judged', () {
    expect(inspect([null, null]).run(), 0);
  });

  test('its level is error: it is part of the law', () {
    expect(DwCheckType.redundantBangAllowed.severity, DwCheckSeverity.error);
  });
}
