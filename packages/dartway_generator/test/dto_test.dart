import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support/temp_project.dart';

void main() {
  group('dartway_core reference fixture', () {
    test('booking_view.dw.dart is reproduced from booking_view.dart', () async {
      final project = TempProject.create(['app_shared']);
      final fixtures = p.join(
        frameworkPackages,
        'dartway_core',
        'test',
        'fixtures',
      );
      project.writeFile(
        'app_shared/lib/src/booking_view.dart',
        File(p.join(fixtures, 'booking_view.dart')).readAsStringSync(),
      );
      await project.generateClean();

      // The reference is hand-written "in dart format output"; one of its
      // declarations (`$RenameBookingFromJson`, an 81-column line) is not what
      // `dart format` produces. The generator's contract is dart-formatted
      // output, so the comparison is with the reference after a format pass —
      // which changes exactly that one declaration and nothing else.
      final reference = File(
        p.join(fixtures, 'booking_view.dw.dart'),
      ).readAsStringSync();
      final formattedReference = DartFormatter(
        languageVersion: Version(3, 11, 0),
      ).format(reference);
      expect(
        project.readFile('app_shared/lib/src/booking_view.dw.dart'),
        formattedReference,
      );
      expect(await project.analyze('app_shared'), isNull);
    });
  });

  group('every supported type', () {
    late TempProject project;

    setUp(() async {
      project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();
    });

    test('parts and registry match the goldens', () {
      for (final name in ['catalog', 'units', 'empty']) {
        expectGolden(
          project.readFile('app_shared/lib/src/$name.dw.dart'),
          'types/$name.dw.dart',
        );
      }
      expectGolden(
        project.readFile('app_shared/lib/generated/dw_protocol.dart'),
        'types/dw_protocol.dart',
      );
    });

    test('generated code is clean under strict analysis', () async {
      expect(await project.analyze('app_shared'), isNull);
    });

    test('every DTO round-trips through JSON text', () async {
      final result = await project.runScript(
        'app_shared',
        'bin/round_trip.dart',
      );
      expect(result.stdout, 'ok\n', reason: '${result.stderr}');
      expect(result.exitCode, 0);
    });
  });

  group('writing', () {
    test('a second run writes nothing', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      final first = await project.generateClean();
      expect(first.written, hasLength(4));
      final stamps = {
        for (final path in first.written) path: File(path).lastModifiedSync(),
      };

      final second = await project.generateClean();
      expect(second.written, isEmpty);
      expect(second.removed, isEmpty);
      expect(second.unchanged, first.written);
      for (final MapEntry(key: path, value: stamp) in stamps.entries) {
        expect(File(path).lastModifiedSync(), stamp, reason: path);
      }
      expect(
        second.summary,
        startsWith('dartway generate: 0 written, 4 unchanged, 0 removed'),
      );
    });

    test(
      'output does not depend on the directory it is generated in',
      () async {
        final a = TempProject.create(['app_shared']);
        final b = TempProject.create(['app_shared']);
        a.copyFixture('types');
        b.copyFixture('types');
        await a.generateClean();
        await b.generateClean();
        expect(a.snapshot(), b.snapshot());
      },
    );

    test('check mode reports and writes nothing', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      final dryRun = await project.generate(check: true);
      expect(dryRun.diagnostics, isEmpty);
      expect(dryRun.isUpToDate, isFalse);
      expect(dryRun.written, hasLength(4));
      expect(project.exists('app_shared/lib/src/catalog.dw.dart'), isFalse);

      await project.generateClean();
      expect((await project.generate(check: true)).isUpToDate, isTrue);

      final source = project.readFile('app_shared/lib/src/units.dart');
      project.writeFile(
        'app_shared/lib/src/units.dart',
        source.replaceFirst('final double width;', 'final num width;'),
      );
      final broken = await project.generate(check: true);
      expect(broken.hasErrors, isTrue);
      expect(broken.summary, contains('nothing written'));
    });

    test('stale parts are removed; foreign .dw.dart files are kept', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();

      // The library stops declaring its part.
      project.writeFile(
        'app_shared/lib/src/empty.dart',
        project
            .readFile('app_shared/lib/src/empty.dart')
            .replaceFirst("part 'empty.dw.dart';", ''),
      );
      // A generated part whose library is gone.
      project.writeFile(
        'app_shared/lib/src/gone.dw.dart',
        "// GENERATED BY dartway generate. DO NOT EDIT.\npart of 'gone.dart';\n",
      );
      // Not ours: no header.
      project.writeFile(
        'app_shared/lib/src/handmade.dw.dart',
        "part of 'handmade.dart';\n",
      );

      final report = await project.generateClean();
      expect(report.removed.map(p.basename), ['empty.dw.dart', 'gone.dw.dart']);
      expect(project.exists('app_shared/lib/src/empty.dw.dart'), isFalse);
      expect(project.exists('app_shared/lib/src/gone.dw.dart'), isFalse);
      expect(project.exists('app_shared/lib/src/handmade.dw.dart'), isTrue);
    });

    test('nothing is written when any library has an error', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      project.writeFile('app_shared/lib/src/bad.dart', '''
import 'package:dartway_core/dartway_core.dart';

part 'bad.dw.dart';

final class Bad extends DwDataObject with _\$Bad {
  const Bad({required this.id});

  @override
  final double id;
}
''');
      final report = await project.generate();
      expect(report.hasErrors, isTrue);
      expect(report.written, isEmpty);
      expect(project.exists('app_shared/lib/src/catalog.dw.dart'), isFalse);
      expect(
        project.exists('app_shared/lib/generated/dw_protocol.dart'),
        isFalse,
      );
    });

    test('the formatter follows the package page width', () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      project.writeFile(
        'app_shared/analysis_options.yaml',
        'formatter:\n  page_width: 120\n',
      );
      await project.generateClean();
      final part = project.readFile('app_shared/lib/src/units.dw.dart');
      expect(
        part,
        contains(
          'Dimensions \$DimensionsFromJson(Map<String, Object?> json) => Dimensions(',
        ),
      );
      expect(await project.analyze('app_shared'), isNull);
    });
  });

  final example = p.join(frameworkPackages, '..', 'example');
  group(
    'example project',
    () {
      test('the example shared package generates and analyzes clean', () async {
        final project = TempProject.create(['dartway_example_shared']);
        final source = Directory(
          p.join(example, 'dartway_example_shared', 'lib'),
        );
        for (final entity in source.listSync(recursive: true)) {
          if (entity is! File || entity.path.endsWith('.dw.dart')) continue;
          if (p.split(entity.path).contains('generated')) continue;
          project.writeFile(
            p.join(
              'dartway_example_shared',
              'lib',
              p.relative(entity.path, from: source.path),
            ),
            entity.readAsStringSync(),
          );
        }
        final report = await project.generateClean();
        expect(
          report.written.map((path) => p.relative(path, from: project.root)),
          contains('dartway_example_shared/lib/generated/dw_protocol.dart'),
        );
        expect(
          project.readFile(
            'dartway_example_shared/lib/generated/dw_protocol.dart',
          ),
          contains('final DwProtocol dartwayExampleProtocol = DwProtocol(['),
        );
        expect(await project.analyze('dartway_example_shared'), isNull);
      });
    },
    skip: Directory(example).existsSync() ? false : 'no example/ in this tree',
  );
}
