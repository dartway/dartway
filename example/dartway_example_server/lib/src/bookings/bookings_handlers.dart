import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../core/call_context.dart';
import 'bookings_jobs.dart';
import 'bookings_objects.dart';
import 'bookings_publications.dart';
import '../schedule/schedule_rows.dart';
import 'bookings_rows.dart';

final bookingsHandlers = <DwCallHandler>[
  /// The caller's bookings, newest first. "My" bookings name no account: the
  /// caller's are the only ones read.
  DwCallHandler.list<ListMyBookings, SessionBooking>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final me = await ctx.profile;
      return BookingsObjects.bookings(
        ctx.db,
        await ctx.db.sessionBookings.find(
          where: (t) => t.clientProfileId.equals(me.id!),
          orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        ),
        client: me,
      );
    },
  ),

  /// Books the caller onto a session. Any signed-in member; refused once the
  /// session started, when it is full, or when they already hold a spot.
  /// Publishes the session's spots and the booking, and queues a reminder.
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
      final now = ctx.now;
      if (session.startsAt.isBefore(now)) {
        ctx.refuse(DartwayExampleRefusal.sessionStarted);
      }
      if (session.bookedCount >= session.capacity) {
        ctx.refuse(DartwayExampleRefusal.noSpotsLeft);
      }
      final alreadyBooked = await ctx.db.sessionBookings.exists(
        where: (t) =>
            t.sessionId.equals(session.id!) &
            t.clientProfileId.equals(me.id!) &
            t.status.equals(BookingStatus.booked),
      );
      if (alreadyBooked) ctx.refuse(DartwayExampleRefusal.alreadyBooked);

      final booking = await ctx.db.sessionBookings.insert(
        SessionBookingRow(
          sessionId: session.id!,
          clientProfileId: me.id!,
          status: BookingStatus.booked,
          createdAt: now,
        ),
      );
      final updated = await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount + 1),
      );
      // Joins this transaction: a refused or failed booking queues nothing.
      // A session closer than the lead is reminded of right away.
      await ctx.jobs.enqueue(
        BookingsJobs.remind,
        (bookingId: booking.id!),
        runAt: session.startsAt.subtract(BookingsJobs.reminderLead),
        key: BookingsJobs.remindKey(booking.id!),
      );
      return BookingsPublications.bookingAndSession(ctx, booking, updated, me);
    },
  ),

  /// Cancels one of the caller's active bookings and frees its spot. Someone
  /// else's booking, like one that does not exist, is `dw.notFound`.
  DwCallHandler.command<CancelBooking, SessionBooking>(
    access: DwAccessRule.resource<CancelBooking, SessionBookingRow>(
      // Locked: the rule runs inside the command's transaction.
      load: (ctx, command) => ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwRowLock.forUpdate,
      ),
      allows: (ctx, command, booking) async =>
          booking.clientProfileId == (await ctx.profile).id,
    ),
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final booking = ctx.accessed<SessionBookingRow>();
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(DartwayExampleRefusal.bookingNotActive);
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
      return BookingsPublications.bookingAndSession(
        ctx,
        cancelled,
        updated,
        me,
      );
    },
  ),

  /// Marks an active booking attended. Staff only; published to the member.
  DwCallHandler.command<MarkAttended, SessionBooking>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      final booking = await ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwRowLock.forUpdate,
      );
      if (booking == null) ctx.refuse(DwCoreRefusal.notFound);
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(DartwayExampleRefusal.bookingNotActive);
      }
      final attended = await ctx.db.sessionBookings.update(
        booking.copyWith(status: BookingStatus.attended),
      );
      return BookingsPublications.booking(ctx, attended);
    },
  ),

  /// Reviews an attended visit, once. Only the member who booked reviews;
  /// anyone else's booking, like one that does not exist, is `dw.notFound`.
  /// Published to the member.
  DwCallHandler.command<ReviewVisit, SessionBooking>(
    access: DwAccessRule.resource<ReviewVisit, SessionBookingRow>(
      load: (ctx, command) =>
          ctx.db.sessionBookings.findById(command.bookingId),
      allows: (ctx, command, booking) async =>
          booking.clientProfileId == (await ctx.profile).id,
    ),
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final booking = ctx.accessed<SessionBookingRow>();
      if (booking.status != BookingStatus.attended) {
        ctx.refuse(DartwayExampleRefusal.reviewNeedsAttendance);
      }
      final inserted = await ctx.db.sessionReviews.tryInsert(
        SessionReviewRow(
          bookingId: booking.id!,
          rating: command.rating,
          text: command.text,
          createdAt: ctx.now,
        ),
        onConflict: DwOnConflict.doNothing((t) => [t.bookingId]),
      );
      if (inserted == null) ctx.refuse(DartwayExampleRefusal.alreadyReviewed);
      return BookingsPublications.booking(ctx, booking, client: me);
    },
  ),
];
