import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../core/channels.dart';
import 'profile_rows.dart';
import 'profile_objects.dart';

/// What a change is published as, and to whom: the objects each channel
/// carries, computed in one place so every handler that changes a profile
/// tells the same listeners the same thing.
abstract final class AppPublications {
  /// The dashboard numbers, counted now.
  static Future<AdminCounters> countAdminCounters(DwDatabaseHandle db) async =>
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
  static Future<void> adminCounters(DwCallContext ctx) async => ctx.publish(
    AppChannels.admin,
    await AppPublications.countAdminCounters(ctx.db),
  );

  /// A changed profile to everyone who shows it: its owner's own profile (and so
  /// the owner's router guards), the members table and the user card of the
  /// admins. Answers the profile as clients see it.
  static Future<UserProfile> profile(
    DwCallContext ctx,
    UserProfileRow row,
  ) async {
    final card = await AppObjects.card(ctx, row);
    ctx
      ..publish(AppChannels.profileOf(row.accountId), card.profile)
      ..publish(AppChannels.admin, card.profile)
      ..publish(AppChannels.admin, card);
    return card.profile;
  }
}
