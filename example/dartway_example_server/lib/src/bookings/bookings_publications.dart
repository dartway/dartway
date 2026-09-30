import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/bookings/bookings_objects.dart';
import 'package:dartway_example_server/src/bookings/bookings_rows.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// What a changed booking is published as, and to whom.
abstract final class BookingsPublications {
  /// A changed booking to its member's devices. [client] is the member and
  /// [session] the booking's session as clients see it, when the caller holds
  /// them. Answers the booking as clients see it.
  static Future<SessionBooking> booking(
    DwCallContext ctx,
    SessionBookingRow row, {
    UserProfileRow? client,
    ClubSession? session,
  }) async {
    final object = await BookingsObjects.booking(
      ctx.db,
      row,
      client: client,
      session: session,
    );
    ctx.publish(AppChannels.bookingsOf(object.accountId), object);
    return object;
  }
}
