import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/core/channels.dart';

/// What the admin dashboard is published as. The counters are the admin
/// feature's; every feature whose command changes what they count publishes
/// them through [counters], so a dashboard never reads again on its own.
abstract final class AdminPublications {
  /// The dashboard numbers, counted now.
  static Future<AdminCounters> countCounters(DwDatabaseHandle db) async =>
      AdminCounters(
        members: await db.userProfiles.count(),
        upcomingSessions: await db.clubSessions.count(
          where: (t) => t.startsAt.gte(DateTime.now()),
        ),
        newsPosts: await db.newsPosts.count(),
      );

  /// Fresh counters to the admin dashboard, from a command that changed what
  /// they count.
  static Future<void> counters(DwCallContext ctx) async =>
      ctx.publish(AppChannels.admin, await countCounters(ctx.db));
}
