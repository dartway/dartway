import 'dart:typed_data';
import 'package:dartway_orm/dartway_orm.dart';
part 'relation_rows.dw.dart';

enum DetailState { fresh, ready }

@DwSqlTable(
  'relation_detail',
  indexes: [
    DwTableIndex(['ancestorId']),
  ],
)
final class RelationDetailRow extends DwTableRow with _$RelationDetailRow {
  const RelationDetailRow({
    required this.id,
    this.ancestorId,
    required this.label,
    required this.integerValue,
    required this.doubleValue,
    required this.active,
    required this.instant,
    required this.day,
    required this.elapsed,
    required this.bytes,
    required this.labels,
    required this.states,
    required this.attributes,
    required this.state,
    this.optionalText,
    this.optionalDay,
    this.optionalInstant,
    this.optionalBytes,
    this.optionalDouble,
  });
  @override
  final int id;
  @DwForeignKey('relation_detail', reverse: 'descendants')
  final int? ancestorId;
  final String label;
  final int integerValue;
  final double doubleValue;
  final bool active;
  final DateTime instant;
  final DwCalendarDay day;
  final Duration elapsed;
  final Uint8List bytes;
  final List<String> labels;
  final List<DetailState> states;
  final Map<String, int> attributes;
  @DwStateColumn(
    DwStateTransitions<DetailState>(
      initial: {DetailState.fresh},
      moves: {
        DetailState.fresh: {DetailState.ready},
      },
    ),
  )
  final DetailState state;
  final String? optionalText;
  final DwCalendarDay? optionalDay;
  final DateTime? optionalInstant;
  final Uint8List? optionalBytes;
  final double? optionalDouble;
  static const tableDef = RelationDetailTable();
}

@DwSqlTable(
  'relation_parent',
  indexes: [
    DwTableIndex(['detailId']),
    DwTableIndex(['optionalDetailId']),
  ],
)
final class RelationParentRow extends DwTableRow with _$RelationParentRow {
  const RelationParentRow({
    required this.id,
    required this.detailId,
    this.optionalDetailId,
    required this.title,
    this.score = 0,
  });
  @override
  final int id;
  @DwForeignKey('relation_detail', relation: 'detail', reverse: 'parents')
  final int detailId;
  @DwForeignKey(
    'relation_detail',
    relation: 'optionalDetail',
    reverse: 'optionalParents',
  )
  final int? optionalDetailId;
  final String title;
  final int score;
  static const tableDef = RelationParentTable();
}

@DwSqlTable(
  'relation_child',
  indexes: [
    DwTableIndex(['parentId', 'rank']),
  ],
)
final class RelationChildRow extends DwTableRow with _$RelationChildRow {
  const RelationChildRow({
    required this.id,
    required this.parentId,
    required this.rank,
    this.note,
  });
  @override
  final int id;
  @DwForeignKey('relation_parent', reverse: 'children')
  final int parentId;
  final int rank;
  final String? note;
  static const tableDef = RelationChildTable();
}

@DwSqlTable(
  'relation_note',
  indexes: [
    DwTableIndex(['parentId']),
  ],
)
final class RelationNoteRow extends DwTableRow with _$RelationNoteRow {
  const RelationNoteRow({
    required this.id,
    required this.parentId,
    required this.text,
  });
  @override
  final int id;
  @DwForeignKey('relation_parent', reverse: 'notes')
  final int parentId;
  final String text;
  static const tableDef = RelationNoteTable();
}
