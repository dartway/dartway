import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// Access: clients see only their own bookings, staff sees all of them.
Future<Expression<dynamic>?> _bookingAccessFilter(Session session) async {
  if (await session.isStaffMember) {
    return null;
  }
  final userProfileId = await session.currentUserProfileId;
  return SessionBooking.t.clientProfileId.equals(userProfileId ?? -1);
}

/// CRUD configuration for the SessionBooking model — the heart of the domain:
/// spot capacity, duplicate protection and status transitions all live here.
final sessionBookingCrudConfig = DwCrudConfig<SessionBooking>(
  table: SessionBooking.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: _bookingAccessFilter,
    include: SessionBooking.include(
      clubSession: ClubSession.include(
        service: ClubService.include(),
        coachProfile: UserProfile.include(),
      ),
    ),
  ),
  saveConfig: DwSaveConfig<SessionBooking>(
    allowSave: (session, saveContext) async =>
        await session.isStaffMember ||
        await session.isUser(saveContext.currentModel.clientProfileId),
    validateSave: (session, saveContext) async {
      final booking = saveContext.currentModel;
      final clubSession =
          await ClubSession.db.findById(session, booking.clubSessionId);
      if (clubSession == null) {
        return 'Session not found';
      }

      if (saveContext.isInsert) {
        if (clubSession.startsAt.isBefore(DateTime.now())) {
          return 'This session has already started';
        }
        // Spot capacity and double-booking are NOT checked here: both count
        // rows that a concurrent save is busy adding, and this runs before the
        // transaction opens. They live in beforeSaveTransaction.
        return null;
      }

      final previousStatus = saveContext.initialModel?.status;
      if (previousStatus == booking.status) {
        return null;
      }
      if (booking.status == BookingStatus.attended &&
          !await session.isStaffMember) {
        return 'Only staff can mark attendance';
      }
      if (previousStatus != BookingStatus.booked) {
        return 'Booking is already ${previousStatus?.name}';
      }
      return null;
    },
    beforeSaveTransaction: (session, saveContext) async {
      if (!saveContext.isInsert) return null;

      final booking = saveContext.currentModel;

      // Lock the session row for the rest of this transaction. Without it the
      // two rules below are decorative: under READ COMMITTED two clients going
      // for the last spot both count four of five and both get in. Blocking is
      // right here — unlike the auth limits, real clients rarely contend for
      // the same session, and the wait is measured in milliseconds.
      await session.db.unsafeQuery(
        'SELECT "id" FROM "club_session" WHERE "id" = @sessionId FOR UPDATE',
        parameters: QueryParameters.named({
          'sessionId': booking.clubSessionId,
        }),
        transaction: saveContext.transaction,
      );

      final clubSession = await ClubSession.db.findById(
        session,
        booking.clubSessionId,
        transaction: saveContext.transaction,
      );
      if (clubSession == null) return 'Session not found';

      final takenSpots = await SessionBooking.db.count(
        session,
        where: (t) =>
            t.clubSessionId.equals(booking.clubSessionId) &
            t.status.equals(BookingStatus.booked),
        transaction: saveContext.transaction,
      );
      if (takenSpots >= clubSession.capacity) {
        return 'No spots left for this session';
      }

      final ownActiveBookings = await SessionBooking.db.count(
        session,
        where: (t) =>
            t.clubSessionId.equals(booking.clubSessionId) &
            t.clientProfileId.equals(booking.clientProfileId) &
            t.status.equals(BookingStatus.booked),
        transaction: saveContext.transaction,
      );
      if (ownActiveBookings > 0) {
        return 'You are already booked for this session';
      }

      saveContext.currentModel = booking.copyWith(
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      );
      return null;
    },
  ),
);
