import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../core/call_context.dart';
import '../core/channels.dart';
import '../profile/profile_objects.dart';
import '../profile/profile_publications.dart';
import '../profile/profile_rows.dart';
import 'admin_publications.dart';

final adminHandlers = <DwCallHandler>[
  /// The dashboard numbers. Admins only; kept live by
  /// [AdminPublications.counters] from every command that moves them.
  DwCallHandler.single<GetAdminCounters, AdminCounters>(
    access: AppAccess.admin,
    handle: (ctx, request) => AdminPublications.countCounters(ctx.db),
  ),

  /// The members table: a page of profiles by name or phone, and by role.
  /// Admins only.
  DwCallHandler.table<ListUserProfiles, UserProfile>(
    access: AppAccess.admin,
    rows: (ctx, request, table) async => [
      for (final row in await ctx.db.userProfiles.find(
        where: request.membersFilter,
        orderBy: (t) => [t.firstName.asc(), t.id.asc()],
        limit: table.fetchLimit,
        offset: table.offset,
      ))
        ProfileObjects.profile(row),
    ],
    count: (ctx, request) =>
        ctx.db.userProfiles.count(where: request.membersFilter),
  ),

  /// Gives a member a role. Admins only; a member who left has none to give
  /// (`dw.notFound`). Publishes the profile to the member and the admins, and
  /// closes the channels a lost role opened.
  DwCallHandler.command<ChangeRole, UserProfile>(
    access: AppAccess.admin,
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
      final profile = ProfilePublications.profile(ctx, updated);
      // Access is checked once, at subscription: a role taken away closes
      // what it opened.
      final account = updated.ownerAccountId;
      if (row.role == UserRole.admin && command.role != UserRole.admin) {
        ctx.revoke(AppChannels.admin, account);
      }
      if (row.role != UserRole.client && command.role == UserRole.client) {
        ctx.revoke(AppChannels.staffChannels, account);
        for (final channel in await ctx.db.chatChannels.find()) {
          ctx.revoke(AppChannels.chatOf(channel.id!), account);
        }
      }
      return profile;
    },
  ),
];

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
