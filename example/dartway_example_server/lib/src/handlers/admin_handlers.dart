import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../../generated/dw_schema.dart';
import '../example_context.dart';
import '../projections.dart';

const _admin = DwChannel(ExampleChannel.admin);

Future<AdminCountersView> _counters(DwContext ctx) async => AdminCountersView(
  members: await ctx.db.userProfiles.count(),
  upcomingSessions: await ctx.db.clubSessions.count(
    where: (t) => t.startsAt.gte(DateTime.now()),
  ),
  newsPosts: await ctx.db.newsPosts.count(),
);

/// Publishes fresh counters to the admin dashboard. Called by the commands that
/// change what they count, so a dashboard never re-reads on its own.
Future<void> publishAdminCounters(DwContext ctx) async =>
    ctx.publish(_admin, await _counters(ctx));

final adminHandlers = <DwHandler>[
  DwHandler.request<GetAdminCounters, AdminCountersView>(
    access: ExampleAccess.admin,
    handle: (ctx, request) => _counters(ctx),
  ),

  DwHandler.request<ListProfiles, List<ProfileView>>(
    access: ExampleAccess.admin,
    handle: (ctx, request) async => [
      for (final p in await ctx.db.userProfiles.find(
        orderBy: (t) => [t.firstName.asc(), t.id.asc()],
      ))
        Views.profile(p),
    ],
  ),

  DwHandler.command<ChangeRole, ProfileView>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      final profile = await ctx.db.userProfiles.findById(
        command.profileId,
        lock: DwLock.forUpdate,
      );
      if (profile == null) ctx.refuse(DwCoreRefusal.notFound);
      final updated = await ctx.db.userProfiles.update(
        profile.copyWith(role: command.role),
      );
      final view = Views.profile(updated);
      ctx.publish(_admin, view);
      ctx.publish(DwChannel(ExampleChannel.profile, updated.accountId), view);
      return view;
    },
  ),
];
