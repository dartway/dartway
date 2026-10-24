import 'dart:typed_data';
import 'package:dartway_orm/dartway_orm.dart';
import '../fixtures/relations/relation_rows.dart';
import '../fixtures/relations/generated/dw_schema.dart';

NewRelationDetailRow detailDraft(String label, {int? ancestorId}) =>
    NewRelationDetailRow(
      ancestorId: ancestorId,
      label: label,
      integerValue: 9223372036854775806,
      doubleValue: 1.2345678901234567,
      active: true,
      instant: DateTime.parse('2026-10-22T12:34:56.123456+03:00'),
      day: DwCalendarDay(1, 1, 1),
      elapsed: const Duration(microseconds: -123456789),
      bytes: Uint8List.fromList([0, 1, 127, 128, 255]),
      labels: const ['a', 'quote"', 'é'],
      states: const [DetailState.fresh, DetailState.ready],
      attributes: const {'a': 42},
      state: DetailState.fresh,
    );

Future<void> createRelationSchema(DwDatabaseHandle db) async {
  final context = DwMigrationContext(db);
  for (final name in [
    'relation_detail',
    'relation_parent',
    'relation_child',
    'relation_note',
  ]) {
    await context.createTable(fixtureSchema.table(name)!);
  }
}

Future<List<RelationParentRow>> seedRelations(DwDatabaseHandle db) async {
  final top = await db.relationDetails.insert(detailDraft('top'));
  final mid = await db.relationDetails.insert(
    detailDraft('mid', ancestorId: top.id),
  );
  final a = await db.relationDetails.insert(
    detailDraft('a', ancestorId: mid.id),
  );
  final b = await db.relationDetails.insert(
    detailDraft('b', ancestorId: mid.id),
  );
  final parents = await db.relationParents.insertAll([
    NewRelationParentRow(detailId: a.id, title: 'zero'),
    NewRelationParentRow(detailId: b.id, optionalDetailId: a.id, title: 'one'),
    NewRelationParentRow(detailId: a.id, title: 'two'),
    NewRelationParentRow(detailId: b.id, title: 'three'),
  ]);
  await db.relationChilds.insertAll([
    for (final (i, ranks) in [
      [1, 2, 3],
      <int>[],
      [2, 3],
      [1],
    ].indexed)
      for (final rank in ranks)
        NewRelationChildRow(
          parentId: parents[i].id,
          rank: rank,
          note: rank == 1 ? null : 'ok',
        ),
  ]);
  await db.relationNotes.insertAll([
    for (final (i, n) in [2, 0, 1, 3].indexed)
      for (var j = 0; j < n; j++)
        NewRelationNoteRow(parentId: parents[i].id, text: '$j'),
  ]);
  return parents;
}
