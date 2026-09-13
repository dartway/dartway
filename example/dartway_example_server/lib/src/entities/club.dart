import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';

part 'club.dw.dart';

@DwTable('club_service')
final class ClubService extends DwEntity with _$ClubService {
  const ClubService({
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

  static const table = ClubServiceTable();
}

@DwTable('club_session', indexes: [DwIndex(['startsAt'])])
final class ClubSession extends DwEntity with _$ClubSession {
  const ClubSession({
    this.id,
    required this.serviceId,
    this.coachProfileId,
    required this.startsAt,
    required this.capacity,
    this.bookedCount = 0,
  });

  @override
  final int? id;

  @DwReferences('club_service', onDelete: DwOnDelete.cascade)
  final int serviceId;

  @DwReferences('user_profile', onDelete: DwOnDelete.setNull)
  final int? coachProfileId;

  final DateTime startsAt;
  final int capacity;

  /// Active bookings, kept by the booking commands under this row's lock — the
  /// schedule is read far more often than it is booked, so it is not counted
  /// per read.
  final int bookedCount;

  static const table = ClubSessionTable();
}

@DwTable(
  'session_booking',
  indexes: [
    DwIndex(['sessionId', 'status']),
    DwIndex(['clientProfileId', 'createdAt']),
  ],
)
final class SessionBooking extends DwEntity with _$SessionBooking {
  const SessionBooking({
    this.id,
    required this.sessionId,
    required this.clientProfileId,
    required this.status,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwReferences('club_session', onDelete: DwOnDelete.cascade)
  final int sessionId;

  @DwReferences('user_profile', onDelete: DwOnDelete.cascade)
  final int clientProfileId;

  final BookingStatus status;
  final DateTime createdAt;

  static const table = SessionBookingTable();
}

@DwTable('session_review')
final class SessionReview extends DwEntity with _$SessionReview {
  const SessionReview({
    this.id,
    required this.bookingId,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  /// One review per visit, held by the schema rather than by a check.
  @DwUnique()
  @DwReferences('session_booking', onDelete: DwOnDelete.cascade)
  final int bookingId;

  final int rating;
  final String? text;
  final DateTime createdAt;

  static const table = SessionReviewTable();
}
