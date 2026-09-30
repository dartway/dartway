import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'bookings_rows.dw.dart';

@DwSqlTable(
  'session_booking',
  indexes: [
    DwTableIndex(['sessionId', 'status']),
    DwTableIndex(['clientProfileId', 'createdAt']),
  ],
)
final class SessionBookingRow extends DwTableRow with _$SessionBookingRow {
  const SessionBookingRow({
    required this.id,
    required this.sessionId,
    required this.clientProfileId,
    required this.status,
    required this.createdAt,
  });

  @override
  final int id;

  @DwForeignKey('club_session', onDelete: DwOnDelete.cascade)
  final int sessionId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int clientProfileId;

  final BookingStatus status;
  final DateTime createdAt;

  static const tableDef = SessionBookingTable();
}

@DwSqlTable('session_review')
final class SessionReviewRow extends DwTableRow with _$SessionReviewRow {
  const SessionReviewRow({
    required this.id,
    required this.bookingId,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  @override
  final int id;

  /// One review per visit, held by the schema rather than by a check.
  @DwUniqueColumn()
  @DwForeignKey('session_booking', onDelete: DwOnDelete.cascade)
  final int bookingId;

  final int rating;
  final String? text;
  final DateTime createdAt;

  static const tableDef = SessionReviewTable();
}
