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

  group('project layout', () {
    test('a directory without DartWay packages', () async {
      final empty = Directory.systemTemp.createTempSync('dw_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));
      final report = await DwGenerator.run(empty.path);
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
      final report = await DwGenerator.run(project.path('app_shared'));
      expect(report.diagnostics, isEmpty);
      expect(report.written.map(p.basename), contains('dw_protocol.dart'));
    });
  });
}
