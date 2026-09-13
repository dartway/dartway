import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../../generated/dw_schema.dart';
import '../entities/club.dart';
import '../example_context.dart';
import '../projections.dart';

final bookingHandlers = <DwHandler>[
  DwHandler.request<ListMyBookings, List<BookingView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async {
      if ((await ctx.profile).id != request.profileId) {
        ctx.refuse(DwCoreRefusal.forbidden);
      }
      return Views.bookings(
        ctx.db,
        await ctx.db.sessionBookings.find(
          where: (t) => t.clientProfileId.equals(request.profileId),
          orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        ),
      );
    },
  ),

  DwHandler.command<BookSession, BookingView>(
    access: DwAccess.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      // The session row is the lock every booking of it queues on: the count
      // and the insert below cannot interleave with another client's.
      final session = await ctx.db.clubSessions.findById(
        command.sessionId,
        lock: DwLock.forUpdate,
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
        SessionBooking(
          sessionId: session.id!,
          clientProfileId: me.id!,
          status: BookingStatus.booked,
          createdAt: DateTime.now(),
        ),
      );
      final updated = await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount + 1),
      );
      return _publishBookingChange(ctx, booking, updated);
    },
  ),

  DwHandler.command<CancelBooking, BookingView>(
    access: DwAccess.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final booking = await ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwLock.forUpdate,
      );
      if (booking == null || booking.clientProfileId != me.id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(ExampleRefusal.bookingNotActive);
      }
      final session = (await ctx.db.clubSessions.findById(
        booking.sessionId,
        lock: DwLock.forUpdate,
      ))!;
      final cancelled = await ctx.db.sessionBookings.update(
        booking.copyWith(status: BookingStatus.cancelled),
      );
      final updated = await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount - 1),
      );
      return _publishBookingChange(ctx, cancelled, updated);
    },
  ),

  DwHandler.command<MarkAttended, BookingView>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final booking = await ctx.db.sessionBookings.findById(
        command.bookingId,
        lock: DwLock.forUpdate,
      );
      if (booking == null) ctx.refuse(DwCoreRefusal.notFound);
      if (booking.status != BookingStatus.booked) {
        ctx.refuse(ExampleRefusal.bookingNotActive);
      }
      final attended = await ctx.db.sessionBookings.update(
        booking.copyWith(status: BookingStatus.attended),
      );
      final view = await Views.booking(ctx.db, attended);
      ctx.publish(DwChannel(ExampleChannel.bookings, attended.clientProfileId), view);
      return view;
    },
  ),

  DwHandler.command<ReviewVisit, BookingView>(
    access: DwAccess.signedIn,
    handle: (ctx, command) async {
      if (command.rating < 1 || command.rating > 5) {
        ctx.refuse(ExampleRefusal.ratingOutOfRange, field: 'rating');
      }
      final me = await ctx.profile;
      final booking = await ctx.db.sessionBookings.findById(command.bookingId);
      if (booking == null || booking.clientProfileId != me.id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (booking.status != BookingStatus.attended) {
        ctx.refuse(ExampleRefusal.reviewNeedsAttendance);
      }
      final inserted = await ctx.db.sessionReviews.insert(
        SessionReview(
          bookingId: booking.id!,
          rating: command.rating,
          text: command.text,
          createdAt: DateTime.now(),
        ),
        onConflict: DwOnConflict.doNothing((t) => [t.bookingId]),
      );
      if (inserted == null) ctx.refuse(ExampleRefusal.alreadyReviewed);
      final view = await Views.booking(ctx.db, booking);
      ctx.publish(DwChannel(ExampleChannel.bookings, me.id!), view);
      return view;
    },
  ),
];

Future<BookingView> _publishBookingChange(
  DwContext ctx,
  SessionBooking booking,
  ClubSession session,
) async {
  final sessionView = await Views.session(ctx.db, session);
  final view = await Views.booking(ctx.db, booking);
  ctx.publish(const DwChannel(ExampleChannel.schedule), sessionView);
  ctx.publish(DwChannel(ExampleChannel.bookings, booking.clientProfileId), view);
  return view;
}
