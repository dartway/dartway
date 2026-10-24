import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/temp_project.dart';

String rows({String first = '', String second = '', String indexes = ''}) =>
    '''
import 'package:dartway_orm/dartway_orm.dart';
part 'relations.dw.dart';
@DwSqlTable('staff_member')
final class StaffMemberRow extends DwTableRow with _\$StaffMemberRow {
  const StaffMemberRow({required this.id, required this.name});
  @override final int id;
  final String name;
  static const tableDef = StaffMemberTable();
}
@DwSqlTable('staff_assignment', indexes: [$indexes])
final class StaffAssignmentRow extends DwTableRow with _\$StaffAssignmentRow {
  const StaffAssignmentRow({required this.id, required this.ownerId, this.reviewerId});
  @override final int id;
  @DwForeignKey('staff_member'$first)
  final int ownerId;
  @DwForeignKey('staff_member'$second)
  final int? reviewerId;
  static const tableDef = StaffAssignmentTable();
}
''';

void main() {
  test('ambiguous FK pair warns and omits both relations', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile('app_server/lib/relations.dart', rows());
    final report = await project.generate();
    expect(report.hasErrors, isFalse);
    expect(
      report.diagnostics.map((d) => d.message).join('\n'),
      allOf(
        contains('ownerId'),
        contains('reviewerId'),
        contains('relation:'),
        contains('reverse:'),
      ),
    );
    expect(report.written, isNotEmpty);
    expect(
      project.readFile('app_server/lib/generated/dw_schema.dart'),
      isNot(contains('RelationPath')),
    );
    expect(await project.analyze('app_server'), isNull);
  });
  test(
    'relation fixtures generate and analyze with typed nullable reads',
    () async {
      final project = TempProject.create(['fixture_server']);
      final fixture = p.join(
        frameworkPackages,
        'dartway_orm',
        'test',
        'fixtures',
        'relations',
      );
      project.writeFile(
        'fixture_server/lib/relation_rows.dart',
        File(p.join(fixture, 'relation_rows.dart')).readAsStringSync(),
      );
      await project.generateClean();
      expectReference(
        project.readFile('fixture_server/lib/relation_rows.dw.dart'),
        p.join(fixture, 'relation_rows.dw.dart'),
      );
      expectReference(
        project.readFile('fixture_server/lib/generated/dw_schema.dart'),
        p.join(fixture, 'generated', 'dw_schema.dart'),
      );
      project.writeFile('fixture_server/lib/typed_reads.dart', """
import 'package:dartway_orm/dartway_orm.dart';
import 'relation_rows.dart';
import 'generated/dw_schema.dart';
RelationDetailRow requiredDetail(RelationParentRow row) => row.one(RelationParentRow.tableDef.detail);
RelationDetailRow? optionalDetail(RelationParentRow row) => row.one(RelationParentRow.tableDef.optionalDetail);
List<RelationChildRow> children(RelationParentRow row) => row.many(RelationParentRow.tableDef.children);
DwWhereCondition chained(RelationParentTable t) => t.detail.ancestor.label.equals('ancestor');
""");
      expect(await project.analyze('fixture_server'), isNull);
    },
  );

  test(
    'named pairs resolve; missing leading indexes warn without blocking',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'owner', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
          indexes: "DwTableIndex(['ownerId', 'reviewerId'])",
        ),
      );
      final report = await project.generate();
      expect(report.hasErrors, isFalse);
      expect(
        report.diagnostics.where((d) => d.isWarning).map((d) => d.message),
        [allOf(contains('reviewerId'), contains('DwTableIndex'))],
      );
      expect(await project.analyze('app_server'), isNull);
    },
  );

  test(
    'nullable paths expose nullable key and aggregate value types',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'owner', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
          indexes: "DwTableIndex(['ownerId']), DwTableIndex(['reviewerId'])",
        ),
      );
      await project.generateClean();
      project.writeFile('app_server/lib/types.dart', """
import 'package:dartway_orm/dartway_orm.dart';
import 'relations.dart';
import 'generated/dw_schema.dart';
String wrong(StaffAssignmentTable t) => readKey(t.reviewer.name);
K readKey<K>(DwTableColumn<K> column) => throw UnimplementedError();
DwTableColumn<int?> nullableId(StaffAssignmentTable t) => t.reviewer.id;
""");
      expect(
        await project.analyze('app_server'),
        contains('argument_type_not_assignable'),
      );
      project.writeFile('app_server/lib/types.dart', """
import 'dart:async';
import 'package:dartway_orm/dartway_orm.dart';
import 'relations.dart';
import 'generated/dw_schema.dart';
String? valid(StaffAssignmentTable t) => readKey(t.reviewer.name);
K readKey<K>(DwTableColumn<K> column) => throw UnimplementedError();
Future<Map<String?, int>> groups(DwDatabaseHandle db) => db.staffAssignments.countBy((t) => t.reviewer.name);
""");
      expect(await project.analyze('app_server'), isNull);
    },
  );

  test(
    'to-many tokens cannot expose an unqualified table as a column source',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'owner', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
          indexes: "DwTableIndex(['ownerId']), DwTableIndex(['reviewerId'])",
        ),
      );
      await project.generateClean();
      project.writeFile('app_server/lib/types.dart', """
import 'package:dartway_orm/dartway_orm.dart';
import 'relations.dart';
import 'generated/dw_schema.dart';
DwWhereCondition wrong(StaffMemberTable t) => t.ownedAssignments.table.id.equals(1);
""");
      expect(await project.analyze('app_server'), contains('undefined_getter'));
    },
  );

  test('FK-index diagnostics point once at each uncovered FK field', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile(
      'app_server/lib/relations.dart',
      rows(
        first: ", relation: 'owner', reverse: 'ownedAssignments'",
        second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
      ),
    );
    final report = await project.generate();
    expect(report.diagnostics, hasLength(2));
    expect(
      report.diagnostics.map((d) => (d.line, d.column)).toSet(),
      hasLength(2),
    );
    for (final index in [
      "DwTableIndex(['ownerId', 'reviewerId']), DwTableIndex(['reviewerId'], unique: true)",
      "DwTableIndex(['ownerId'], name: 'owner_lookup'), DwTableIndex(['reviewerId', 'ownerId'])",
    ]) {
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'owner', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
          indexes: index,
        ),
      );
      await project.generateClean();
    }
    project.writeFile(
      'app_server/lib/relations.dart',
      rows(
        first: ", relation: 'owner', reverse: 'ownedAssignments'",
        second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
      ).replaceAll("@DwForeignKey", "@DwUniqueColumn()\n  @DwForeignKey"),
    );
    await project.generateClean();
  });

  test('generateClean refuses unexpected warnings', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile(
      'app_server/lib/relations.dart',
      rows().replaceAll(
        "@DwForeignKey('staff_member')",
        "@DwForeignKey('dw_account')",
      ),
    );
    await expectLater(project.generateClean(), throwsA(isA<TestFailure>()));
  });

  for (final name in ['id', 'name', 'class', 'ownerId']) {
    test(
      'collision $name warns, identifies fields and omits both directions',
      () async {
        final project = TempProject.create(['app_server']);
        project.writeFile(
          'app_server/lib/relations.dart',
          rows(
                first: ", relation: '$name', reverse: 'ownedAssignments'",
                second:
                    ", relation: 'reviewer', reverse: 'reviewedAssignments'",
                indexes:
                    "DwTableIndex(['ownerId']), DwTableIndex(['reviewerId'])",
              )
              .replaceFirst(
                'this.reviewerId}',
                "this.reviewerId, this.name = 'existing'}",
              )
              .replaceFirst(
                'final int ownerId;',
                'final int ownerId;\n  final String name;',
              ),
        );
        final report = await project.generate();
        expect(report.hasErrors, isFalse);
        expect(report.diagnostics, hasLength(1));
        expect(
          report.diagnostics.single.message,
          allOf(
            contains('ownerId'),
            contains(name),
            contains('relation:'),
            contains('reverse:'),
          ),
        );
        final schema = project.readFile(
          'app_server/lib/generated/dw_schema.dart',
        );
        expect(schema, isNot(contains('get ownedAssignments')));
        expect(schema, isNot(contains('get $name =>')));
        expect(await project.analyze('app_server'), isNull);
      },
    );
  }

  test(
    'an FK without Id suffix warns instead of shadowing its column',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(indexes: "DwTableIndex(['owner']), DwTableIndex(['reviewerId'])")
            .replaceAll('ownerId', 'owner')
            .replaceAll(
              "@DwForeignKey('staff_member')",
              "@DwForeignKey('dw_account')",
            )
            .replaceFirst(
              "@DwForeignKey('dw_account')",
              "@DwForeignKey('staff_member')",
            ),
      );
      final report = await project.generate();
      expect(report.hasErrors, isFalse);
      expect(report.diagnostics.where((d) => d.isWarning), hasLength(1));
      expect(await project.analyze('app_server'), isNull);
    },
  );

  for (final name in ['tablePath', 'include', 'includeSpec']) {
    test('target field $name remains a generation error', () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
              first: ", relation: 'owner', reverse: 'ownedAssignments'",
              second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
            )
            .replaceAll('this.name', 'this.$name')
            .replaceAll('final String name;', 'final String $name;'),
      );
      final report = await project.generate();
      expect(report.hasErrors, isTrue);
      expect(
        report.diagnostics.map((d) => d.message).join(' '),
        contains(name),
      );
      expect(report.written, isEmpty);
    });
  }

  test('a partially named ambiguous pair emits neither FK relation', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile(
      'app_server/lib/relations.dart',
      rows(
        first: ", relation: 'owner', reverse: 'ownedAssignments'",
        indexes: "DwTableIndex(['ownerId']), DwTableIndex(['reviewerId'])",
      ),
    );
    final report = await project.generate();
    expect(report.hasErrors, isFalse);
    expect(report.diagnostics, hasLength(1));
    expect(
      report.diagnostics.single.message,
      allOf(
        contains('ownerId'),
        contains('reviewerId'),
        contains('relation:'),
        contains('reverse:'),
      ),
    );
    expect(
      project.readFile('app_server/lib/generated/dw_schema.dart'),
      isNot(contains('RelationPath')),
    );
    expect(await project.analyze('app_server'), isNull);
  });

  test('external SQL-only FKs warn for indexes and emit no relation', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile(
      'app_server/lib/relations.dart',
      rows().replaceAll(
        "@DwForeignKey('staff_member')",
        "@DwForeignKey('dw_account')",
      ),
    );
    final report = await project.generate();
    expect(report.hasErrors, isFalse);
    expect(report.diagnostics.where((d) => d.isWarning), hasLength(2));
    expect(
      project.readFile('app_server/lib/generated/dw_schema.dart'),
      isNot(contains('StaffAssignmentRelations')),
    );
    expect(await project.analyze('app_server'), isNull);
  });

  test(
    'relation names colliding with columns warn and omit the pair',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'id', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
        ),
      );
      final report = await project.generate();
      expect(report.hasErrors, isFalse);
      expect(
        report.diagnostics.map((d) => d.message).join(' '),
        allOf(contains('collides'), contains('id'), contains('relation:')),
      );
      expect(report.written, isNotEmpty);
      expect(await project.analyze('app_server'), isNull);
    },
  );
  test(
    'reserved relation names warn without breaking existing tables',
    () async {
      final project = TempProject.create(['app_server']);
      project.writeFile(
        'app_server/lib/relations.dart',
        rows(
          first: ", relation: 'class', reverse: 'ownedAssignments'",
          second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
        ),
      );
      final report = await project.generate();
      expect(report.hasErrors, isFalse);
      expect(
        report.diagnostics.map((d) => d.message).join(' '),
        contains('class'),
      );
      expect(report.written, isNotEmpty);
      expect(await project.analyze('app_server'), isNull);
    },
  );
}
