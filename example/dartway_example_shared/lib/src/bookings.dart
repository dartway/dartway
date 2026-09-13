import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';
import 'schedule.dart';

part 'bookings.dw.dart';

enum BookingStatus { booked, cancelled, attended }

/// A client's review of a visit.
final class ReviewView extends DwDataObject with _$ReviewView {
  const ReviewView({
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

/// A booking as its client sees it.
final class BookingView extends DwDataObject with _$BookingView {
  const BookingView({
    required this.id,
    required this.session,
    required this.status,
    required this.createdAt,
    this.review,
  });

  @override
  final int id;
  final ClubSessionView session;
  final BookingStatus status;
  final DateTime createdAt;
  final ReviewView? review;
}

/// The caller's bookings, newest first. [profileId] must be the caller's.
final class ListMyBookings extends DwListRequest<BookingView>
    with _$ListMyBookings {
  const ListMyBookings({required this.profileId});

  final int profileId;

  @override
  List<DwChannel> get channels => [DwChannel(ExampleChannel.bookings, profileId)];

  @override
  int Function(BookingView a, BookingView b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

/// Books a spot on a session for the caller.
final class BookSession extends DwCommand<BookingView> with _$BookSession {
  const BookSession({required this.sessionId});

  final int sessionId;
}

/// Cancels one of the caller's active bookings.
final class CancelBooking extends DwCommand<BookingView> with _$CancelBooking {
  const CancelBooking({required this.bookingId});

  final int bookingId;
}

/// Marks a booking attended. Staff only.
final class MarkAttended extends DwCommand<BookingView> with _$MarkAttended {
  const MarkAttended({required this.bookingId});

  final int bookingId;
}

/// Reviews an attended visit, once.
final class ReviewVisit extends DwCommand<BookingView> with _$ReviewVisit {
  const ReviewVisit({required this.bookingId, required this.rating, this.text});

  final int bookingId;
  final int rating;
  final String? text;
}
