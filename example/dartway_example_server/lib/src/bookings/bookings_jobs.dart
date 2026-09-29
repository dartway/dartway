import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import '../../generated/dw_schema.dart';
import '../profile/profile_rows.dart';

/// What the bookings feature's jobs are — name and payload codec — imported by
/// the commands that enqueue them.
abstract final class BookingsJobs {
  /// Reminds a member of a session they booked, [reminderLead] before it
  /// starts — if the booking is still active by then.
  static const remind = DwJobKind<({int bookingId})>(
    'bookings.remind',
    encode: _encodeBooking,
    decode: _decodeBooking,
  );

  /// How long before a session its reminder goes out.
  static const reminderLead = Duration(hours: 2);

  /// The one key a booking's reminder is queued under: booking the same
  /// session again after a cancellation is a new booking and a new key.
  static String remindKey(int bookingId) => 'bookings.remind:$bookingId';

  static Map<String, Object?> _encodeBooking(({int bookingId}) payload) => {
    'bookingId': payload.bookingId,
  };

  static ({int bookingId}) _decodeBooking(Map<String, Object?> json) =>
      (bookingId: json['bookingId']! as int);
}

/// The jobs the bookings feature runs, declared in its `DwServerFeature`.
final bookingsJobs = <DwJobDefinition>[
  DwQueuedJob(
    BookingsJobs.remind,
    handle: (ctx, payload) async {
      // Decided when the job runs, not when it was queued: a booking
      // cancelled since — or a session taken off the schedule, which takes
      // its bookings with it — reminds nobody.
      final booking = await ctx.db.sessionBookings.findById(payload.bookingId);
      if (booking == null || booking.status != BookingStatus.booked) return;
      final session = (await ctx.db.clubSessions.findById(booking.sessionId))!;
      final service = (await ctx.db.clubServices.findById(session.serviceId))!;
      final client = (await ctx.db.userProfiles.findById(
        booking.clientProfileId,
      ))!;
      // Queued in this job's transaction, delivered by the push module.
      await ctx.push.send(
        [client.ownerAccountId],
        message: DwPushMessage(title: service.title, link: '/bookings'),
        category: DartwayExamplePushCategory.bookingReminder,
        dedupKey: BookingsJobs.remindKey(booking.id!),
      );
    },
  ),
];
