import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';
import 'schedule.dart';

part 'bookings.dw.dart';

enum BookingStatus { booked, cancelled, attended }

/// A member's review of a visit.
final class SessionReview extends DwDataObject with _$SessionReview {
  const SessionReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.text,
  });

  @override
  final int id;
  final int rating;
  final String? text;
  final DateTime createdAt;
}

/// A booking as its member sees it.
final class SessionBooking extends DwDataObject with _$SessionBooking {
  const SessionBooking({
    required this.id,
    required this.accountId,
    required this.session,
    required this.status,
    required this.createdAt,
    this.review,
  });

  @override
  final int id;

  /// The account of the member who booked.
  final int accountId;
  final ClubSession session;
  final BookingStatus status;
  final DateTime createdAt;
  final SessionReview? review;
}

/// The signed-in member's bookings, newest first, live on their own bookings
/// channel.
///
/// It names no account: the server reads the caller's bookings, and the
/// channel is the caller's. Every booking published to it is the caller's —
/// a staff member marking someone's visit attended publishes to that
/// member's channel, which this request on the staff member's device does not
/// declare — so every booking on it belongs in the list.
final class ListMyBookings extends DwListRequest<SessionBooking>
    with _$ListMyBookings {
  const ListMyBookings();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(ExampleChannel.bookings),
  ];

  @override
  int Function(SessionBooking a, SessionBooking b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

/// Books a spot on a session for the caller.
final class BookSession extends DwActionCommand<SessionBooking>
    with _$BookSession {
  const BookSession({required this.sessionId});

  final int sessionId;
}

/// Cancels one of the caller's active bookings.
final class CancelBooking extends DwActionCommand<SessionBooking>
    with _$CancelBooking {
  const CancelBooking({required this.bookingId});

  final int bookingId;
}

/// Marks a booking attended. Staff only.
final class MarkAttended extends DwActionCommand<SessionBooking>
    with _$MarkAttended {
  const MarkAttended({required this.bookingId});

  final int bookingId;
}

/// Reviews an attended visit, once.
final class ReviewVisit extends DwActionCommand<SessionBooking>
    with _$ReviewVisit
    implements DwSelfValidating {
  const ReviewVisit({required this.bookingId, required this.rating, this.text});

  final int bookingId;
  final int rating;
  final String? text;

  @override
  List<DwCallRefusal> validate() => [
    if (rating < 1 || rating > 5)
      DwCallRefusal(ExampleRefusal.ratingOutOfRange, field: 'rating'),
  ];
}
