import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/people.dart';
import '../example_channels.dart';
import '../example_context.dart';

const adminChannel = DwLiveChannel(ExampleChannel.admin);

/// The admin dashboard's numbers, as a handler counts and publishes them.
extension AdminCounting on DwCallContext {
  /// The dashboard numbers, counted now.
  Future<AdminCounters> countAdminCounters() async => AdminCounters(
    members: await db.userProfiles.count(),
    upcomingSessions: await db.clubSessions.count(
      where: (t) => t.startsAt.gte(DateTime.now()),
    ),
    newsPosts: await db.newsPosts.count(),
  );

  /// Publishes fresh counters to the admin dashboard. Called by the commands
  /// that change what they count, so a dashboard never reads again on its own.
  Future<void> publishAdminCounters() async =>
      publish(adminChannel, await countAdminCounters());
}

extension on ListUserProfiles {
  /// The filter of a [ListUserProfiles] page — by name or phone, and by role —
  /// or `null` for every member.
  DwWhereCondition Function(UserProfileTable t)? get membersFilter {
    final text = search.trim();
    final role = this.role;
    if (text.isEmpty && role == null) return null;
    // LIKE's own characters in what was typed are matched literally.
    final pattern =
        '%${text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    return (t) {
      final byRole = role == null ? null : t.role.equals(role);
      if (text.isEmpty) return byRole!;
      final bySearch =
          t.firstName.ilike(pattern) |
          t.lastName.ilike(pattern) |
          t.phone.like(pattern);
      return byRole == null ? bySearch : bySearch & byRole;
    };
  }
}

final adminHandlers = <DwCallHandler>[
  DwCallHandler.single<GetAdminCounters, AdminCounters>(
    access: ExampleAccess.admin,
    handle: (ctx, request) => ctx.countAdminCounters(),
  ),

  DwCallHandler.table<ListUserProfiles, UserProfile>(
    access: ExampleAccess.admin,
    rows: (ctx, request, table) async => [
      for (final row in await ctx.db.userProfiles.find(
        where: request.membersFilter,
        orderBy: (t) => [t.firstName.asc(), t.id.asc()],
        limit: table.fetchLimit,
        offset: table.offset,
      ))
        ClubObjects.profile(row),
    ],
    count: (ctx, request) =>
        ctx.db.userProfiles.count(where: request.membersFilter),
  ),

  DwCallHandler.command<ChangeRole, UserProfile>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      final row = await ctx.db.userProfiles.findById(
        command.profileId,
        lock: DwRowLock.forUpdate,
      );
      // A member who left has no role to give: their profile is a tombstone
      // the club keeps for what they wrote, not a person to promote.
      if (row == null || row.deletedAt != null) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      final updated = await ctx.db.userProfiles.update(
        row.copyWith(role: command.role),
      );
      final profile = ClubObjects.profile(updated);
      ctx
        ..publish(adminChannel, profile)
        // To the admins' table, and to the member's own profile — not to the
        // admin's, whose "my profile" does not declare that channel.
        ..publish(ExampleChannels.profileOf(updated.ownerAccountId), profile);
      // Access is checked once, at subscription: a role taken away closes
      // what it opened.
      final account = updated.ownerAccountId;
      if (row.role == UserRole.admin && command.role != UserRole.admin) {
        ctx.revoke(adminChannel, account);
      }
      if (row.role != UserRole.client && command.role == UserRole.client) {
        ctx.revoke(const DwLiveChannel(ExampleChannel.staffChannels), account);
        for (final channel in await ctx.db.chatChannels.find()) {
          ctx.revoke(
            DwLiveChannel(ExampleChannel.staffChat, channel.id),
            account,
          );
        }
      }
      return profile;
    },
  ),
];
