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
      session: ClubSession.include(
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
          await ClubSession.db.findById(session, booking.sessionId);
      if (clubSession == null) {
        return 'Session not found';
      }

      if (saveContext.isInsert) {
        if (clubSession.startsAt.isBefore(DateTime.now())) {
          return 'This session has already started';
        }
        final takenSpots = await SessionBooking.db.count(
          session,
          where: (t) =>
              t.sessionId.equals(booking.sessionId) &
              t.status.equals(BookingStatus.booked),
        );
        if (takenSpots >= clubSession.capacity) {
          return 'No spots left for this session';
        }
        final ownActiveBookings = await SessionBooking.db.count(
          session,
          where: (t) =>
              t.sessionId.equals(booking.sessionId) &
              t.clientProfileId.equals(booking.clientProfileId) &
              t.status.equals(BookingStatus.booked),
        );
        if (ownActiveBookings > 0) {
          return 'You are already booked for this session';
        }
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
      if (saveContext.isInsert) {
        saveContext.currentModel = saveContext.currentModel.copyWith(
          status: BookingStatus.booked,
          createdAt: DateTime.now(),
        );
      }
    },
  ),
);
