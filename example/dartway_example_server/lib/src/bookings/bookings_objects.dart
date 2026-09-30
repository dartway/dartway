import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_server/src/schedule/schedule_objects.dart';
import 'package:dartway_example_server/src/bookings/bookings_rows.dart';

/// Booking rows → the data objects clients see. Related rows are loaded in one
/// query per relation for the whole batch, never per row, and not at all when
/// the caller already holds them.
abstract final class BookingsObjects {
  /// [client] is the profile every row belongs to, when the caller holds it;
  /// [session] the data object of every row's session, likewise.
  static Future<List<SessionBooking>> bookings(
    DwDatabaseHandle db,
    List<SessionBookingRow> rows, {
    UserProfileRow? client,
    ClubSession? session,
  }) async {
    if (rows.isEmpty) return const [];
    final sessionsById = session != null
        ? {session.id: session}
        : {
            for (final s in await ScheduleObjects.sessions(
              db,
              await db.clubSessions.findByIds(
                rows.map((b) => b.sessionId).toSet(),
              ),
            ))
              s.id: s,
          };
    final clients = client != null
        ? {client.id!: client}
        : await ProfileObjects.rowsById(db, rows.map((b) => b.clientProfileId));
    // Only an attended visit can have been reviewed.
    final attended = [
      for (final row in rows)
        if (row.status == BookingStatus.attended) row.id!,
    ];
    final reviews = attended.isEmpty
        ? const <int, SessionReview>{}
        : {
            for (final r in await db.sessionReviews.find(
              where: (t) => t.bookingId.inList(attended),
            ))
              r.bookingId: SessionReview(
                id: r.id!,
                rating: r.rating,
                text: r.text,
                createdAt: r.createdAt,
              ),
          };
    return [
      for (final row in rows)
        SessionBooking(
          id: row.id!,
          // A booking always belongs to someone who is here: the last thing
          // a member's deletion does is cancel the ones still ahead, and the
          // ones behind are read by nobody but them.
          accountId: clients[row.clientProfileId]!.ownerAccountId,
          session: sessionsById[row.sessionId]!,
          status: row.status,
          createdAt: row.createdAt,
          review: reviews[row.id],
        ),
    ];
  }

  static Future<SessionBooking> booking(
    DwDatabaseHandle db,
    SessionBookingRow row, {
    UserProfileRow? client,
    ClubSession? session,
  }) async =>
      (await bookings(db, [row], client: client, session: session)).single;
}
