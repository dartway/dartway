import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/schedule/schedule_objects.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// What a changed session is published as, and to whom.
abstract final class SchedulePublications {
  /// A changed session — its spots, its time — to everyone on the schedule.
  /// Answers the session as clients see it.
  static Future<ClubSession> session(
    DwCallContext ctx,
    ClubSessionRow row,
  ) async {
    final object = await ScheduleObjects.session(ctx.db, row);
    ctx.publish(AppChannels.schedule, object);
    return object;
  }
}
