import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/checker/dw_framework_overrides.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An override a project added to take a satellite before the core raised its
/// caret (D-032) must be named once the core allows the version on its own —
/// and must stay silent while it is still what makes the project resolve.
void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_overrides'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  /// An installed framework package, as pub unpacks it, depending on
  /// `dartway_router` by [routerConstraint].
  String installCore(String routerConstraint) {
    final dir = Directory(p.join(sandbox.path, 'cache', 'dartway_core_flutter'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      'name: dartway_core_flutter\n'
      'version: 0.20.0\n'
      'dependencies:\n'
      '  dartway_router: "$routerConstraint"\n',
    );
    return dir.path;
  }

  /// The `app_flutter` package: its override, its lock, its package config.
  void writeApp({
    required Object override,
    required String resolvedRouter,
    required String corePath,
  }) {
    final dir = Directory(p.join(sandbox.path, 'app_flutter'))
      ..createSync(recursive: true);
    final overrideYaml = override is String
        ? '  dartway_router: "$override"\n'
        : '  dartway_router:\n    path: ../../framework/packages/dartway_router\n';
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      'name: app_flutter\n'
      'dependencies:\n'
      '  dartway_core_flutter: ^0.20.0\n'
      'dependency_overrides:\n$overrideYaml',
    );
    File(p.join(dir.path, 'pubspec.lock')).writeAsStringSync(
      'packages:\n'
      '  dartway_router:\n'
      '    dependency: "direct overridden"\n'
      '    description:\n'
      '      name: dartway_router\n'
      '      url: "https://pub.dev"\n'
      '    source: hosted\n'
      '    version: "$resolvedRouter"\n'
      'sdks:\n  dart: ">=3.11.0 <4.0.0"\n',
    );
    final tool = Directory(p.join(dir.path, '.dart_tool'))..createSync();
    File(p.join(tool.path, 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'dartway_core_flutter',
            'rootUri': Uri.file('$corePath/').toString(),
            'packageUri': 'lib/',
          },
        ],
      }),
    );
  }

  List<String> findings() {
    final inspector = DwFrameworkOverridesInspector(projectRoot: sandbox);
    inspector.run();
    return inspector.findings;
  }

  test('an override the core now allows is named, with the fix', () {
    writeApp(
      override: '^1.3.0',
      resolvedRouter: '1.3.2',
      corePath: installCore('^1.3.0'),
    );
    final found = findings().single;
    expect(found, contains('app_flutter overrides `dartway_router: ^1.3.0`'));
    expect(found, contains('dartway_core_flutter'));
    expect(
      found,
      contains('remove the override from app_flutter/pubspec.yaml'),
    );
  });

  test('an override beyond the core\'s range is still needed, and silent', () {
    writeApp(
      override: '^1.3.0',
      resolvedRouter: '1.3.2',
      corePath: installCore('>=1.2.0 <1.3.0'),
    );
    expect(findings(), isEmpty);
  });

  test(
    'a path override points at a checkout, not a version, and is left alone',
    () {
      writeApp(
        override: const {'path': true},
        resolvedRouter: '1.3.2',
        corePath: installCore('^1.3.0'),
      );
      expect(findings(), isEmpty);
    },
  );
}
