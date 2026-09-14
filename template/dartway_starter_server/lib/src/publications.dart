import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../generated/dw_schema.dart';
import 'channels.dart';
import 'entities/people.dart';
import 'objects.dart';

/// The dashboard numbers, counted now.
Future<AdminCounters> countAdminCounters(DwDatabaseHandle db) async =>
    AdminCounters(
      members: await db.userProfiles.count(),
      admins: await db.userProfiles.count(
        where: (t) => t.role.equals(UserRole.admin),
      ),
      marketingOptIns: await db.userProfiles.count(
        where: (t) => t.agreedForMarketing.equals(true),
      ),
    );

/// Fresh counters to the admin dashboard, from a command that changed what
/// they count — so a dashboard never reads again on its own.
Future<void> publishAdminCounters(DwCallContext ctx) async =>
    ctx.publish(adminChannel, await countAdminCounters(ctx.db));

/// A changed profile to everyone who shows it: its owner's own profile (and so
/// the owner's router guards), the members table and the user card of the
/// admins. Answers the profile as clients see it.
Future<UserProfile> publishProfile(
  DwCallContext ctx,
  UserProfileRow row,
) async {
  final card = await AppObjects.card(ctx, row);
  ctx
    ..publish(profileOf(row.accountId), card.profile)
    ..publish(adminChannel, card.profile)
    ..publish(adminChannel, card);
  return card.profile;
}
