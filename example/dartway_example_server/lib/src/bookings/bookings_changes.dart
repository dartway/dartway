import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/bookings/bookings_publications.dart';
import 'package:dartway_example_server/src/bookings/bookings_rows.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_server/src/schedule/schedule_changes.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Every way a booking is written from outside the bookings — the one place
/// "cancelled" is defined: the booking marked, its spot given back to the
/// session, both published. The member's own cancel and an account's
/// deletion both come here.
abstract final class BookingsChanges {
  /// Cancels an active [booking], locked by the caller, and gives its spot
  /// back. [client] is the member, when the caller holds the row. Answers
  /// the booking as clients see it, published.
  static Future<SessionBooking> cancel(
    DwCallContext ctx,
    SessionBookingRow booking, {
    UserProfileRow? client,
  }) async {
    final cancelled = await ctx.db.sessionBookings.update(
      booking.copyWith(status: BookingStatus.cancelled),
    );
    final session = await ScheduleChanges.freeSpot(ctx, booking.sessionId);
    return BookingsPublications.booking(
      ctx,
      cancelled,
      client: client,
      session: session,
    );
  }
}
