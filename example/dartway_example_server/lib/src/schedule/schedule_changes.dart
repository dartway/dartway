import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/schedule/schedule_publications.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Every way a session row is written from outside the schedule — the one
/// place its invariant is kept: `bookedCount` never passes `capacity`, and
/// every change of it reaches everyone on the schedule. A booking takes and
/// gives back spots through these; it never writes `club_session` itself
/// (`foreignRowWrite`).
abstract final class ScheduleChanges {
  /// One spot of the session [sessionId] taken, the session locked here —
  /// the lock every booking of it queues on. Refused when there is no such
  /// session ([DwCoreRefusal.notFound]) or it is full
  /// ([DartwayExampleRefusal.noSpotsLeft]). Answers the session as clients
  /// see it, published.
  static Future<ClubSession> takeSpot(DwCallContext ctx, int sessionId) async {
    final session = await ctx.db.clubSessions.findById(
      sessionId,
      lock: DwRowLock.forUpdate,
    );
    if (session == null) ctx.refuse(DwCoreRefusal.notFound);
    if (session.bookedCount >= session.capacity) {
      ctx.refuse(DartwayExampleRefusal.noSpotsLeft);
    }
    return SchedulePublications.session(
      ctx,
      await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount + 1),
      ),
    );
  }

  /// One spot of the session [sessionId] given back, the session locked
  /// here. Answers the session as clients see it, published.
  static Future<ClubSession> freeSpot(DwCallContext ctx, int sessionId) async {
    final session = (await ctx.db.clubSessions.findById(
      sessionId,
      lock: DwRowLock.forUpdate,
    ))!;
    return SchedulePublications.session(
      ctx,
      await ctx.db.clubSessions.update(
        session.copyWith(bookedCount: session.bookedCount - 1),
      ),
    );
  }
}
