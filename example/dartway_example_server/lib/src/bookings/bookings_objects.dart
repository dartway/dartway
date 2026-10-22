import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/bookings/bookings_rows.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_server/src/schedule/schedule_objects.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Booking rows → client objects from explicit typed includes.
abstract final class BookingsObjects {
  static List<DwRelationInclude> includes(
    SessionBookingTable t, {
    UserProfileRow? client,
    ClubSession? session,
  }) => [
    if (client == null) t.clientProfile,
    if (session == null) t.session.include(ScheduleObjects.includes),
    t.sessionReviews.take(1),
  ];

  static List<SessionBooking> bookings(
    List<SessionBookingRow> rows, {
    UserProfileRow? client,
    ClubSession? session,
  }) => [
    for (final row in rows)
      SessionBooking(
        id: row.id,
        accountId:
            (client ??
                    row.one<UserProfileRow>(
                      SessionBookingRow.tableDef.clientProfile,
                    ))
                .ownerAccountId,
        session:
            session ??
            ScheduleObjects.sessionObject(
              row.one(SessionBookingRow.tableDef.session),
            ),
        status: row.status,
        createdAt: row.createdAt,
        review: switch (row
            .many(SessionBookingRow.tableDef.sessionReviews)
            .firstOrNull) {
          final review? when row.status == BookingStatus.attended =>
            SessionReview(
              id: review.id,
              rating: review.rating,
              text: review.text,
              createdAt: review.createdAt,
            ),
          _ => null,
        },
      ),
  ];

  static Future<SessionBooking> booking(
    DwDatabaseHandle db,
    SessionBookingRow row, {
    UserProfileRow? client,
    ClubSession? session,
  }) async => bookings(
    [
      (await db.sessionBookings.findById(
        row.id,
        include: (t) => includes(t, client: client, session: session),
      ))!,
    ],
    client: client,
    session: session,
  ).single;
}
