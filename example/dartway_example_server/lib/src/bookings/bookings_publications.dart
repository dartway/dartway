import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../core/channels.dart';
import '../profile/profile_rows.dart';
import '../schedule/schedule_objects.dart';
import '../schedule/schedule_rows.dart';
import 'bookings_objects.dart';
import 'bookings_rows.dart';

/// What a changed booking is published as, and to whom.
abstract final class BookingsPublications {
  /// A changed booking to its member's devices. [client] is the member, when
  /// the caller holds the row. Answers the booking as clients see it.
  static Future<SessionBooking> booking(
    DwCallContext ctx,
    SessionBookingRow row, {
    UserProfileRow? client,
  }) async {
    final object = await BookingsObjects.booking(ctx.db, row, client: client);
    ctx.publish(AppChannels.bookingsOf(object.accountId), object);
    return object;
  }

  /// A booking made or cancelled: the session's new spots go to everyone on
  /// the schedule, the booking to its member's devices.
  static Future<SessionBooking> bookingAndSession(
    DwCallContext ctx,
    SessionBookingRow booking,
    ClubSessionRow session,
    UserProfileRow client,
  ) async {
    final sessionObject = await ScheduleObjects.session(ctx.db, session);
    final object = await BookingsObjects.booking(
      ctx.db,
      booking,
      client: client,
      session: sessionObject,
    );
    ctx
      ..publish(AppChannels.schedule, sessionObject)
      ..publish(AppChannels.bookingsOf(client.ownerAccountId), object);
    return object;
  }
}
