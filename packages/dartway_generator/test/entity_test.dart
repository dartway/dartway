import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dartway_generator/src/entity/entity_model.dart';

import 'support/temp_project.dart';

void main() {
  final ormFixtures = p.join(
    frameworkPackages,
    'dartway_orm',
    'test',
    'fixtures',
  );
  const entities = ['app_setting', 'club_service', 'club_session'];

  group('dartway_orm reference fixtures', () {
    late TempProject project;

    setUp(() async {
      project = TempProject.create(['fixture_server']);
      for (final name in entities) {
        project.writeFile(
          'fixture_server/lib/$name.dart',
          File(p.join(ormFixtures, '$name.dart')).readAsStringSync(),
        );
      }
      await project.generateClean();
    });

    for (final name in entities) {
      test('$name.dw.dart is reproduced', () {
        expectReference(
          project.readFile('fixture_server/lib/$name.dw.dart'),
          p.join(ormFixtures, '$name.dw.dart'),
        );
      });
    }

    test('generated/dw_schema.dart is reproduced', () {
      expectReference(
        project.readFile('fixture_server/lib/generated/dw_schema.dart'),
        p.join(ormFixtures, 'generated', 'dw_schema.dart'),
      );
    });

    test('generated code is clean under strict analysis', () async {
      expect(await project.analyze('fixture_server'), isNull);
    });
  });

  group('row fields named like table members (D-040)', () {
    late TempProject project;
    final fixture = p.join(ormFixtures, 'field_names');

    setUp(() async {
      project = TempProject.create(['fixture_server']);
      project.writeFile(
        'fixture_server/lib/catalog_entry.dart',
        File(p.join(fixture, 'catalog_entry.dart')).readAsStringSync(),
      );
      await project.generateClean();
    });

    test('name, columns, schema, table, row, where and order are legal '
        'fields; the part is the ORM fixture', () async {
      expectReference(
        project.readFile('fixture_server/lib/catalog_entry.dw.dart'),
        p.join(fixture, 'catalog_entry.dw.dart'),
      );
      expect(await project.analyze('fixture_server'), isNull);
    });
  });

  test('a server package on dartway_core_server gets its generated code '
      'importing that, not the ORM it re-exports', () async {
    // As a project declares it (D-030): the ORM is not a dependency of its
    // own, so an import of it would be `depend_on_referenced_packages`.
    final project = TempProject.create(['app_server'], serverOnCore: true);
    project.writeFile('app_server/lib/src/memo_row.dart', '''
import 'package:dartway_core_server/dartway_core_server.dart';

part 'memo_row.dw.dart';

@DwSqlTable('memo')
final class MemoRow extends DwTableRow with _\$MemoRow {
  const MemoRow({this.id, required this.text});

  @override
  final int? id;

  final String text;

  static const tableDef = MemoTable();
}
''');
    await project.generateClean();
    final schema = project.readFile('app_server/lib/generated/dw_schema.dart');
    expect(
      schema,
      contains(
        "import 'package:dartway_core_server/dartway_core_server.dart';",
      ),
    );
    expect(schema, isNot(contains('dartway_orm')));
    expect(await project.analyze('app_server'), isNull);
  });

  test(
    'entity problems are reported, located, and nothing is written',
    () async {
      final project = TempProject.create(['app_server', 'app_shared']);
      project.copyFixture('entity_errors');
      final report = await project.generate();
      expectGolden(
        '${report.diagnostics.map((d) => d.format(project.root)).join('\n')}\n',
        'entity_errors/diagnostics.txt',
      );
      expect(report.written, isEmpty);
    },
  );

  group('naming', () {
    test('a row class is <Entity>Row; table and getter use the entity', () {
      expect(entityNameOf('SessionBookingRow'), 'SessionBooking');
      expect(entityNameOf('ClubSessionRow'), 'ClubSession');
      expect(entityNameOf('ClubSession'), isNull);
      expect(entityNameOf('Row'), isNull);
      expect(entityNameOf('Rows'), isNull);
      expect(
        pluralCamelCase(entityNameOf('SessionBookingRow')!),
        'sessionBookings',
      );
    });

    test('repository getters are the camelCase plural of the class', () {
      expect(pluralCamelCase('ClubSession'), 'clubSessions');
      expect(pluralCamelCase('AppSetting'), 'appSettings');
      expect(pluralCamelCase('Category'), 'categories');
      expect(pluralCamelCase('Day'), 'days');
      expect(pluralCamelCase('Address'), 'addresses');
      expect(pluralCamelCase('Box'), 'boxes');
      expect(pluralCamelCase('Match'), 'matches');
      expect(pluralCamelCase('Wish'), 'wishes');
      expect(pluralCamelCase('Person'), 'persons');
      expect(pluralCamelCase('URLVisit'), 'urlVisits');
      expect(pluralCamelCase('IP'), 'ips');
    });

    test('columns are the snake_case of the field', () {
      expect(snakeCase('previousSessionId'), 'previous_session_id');
      expect(snakeCase('startsAt'), 'starts_at');
      expect(snakeCase('userID'), 'user_id');
      expect(snakeCase('httpServer'), 'http_server');
      expect(snakeCase('HTTPServer'), 'http_server');
      expect(snakeCase('address2Line'), 'address2_line');
      expect(snakeCase('id'), 'id');
    });
  });

  final example = p.join(frameworkPackages, '..', 'example');
  test(
    'the example server entities generate and analyze clean',
    () async {
      // The example's server imports ORM types from dartway_core_server, as
      // every project's does.
      final project = TempProject.create(
        ['dartway_example_server', 'dartway_example_shared'],
        serverOnCore: true,
        dependencies: ['dartway_push_server', 'dartway_push_shared'],
      );
      void copy(String package, String directory) {
        final source = Directory(p.join(example, package, directory));
        for (final entity in source.listSync(recursive: true)) {
          if (entity is! File || entity.path.endsWith('.dw.dart')) continue;
          if (p.split(entity.path).contains('generated')) continue;
          project.writeFile(
            p.join(
              package,
              directory,
              p.relative(entity.path, from: source.path),
            ),
            entity.readAsStringSync(),
          );
        }
      }

      copy('dartway_example_shared', 'lib');
      copy('dartway_example_server', p.join('lib', 'src', 'entities'));
      final report = await project.generateClean();
      expect(
        report.written.map((path) => p.relative(path, from: project.root)),
        contains('dartway_example_server/lib/generated/dw_schema.dart'),
      );
      final schema = project.readFile(
        'dartway_example_server/lib/generated/dw_schema.dart',
      );
      expect(
        schema,
        contains(
          'final DwDatabaseSchema dartwayExampleSchema = DwDatabaseSchema([',
        ),
      );
      expect(
        schema,
        contains('extension DartwayExampleDb on DwDatabaseHandle {'),
      );
      expect(await project.analyze('dartway_example_server'), isNull);
      expect(await project.analyze('dartway_example_shared'), isNull);
    },
    skip:
        Directory(
          p.join(example, 'dartway_example_server', 'lib', 'src', 'entities'),
        ).existsSync()
        ? false
        : 'no example server entities in this tree',
  );
}
