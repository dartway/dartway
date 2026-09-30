import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/core/channels.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// What the admin dashboard is published as. The counters are the admin
/// feature's; every feature whose command changes what they count publishes
/// them through [counters], so a dashboard never reads again on its own.
abstract final class AdminPublications {
  /// The dashboard numbers, counted now.
  static Future<AdminCounters> countCounters(DwDatabaseHandle db) async =>
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
  static Future<void> counters(DwCallContext ctx) async =>
      ctx.publish(AppChannels.admin, await countCounters(ctx.db));
}
