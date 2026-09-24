import 'dart:io';

import 'package:dartway_generator/dartway_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/temp_project.dart';

void main() {
  test(
    'every problem is reported at once, located, and nothing is written',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('errors');
      final report = await project.generate();
      final printed = report.diagnostics
          .map((d) => d.format(project.root))
          .join('\n');
      expectGolden('$printed\n', 'errors/diagnostics.txt');
      expect(report.written, isEmpty);
      expect(
        Directory(project.path('app_shared/lib'))
            .listSync(recursive: true)
            .where((entity) => entity.path.endsWith('.dw.dart')),
        isEmpty,
      );
      expect(
        report.summary,
        startsWith(
          'dartway generate: ${report.diagnostics.length} errors, nothing written',
        ),
      );
    },
  );

  test('a shared package without a version has no contract version: '
      'refused, and nothing is written (#296)', () async {
    final project = TempProject.create(['app_shared']);
    project.copyFixture('types');
    final pubspec = File(project.path('app_shared/pubspec.yaml'));
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst('version: 0.1.0\n', ''),
    );
    final report = await project.generate();
    expect(
      report.diagnostics.map((d) => d.message),
      contains(startsWith('app_shared declares no semantic `version:`')),
    );
    expect(report.written, isEmpty);
  });

  group('project layout', () {
    test('a directory without DartWay packages', () async {
      final empty = Directory.systemTemp.createTempSync('dw_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));
      final report = await DwCodeGenerator.run(empty.path);
      expect(
        report.diagnostics.single.message,
        startsWith('no DartWay package in '),
      );
      expect(report.diagnostics.single.path, isNull);
    });

    test('a package without pub get', () async {
      final project = TempProject.create(['app_shared']);
      Directory(
        project.path('app_shared/.dart_tool'),
      ).deleteSync(recursive: true);
      final report = await project.generate();
      expect(
        report.diagnostics.single.format(project.root),
        'app_shared has no resolved package config; run `dart pub get` in '
        '${project.path('app_shared')} first',
      );
    });

    test('an app package without pub get does not stop the contract and the '
        'server, and is named', () async {
      // Mid-port: the app still resolves against the old framework, or not at
      // all, while the shared and server packages are being moved.
      final project = TempProject.create(['app_shared', 'app_flutter']);
      Directory(
        project.path('app_flutter/.dart_tool'),
      ).deleteSync(recursive: true);
      final report = await project.generate();
      expect(report.diagnostics, isEmpty);
      expect(report.skipped, ['app_flutter']);
      expect(
        report.summary,
        endsWith('not scanned: app_flutter — run `dart pub get` there'),
      );

      // --check cannot say "up to date" about a package it did not read.
      final check = await project.generate(check: true);
      expect(
        check.diagnostics.single.message,
        startsWith('app_flutter has no resolved package config'),
      );
    });

    test('two packages of one role', () async {
      final project = TempProject.create(['app_shared', 'other_shared']);
      final report = await project.generate();
      expect(
        report.diagnostics.single.message,
        'several *_shared packages in ${project.root} (app_shared, '
        'other_shared); a project has one',
      );
    });

    test('a single package can be the project', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      final report = await DwCodeGenerator.run(project.path('app_shared'));
      expect(report.diagnostics, isEmpty);
      expect(report.written.map(p.basename), contains('dw_protocol.dart'));
    });
  });
}
