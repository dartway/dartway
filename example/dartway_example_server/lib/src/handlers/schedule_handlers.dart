import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../../generated/dw_schema.dart';
import '../entities/club.dart';
import '../example_context.dart';
import '../projections.dart';
import 'admin_handlers.dart';

const _schedule = DwChannel(ExampleChannel.schedule);

final scheduleHandlers = <DwHandler>[
  DwHandler.request<ListClubServices, List<ClubServiceView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async => [
      for (final s in await ctx.db.clubServices.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        Views.service(s),
    ],
  ),

  DwHandler.request<ListUpcomingSessions, List<ClubSessionView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async => Views.sessions(
      ctx.db,
      await ctx.db.clubSessions.find(
        where: (t) => t.startsAt.gte(request.from),
        orderBy: (t) => [t.startsAt.asc(), t.id.asc()],
      ),
    ),
  ),

  DwHandler.command<SaveClubService, ClubServiceView>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      if (command.title.trim().isEmpty) {
        ctx.refuse(ExampleRefusal.titleRequired, field: 'title');
      }
      if (command.durationMinutes <= 0) {
        ctx.refuse(ExampleRefusal.durationNotPositive, field: 'durationMinutes');
      }
      if (command.price < 0) {
        ctx.refuse(ExampleRefusal.priceNegative, field: 'price');
      }
      final entity = ClubService(
        id: command.id,
        title: command.title.trim(),
        description: command.description,
        durationMinutes: command.durationMinutes,
        price: command.price,
        imageUrl: command.imageUrl,
      );
      final saved = command.id == null
          ? await ctx.db.clubServices.insert(entity)
          : await ctx.db.clubServices.update(entity);
      final view = Views.service(saved);
      ctx.publish(_schedule, view);
      return view;
    },
  ),

  DwHandler.command<ScheduleSession, ClubSessionView>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      if (command.capacity < 1) {
        ctx.refuse(ExampleRefusal.capacityTooSmall, field: 'capacity');
      }
      if (command.startsAt.isBefore(DateTime.now())) {
        ctx.refuse(ExampleRefusal.sessionInPast, field: 'startsAt');
      }
      if (await ctx.db.clubServices.findById(command.serviceId) == null) {
        ctx.refuse(DwCoreRefusal.notFound, field: 'serviceId');
      }
      final session = await ctx.db.clubSessions.insert(
        ClubSession(
          serviceId: command.serviceId,
          coachProfileId: command.coachProfileId,
          startsAt: command.startsAt,
          capacity: command.capacity,
        ),
      );
      final view = await Views.session(ctx.db, session);
      ctx.publish(_schedule, view);
      await publishAdminCounters(ctx);
      return view;
    },
  ),

  DwHandler.command<CancelSession, void>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final session = await ctx.db.clubSessions.findById(
        command.sessionId,
        lock: DwLock.forUpdate,
      );
      if (session == null) ctx.refuse(DwCoreRefusal.notFound);
      final affected = await ctx.db.sessionBookings.find(
        where: (t) => t.sessionId.equals(command.sessionId),
      );
      await ctx.db.clubSessions.delete(command.sessionId);
      ctx.publish(_schedule, DwDeleted.of<ClubSessionView>(command.sessionId, ctx.protocol));
      for (final clientId in affected.map((b) => b.clientProfileId).toSet()) {
        for (final booking in affected.where((b) => b.clientProfileId == clientId)) {
          ctx.publish(
            DwChannel(ExampleChannel.bookings, clientId),
            DwDeleted.of<BookingView>(booking.id!, ctx.protocol),
          );
        }
      }
      await publishAdminCounters(ctx);
    },
  ),
];
