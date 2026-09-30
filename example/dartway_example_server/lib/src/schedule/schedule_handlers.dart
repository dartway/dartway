import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/admin/admin_publications.dart';
import 'package:dartway_example_server/src/core/call_context.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/schedule/schedule_objects.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

final scheduleHandlers = <DwCallHandler>[
  /// The club's services, by title. Every signed-in member.
  DwCallHandler.list<ListClubServices, ClubService>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.clubServices.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ScheduleObjects.service(row),
    ],
  ),

  /// Sessions from a moment on, earliest first. Every signed-in member.
  DwCallHandler.list<ListUpcomingSessions, ClubSession>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ScheduleObjects.sessions(
      ctx.db,
      await ctx.db.clubSessions.find(
        where: (t) => t.startsAt.gte(request.from),
        orderBy: (t) => [t.startsAt.asc(), t.id.asc()],
      ),
    ),
  ),

  /// Adds a service or rewrites one. Admins only; published on the schedule.
  DwCallHandler.command<SaveClubService, ClubService>(
    access: AppAccess.admin,
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
      final service = ScheduleObjects.service(saved);
      ctx.publish(AppChannels.schedule, service);
      return service;
    },
  ),

  /// Puts a session of a service on the schedule. Staff only; a session in
  /// the past is refused, and a service or coach that does not exist is
  /// `dw.notFound`. Published on the schedule and to the admin counters.
  DwCallHandler.command<ScheduleSession, ClubSession>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      if (command.startsAt.isBefore(DateTime.now())) {
        ctx.refuse(DartwayExampleRefusal.sessionInPast, field: 'startsAt');
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
      final session = await ScheduleObjects.session(ctx.db, row);
      ctx.publish(AppChannels.schedule, session);
      await AdminPublications.counters(ctx);
      return session;
    },
  ),

  /// Takes a session off the schedule, with its bookings. Staff only. The
  /// session leaves the schedule, each booking its member's list, and the
  /// admin counters move.
  DwCallHandler.command<CancelSession, void>(
    access: AppAccess.staff,
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
        AppChannels.schedule,
        DwDeletedObject.of<ClubSession>(command.sessionId, ctx.protocol),
      );
      for (final booking in affected) {
        ctx.publish(
          AppChannels.bookingsOf(clients[booking.clientProfileId]!),
          DwDeletedObject.of<SessionBooking>(booking.id!, ctx.protocol),
        );
      }
      await AdminPublications.counters(ctx);
    },
  ),
];
