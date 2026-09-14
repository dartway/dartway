import 'package:dartway_orm/dartway_orm.dart';

part 'club_session.dw.dart';

/// Hand-written in the exact shape `dartway generate` produces.
///
/// Covers references (a cascading one and a nullable self-reference), a
/// renamed column, a nullable `jsonb` list, a plain index and a unique
/// multi-column index.
@DwSqlTable(
  'club_session',
  indexes: [
    DwTableIndex(['startsAt']),
    DwTableIndex(['serviceId', 'startsAt'], unique: true),
  ],
)
final class ClubSessionRow extends DwTableRow with _$ClubSessionRow {
  const ClubSessionRow({
    this.id,
    required this.serviceId,
    this.previousSessionId,
    required this.startsAt,
    required this.capacity,
    this.note,
    this.labels,
  });

  @override
  final int? id;

  @DwForeignKey('club_service', onDelete: DwOnDelete.cascade)
  final int serviceId;

  @DwForeignKey('club_session', onDelete: DwOnDelete.setNull)
  final int? previousSessionId;

  final DateTime startsAt;
  final int capacity;

  @DwColumnName('note_text')
  final String? note;

  final List<String>? labels;

  static const table = ClubSessionTable();
}
