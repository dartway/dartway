import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/club.dart';
import '../example_channels.dart';
import '../example_context.dart';
import 'admin_handlers.dart';

const scheduleChannel = DwLiveChannel(ExampleChannel.schedule);

final scheduleHandlers = <DwCallHandler>[
  DwCallHandler.list<ListClubServices, ClubService>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.clubServices.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ClubObjects.service(row),
    ],
  ),

  DwCallHandler.list<ListUpcomingSessions, ClubSession>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ClubObjects.sessions(
      ctx.db,
      await ctx.db.clubSessions.find(
        where: (t) => t.startsAt.gte(request.from),
        orderBy: (t) => [t.startsAt.asc(), t.id.asc()],
      ),
    ),
  ),

  DwCallHandler.command<SaveClubService, ClubService>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      final row = ClubServiceRow(
        id: command.id,
        title: command.title.trim(),
        description: command.description,
        durationMinutes: command.durationMinutes,
        price: command.price,
        imageUrl: command.imageUrl,
      );
      final saved = command.id == null
          ? await ctx.db.clubServices.insert(row)
          : await ctx.db.clubServices.update(row);
      final service = ClubObjects.service(saved);
      ctx.publish(scheduleChannel, service);
      return service;
    },
  ),

  DwCallHandler.command<ScheduleSession, ClubSession>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      if (command.startsAt.isBefore(DateTime.now())) {
        ctx.refuse(ExampleRefusal.sessionInPast, field: 'startsAt');
      }
      final ClubSessionRow row;
      try {
        row = await ctx.db.clubSessions.insert(
          ClubSessionRow(
            serviceId: command.serviceId,
            coachProfileId: command.coachProfileId,
            startsAt: command.startsAt,
            capacity: command.capacity,
          ),
        );
      } on DwForeignKeyViolation {
        // The service or the coach does not exist: the schema says so, and
        // no query asks first.
        ctx.refuse(DwCoreRefusal.notFound);
      }
      final session = (await ClubObjects.sessions(ctx.db, [row])).single;
      ctx.publish(scheduleChannel, session);
      await publishAdminCounters(ctx);
      return session;
    },
  ),

  DwCallHandler.command<CancelSession, void>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final session = await ctx.db.clubSessions.findById(
        command.sessionId,
        lock: DwRowLock.forUpdate,
      );
      if (session == null) ctx.refuse(DwCoreRefusal.notFound);
      final affected = await ctx.db.sessionBookings.find(
        where: (t) => t.sessionId.equals(command.sessionId),
      );
      final clients = {
        for (final profile in await ctx.db.userProfiles.findByIds(
          affected.map((b) => b.clientProfileId).toSet(),
        ))
          profile.id!: profile.accountId,
      };
      // The bookings go with the session (ON DELETE CASCADE).
      await ctx.db.clubSessions.delete(command.sessionId);
      ctx.publish(
        scheduleChannel,
        DwDeletedObject.of<ClubSession>(command.sessionId, ctx.protocol),
      );
      for (final booking in affected) {
        ctx.publish(
          bookingsOf(clients[booking.clientProfileId]!),
          DwDeletedObject.of<SessionBooking>(booking.id!, ctx.protocol),
        );
      }
      await publishAdminCounters(ctx);
    },
  ),
];
