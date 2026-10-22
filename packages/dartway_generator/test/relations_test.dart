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
  test('ambiguous FK pair names both fields and writes nothing', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile('app_server/lib/relations.dart', rows());
    final report = await project.generate();
    expect(report.hasErrors, isTrue);
    expect(
      report.diagnostics.map((d) => d.message).join('\n'),
      allOf(
        contains('ownerId'),
        contains('reviewerId'),
        contains('relation:'),
        contains('reverse:'),
      ),
    );
    expect(report.written, isEmpty);
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

  test('relation names colliding with columns fail with a remedy', () async {
    final project = TempProject.create(['app_server']);
    project.writeFile(
      'app_server/lib/relations.dart',
      rows(
        first: ", relation: 'id', reverse: 'ownedAssignments'",
        second: ", relation: 'reviewer', reverse: 'reviewedAssignments'",
      ),
    );
    final report = await project.generate();
    expect(report.hasErrors, isTrue);
    expect(
      report.diagnostics.map((d) => d.message).join(' '),
      allOf(contains('collides'), contains('id'), contains('relation:')),
    );
    expect(report.written, isEmpty);
  });
  test(
    'reserved relation names fail generation instead of the formatter',
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
      expect(report.hasErrors, isTrue);
      expect(
        report.diagnostics.map((d) => d.message).join(' '),
        contains('class'),
      );
      expect(report.written, isEmpty);
    },
  );
}
