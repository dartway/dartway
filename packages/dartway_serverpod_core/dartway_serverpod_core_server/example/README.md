# Example — a feature without an endpoint

This is the server half of a booking feature: capacity, duplicate protection and status
transitions. There is no endpoint, no repository and no service class — the config *is* the
feature. The client gets typed, realtime-synced CRUD over `SessionBooking` for free.

> `session.isStaffMember` below is a one-line extension on `Session` declared in **your** app —
> roles belong to your domain. The framework ships `session.currentUserProfileId` and
> `session.isUser(id)` and never owns your `UserProfile`.

```dart
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Clients see only their own bookings, staff sees all of them.
Future<Expression<dynamic>?> _bookingAccessFilter(Session session) async {
  if (await session.isStaffMember) return null;
  final userProfileId = await session.currentUserProfileId;
  return SessionBooking.t.clientProfileId.equals(userProfileId ?? -1);
}

final sessionBookingCrudConfig = DwCrudConfig<SessionBooking>(
  table: SessionBooking.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: _bookingAccessFilter,
    include: SessionBooking.include(
      clubSession: ClubSession.include(service: ClubService.include()),
    ),
  ),
  saveConfig: DwSaveConfig<SessionBooking>(
    // who may write at all
    allowSave: (session, saveContext) async =>
        await session.isStaffMember ||
        await session.isUser(saveContext.currentModel.clientProfileId),

    // business rules — returning a string rejects the write
    validateSave: (session, saveContext) async {
      final booking = saveContext.currentModel;
      final clubSession =
          await ClubSession.db.findById(session, booking.clubSessionId);
      if (clubSession == null) return 'Session not found';

      if (saveContext.isInsert) {
        if (clubSession.startsAt.isBefore(DateTime.now())) {
          return 'This session has already started';
        }
        final takenSpots = await SessionBooking.db.count(
          session,
          where: (t) =>
              t.clubSessionId.equals(booking.clubSessionId) &
              t.status.equals(BookingStatus.booked),
        );
        if (takenSpots >= clubSession.capacity) return 'No spots left';
        return null;
      }

      // status transitions: only staff marks attendance, and only once
      final previousStatus = saveContext.initialModel?.status;
      if (previousStatus == booking.status) return null;
      if (booking.status == BookingStatus.attended &&
          !await session.isStaffMember) {
        return 'Only staff can mark attendance';
      }
      if (previousStatus != BookingStatus.booked) {
        return 'Booking is already ${previousStatus?.name}';
      }
      return null;
    },

    // runs inside the same transaction as the write
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
```

Register it once at startup, and the generic CRUD endpoints serve the model:

```dart
dw = DwCore.init<UserProfile>(
  userProfileTable: UserProfile.t,
  userProfileInclude: UserProfile.include(),
  crudConfigurations: [
    sessionBookingCrudConfig,
    clubSessionCrudConfig,
    // ...one entry per model the app exposes
  ],
  dtoConfigurations: [],
  userProfileConstructor: _buildUserProfile,
  dwAlerts: DwAlerts.init(),
  dwAuthConfig: DwAuthConfig(passwords: passwords),
);
```

**Secure by default:** a model with no config is not reachable. Access is something you grant,
never something you forget to take away.

The full server — nine models, eight configs, a staff chat invisible to clients, phone auth and
seed data — lives in [`example/`](https://github.com/dartway/dartway/tree/master/example) of the
DartWay monorepo.
