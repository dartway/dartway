import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/club.dart';
import '../entities/people.dart';
import '../example_channels.dart';
import '../example_context.dart';
import 'schedule_handlers.dart';

final bookingHandlers = <DwCallHandler>[
  DwCallHandler.list<ListMyBookings, SessionBooking>(
    // "My" bookings name no account: the caller's are the only ones read.
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final me = await ctx.profile;
      return ClubObjects.bookings(
        ctx.db,
        await ctx.db.sessionBookings.find(
          where: (t) => t.clientProfileId.equals(me.id!),
          orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        ),
        client: me,
      );
    },
  ),

  DwCallHandler.command<BookSession, SessionBooking>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      // The session row is the lock every booking of it queues on: the count
      // and the insert below cannot interleave with another member's.
      final session = await ctx.db.clubSessions.findById(
        command.sessionId,
        lock: DwRowLock.forUpdate,
      );
      if (session == null) ctx.refuse(DwCoreRefusal.notFound);
      if (session.startsAt.isBefore(DateTime.now())) {
        ctx.refuse(ExampleRefusal.sessionStarted);
      }
      if (session.bookedCount >= session.capacity) {
        ctx.refuse(ExampleRefusal.noSpotsLeft);
      }
      final alreadyBooked = await ctx.db.sessionBookings.exists(
        where: (t) =>
            t.sessionId.equals(session.id!) &
            t.clientProfileId.equals(me.id!) &
            t.status.equals(BookingStatus.booked),
      );
      if (alreadyBooked) ctx.refuse(ExampleRefusal.alreadyBooked);

      final booking = await ctx.db.sessionBookings.insert(
        SessionBookingRow(
          sessionId: session.id!,
          clientProfileId: me.id!,
          status: BookingStatus.booked,
          createdAt: DateTime.now(),
        ),
      );
      final updated = await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount + 1),
      );
      return _publishBookingChange(ctx, booking, updated, me);
    },
  ),

  DwCallHandler.command<CancelBooking, SessionBooking>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final booking = await ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwRowLock.forUpdate,
      );
      // Someone else's booking does not exist for the caller.
      if (booking == null || booking.clientProfileId != me.id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(ExampleRefusal.bookingNotActive);
      }
      final session = (await ctx.db.clubSessions.findById(
        booking.sessionId,
        lock: DwRowLock.forUpdate,
      ))!;
      final cancelled = await ctx.db.sessionBookings.update(
        booking.copyWith(status: BookingStatus.cancelled),
      );
      final updated = await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount - 1),
      );
      return _publishBookingChange(ctx, cancelled, updated, me);
    },
  ),

  DwCallHandler.command<MarkAttended, SessionBooking>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final booking = await ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwRowLock.forUpdate,
      );
      if (booking == null) ctx.refuse(DwCoreRefusal.notFound);
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(ExampleRefusal.bookingNotActive);
      }
      final attended = await ctx.db.sessionBookings.update(
        booking.copyWith(status: BookingStatus.attended),
      );
      final object = (await ClubObjects.bookings(ctx.db, [attended])).single;
      ctx.publish(bookingsOf(object.accountId), object);
      return object;
    },
  ),

  DwCallHandler.command<ReviewVisit, SessionBooking>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final booking = await ctx.db.sessionBookings.findById(command.bookingId);
      if (booking == null || booking.clientProfileId != me.id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (booking.status != BookingStatus.attended) {
        ctx.refuse(ExampleRefusal.reviewNeedsAttendance);
      }
      final inserted = await ctx.db.sessionReviews.tryInsert(
        SessionReviewRow(
          bookingId: booking.id!,
          rating: command.rating,
          text: command.text,
          createdAt: DateTime.now(),
        ),
        onConflict: DwOnConflict.doNothing((t) => [t.bookingId]),
      );
      if (inserted == null) ctx.refuse(ExampleRefusal.alreadyReviewed);
      final object = (await ClubObjects.bookings(ctx.db, [
        booking,
      ], client: me)).single;
      ctx.publish(bookingsOf(me.accountId), object);
      return object;
    },
  ),
];

/// The session's new spots go to everyone on the schedule, the booking to its
/// member's devices.
Future<SessionBooking> _publishBookingChange(
  DwCallContext ctx,
  SessionBookingRow booking,
  ClubSessionRow session,
  UserProfileRow client,
) async {
  final sessionObject = (await ClubObjects.sessions(ctx.db, [session])).single;
  final object = (await ClubObjects.bookings(
    ctx.db,
    [booking],
    client: client,
    session: sessionObject,
  )).single;
  ctx
    ..publish(scheduleChannel, sessionObject)
    ..publish(bookingsOf(client.accountId), object);
  return object;
}
