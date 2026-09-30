import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/bookings/bookings_changes.dart';
import 'package:dartway_example_server/src/bookings/bookings_jobs.dart';
import 'package:dartway_example_server/src/bookings/bookings_objects.dart';
import 'package:dartway_example_server/src/bookings/bookings_publications.dart';
import 'package:dartway_example_server/src/bookings/bookings_rows.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_server/src/schedule/schedule_changes.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

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
          where: (t) => t.clientProfileId.equals(me.id),
          orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        ),
        client: me,
      );
    },
  ),

  /// Books the caller onto a session. Any signed-in member; refused when the
  /// session is full, once it started, or when they already hold a spot — in
  /// that order.
  /// Publishes the session's spots and the booking, and queues a reminder.
  DwCallHandler.command<BookSession, SessionBooking>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      // Taking the spot locks the session row, the lock every booking of it
      // queues on: the checks and the insert below cannot interleave with
      // another member's. A refusal after it rolls the spot back, and nothing
      // it published is sent.
      final session = await ScheduleChanges.takeSpot(ctx, command.sessionId);
      final now = ctx.now;
      if (session.startsAt.isBefore(now)) {
        ctx.refuse(DartwayExampleRefusal.sessionStarted);
      }
      final alreadyBooked = await ctx.db.sessionBookings.exists(
        where: (t) =>
            t.sessionId.equals(session.id) &
            t.clientProfileId.equals(me.id) &
            t.status.equals(BookingStatus.booked),
      );
      if (alreadyBooked) ctx.refuse(DartwayExampleRefusal.alreadyBooked);

      final booking = await ctx.db.sessionBookings.insert(
        NewSessionBookingRow(
          sessionId: session.id,
          clientProfileId: me.id,
          status: BookingStatus.booked,
          createdAt: now,
        ),
      );
      // Joins this transaction: a refused or failed booking queues nothing.
      // A session closer than the lead is reminded of right away.
      await ctx.jobs.enqueue(
        BookingsJobs.remind,
        (bookingId: booking.id),
        runAt: session.startsAt.subtract(BookingsJobs.reminderLead),
        key: BookingsJobs.remindKey(booking.id),
      );
      return BookingsPublications.booking(
        ctx,
        booking,
        client: me,
        session: session,
      );
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
      return BookingsChanges.cancel(ctx, booking, client: me);
    },
  ),

  /// Marks an active booking attended. Staff only; published to the member.
  DwCallHandler.command<MarkAttended, SessionBooking>(
    access: ProfileAccess.staff,
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
        NewSessionReviewRow(
          bookingId: booking.id,
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
