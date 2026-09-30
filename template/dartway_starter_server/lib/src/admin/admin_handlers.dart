import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/admin/admin_publications.dart';
import 'package:dartway_starter_server/src/core/call_context.dart';
import 'package:dartway_starter_server/src/core/channels.dart';
import 'package:dartway_starter_server/src/profile/profile_objects.dart';
import 'package:dartway_starter_server/src/profile/profile_publications.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

final adminHandlers = <DwCallHandler>[
  /// The dashboard numbers. Admins only; kept live by
  /// [AdminPublications.counters] from every command that moves them.
  DwCallHandler.single<GetAdminCounters, AdminCounters>(
    access: AppAccess.admin,
    handle: (ctx, request) => AdminPublications.countCounters(ctx.db),
  ),

  /// The members table: a page of profiles by name, phone or e-mail, and by
  /// role. Admins only.
  DwCallHandler.table<ListUserProfiles, UserProfile>(
    access: AppAccess.admin,
    rows: (ctx, request, table) async => ProfileObjects.profiles(
      ctx,
      await ctx.db.userProfiles.find(
        where: await request.membersFilter(ctx),
        orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        limit: table.fetchLimit,
        offset: table.offset,
      ),
    ),
    count: (ctx, request) async =>
        ctx.db.userProfiles.count(where: await request.membersFilter(ctx)),
  ),

  /// One member's card: the profile, every identifier, when the terms were
  /// accepted. Admins only.
  DwCallHandler.single<GetUserCard, UserCard>(
    access: AppAccess.admin,
    handle: (ctx, request) async {
      final row = await ctx.db.userProfiles.findById(request.profileId);
      if (row == null) ctx.refuse(DwCoreRefusal.notFound);
      return ProfileObjects.card(ctx, row);
    },
  ),

  /// Gives a member a role. Admins only; nobody changes their own
  /// (`ownRoleLocked`). Publishes the profile and the counters, and closes the
  /// admin channel for a role taken away.
  DwCallHandler.command<ChangeUserRole, UserProfile>(
    access: AppAccess.admin,
    handle: (ctx, command) async {
      if ((await ctx.profile).id == command.profileId) {
        ctx.refuse(DartwayStarterRefusal.ownRoleLocked, field: 'role');
      }
      final row = await ctx.db.userProfiles.findById(
        command.profileId,
        lock: DwRowLock.forUpdate,
      );
      if (row == null) ctx.refuse(DwCoreRefusal.notFound);
      if (row.role == command.role) return ProfileObjects.profile(ctx, row);
      final updated = await ctx.db.userProfiles.update(
        row.copyWith(role: command.role),
      );
      // Access is checked once, at subscription: a role taken away closes
      // what it opened.
      if (row.role == UserRole.admin) {
        ctx.revoke(AppChannels.admin, updated.accountId);
      }
      await AdminPublications.counters(ctx);
      return ProfilePublications.profile(ctx, updated);
    },
  ),
];

extension on ListUserProfiles {
  /// The filter of a [ListUserProfiles] page — by name, phone or e-mail, and by
  /// role — or `null` for every member.
  Future<DwWhereCondition Function(UserProfileTable t)?> membersFilter(
    DwCallContext ctx,
  ) async {
    final text = search.trim();
    final role = this.role;
    if (text.isEmpty && role == null) return null;
    // Identifiers live in the framework's table and the ORM has no joins: the
    // matching accounts are read first, in one query.
    final byIdentifier = text.isEmpty
        ? const <int>{}
        : await ctx.accounts.accountsMatching(text);
    // LIKE's own characters in what was typed are matched literally.
    final pattern =
        '%${text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    return (UserProfileTable t) {
      final byRole = role == null ? null : t.role.equals(role);
      if (text.isEmpty) return byRole!;
      var bySearch = t.firstName.ilike(pattern) | t.lastName.ilike(pattern);
      if (byIdentifier.isNotEmpty) {
        bySearch = bySearch | t.accountId.inList(byIdentifier);
      }
      return byRole == null ? bySearch : bySearch & byRole;
    };
  }
}
