import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../call_context.dart';
import '../channels.dart';
import '../entities/people.dart';
import '../objects.dart';
import '../publications.dart';

final adminHandlers = <DwCallHandler>[
  DwCallHandler.single<GetAdminCounters, AdminCounters>(
    access: AppAccess.admin,
    handle: (ctx, request) => countAdminCounters(ctx.db),
  ),

  DwCallHandler.table<ListUserProfiles, UserProfile>(
    access: AppAccess.admin,
    rows: (ctx, request, table) async => AppObjects.profiles(
      ctx,
      await ctx.db.userProfiles.find(
        where: await _membersFilter(ctx, request),
        orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        limit: table.fetchLimit,
        offset: table.offset,
      ),
    ),
    count: (ctx, request) async =>
        ctx.db.userProfiles.count(where: await _membersFilter(ctx, request)),
  ),

  DwCallHandler.single<GetUserCard, UserCard>(
    access: AppAccess.admin,
    handle: (ctx, request) async {
      final row = await ctx.db.userProfiles.findById(request.profileId);
      if (row == null) ctx.refuse(DwCoreRefusal.notFound);
      return AppObjects.card(ctx, row);
    },
  ),

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
      if (row.role == command.role) return AppObjects.profile(ctx, row);
      final updated = await ctx.db.userProfiles.update(
        row.copyWith(role: command.role),
      );
      // Access is checked once, at subscription: a role taken away closes
      // what it opened.
      if (row.role == UserRole.admin) {
        ctx.revoke(adminChannel, updated.accountId);
      }
      await publishAdminCounters(ctx);
      return publishProfile(ctx, updated);
    },
  ),
];

/// The filter of a [ListUserProfiles] page — by name, phone or e-mail, and by
/// role — or `null` for every member.
Future<DwWhereCondition Function(UserProfileTable t)?> _membersFilter(
  DwCallContext ctx,
  ListUserProfiles request,
) async {
  final search = request.search.trim();
  final role = request.role;
  if (search.isEmpty && role == null) return null;
  // Identifiers live in the framework's table and the ORM has no joins: the
  // matching accounts are read first, in one query.
  final byIdentifier = search.isEmpty
      ? const <int>{}
      : await ctx.accounts.accountsMatching(search);
  // LIKE's own characters in what was typed are matched literally.
  final pattern =
      '%${search.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
  return (UserProfileTable t) {
    final byRole = role == null ? null : t.role.equals(role);
    if (search.isEmpty) return byRole!;
    var bySearch = t.firstName.ilike(pattern) | t.lastName.ilike(pattern);
    if (byIdentifier.isNotEmpty) {
      bySearch = bySearch | t.accountId.inList(byIdentifier);
    }
    return byRole == null ? bySearch : bySearch & byRole;
  };
}
