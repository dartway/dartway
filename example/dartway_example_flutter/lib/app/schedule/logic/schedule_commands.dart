import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the schedule sends.
abstract final class ScheduleCommands {
  /// Books the signed-in member onto [session]. The answer carries the
  /// booking and the session, and both lists on screen take them before the
  /// command completes.
  static Future<DwCallResult<SessionBooking>> book(ClubSession session) =>
      dw.command(BookSession(sessionId: session.id));
}
