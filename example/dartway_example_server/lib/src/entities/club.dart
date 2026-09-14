import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'club.dw.dart';

@DwSqlTable('club_service')
final class ClubServiceRow extends DwTableRow with _$ClubServiceRow {
  const ClubServiceRow({
    this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.imageUrl,
  });

  @override
  final int? id;
  final String title;
  final String description;
  final int durationMinutes;
  final int price;
  final String? imageUrl;

  static const tableDef = ClubServiceTable();
}

@DwSqlTable(
  'club_session',
  indexes: [
    DwTableIndex(['startsAt']),
  ],
)
final class ClubSessionRow extends DwTableRow with _$ClubSessionRow {
  const ClubSessionRow({
    this.id,
    required this.serviceId,
    this.coachProfileId,
    required this.startsAt,
    required this.capacity,
    this.bookedCount = 0,
  });

  @override
  final int? id;

  @DwForeignKey('club_service', onDelete: DwOnDelete.cascade)
  final int serviceId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.setNull)
  final int? coachProfileId;

  final DateTime startsAt;
  final int capacity;

  /// Active bookings, kept by the booking commands under this row's lock — the
  /// schedule is read far more often than it is booked, so it is not counted
  /// per read.
  final int bookedCount;

  static const tableDef = ClubSessionTable();
}

@DwSqlTable(
  'session_booking',
  indexes: [
    DwTableIndex(['sessionId', 'status']),
    DwTableIndex(['clientProfileId', 'createdAt']),
  ],
)
final class SessionBookingRow extends DwTableRow with _$SessionBookingRow {
  const SessionBookingRow({
    this.id,
    required this.sessionId,
    required this.clientProfileId,
    required this.status,
    required this.createdAt,
  });

  @override
  final int? id;

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
    this.id,
    required this.bookingId,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  /// One review per visit, held by the schema rather than by a check.
  @DwUniqueColumn()
  @DwForeignKey('session_booking', onDelete: DwOnDelete.cascade)
  final int bookingId;

  final int rating;
  final String? text;
  final DateTime createdAt;

  static const tableDef = SessionReviewTable();
}
