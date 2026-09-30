import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Schedule rows → the data objects clients see. Related rows are loaded in
/// one query per relation for the whole batch, never per row.
abstract final class ScheduleObjects {
  static ClubService service(ClubServiceRow row) => ClubService(
    id: row.id,
    title: row.title,
    description: row.description,
    durationMinutes: row.durationMinutes,
    price: row.price,
    imageUrl: row.imageUrl,
  );

  static Future<List<ClubSession>> sessions(
    DwDatabaseHandle db,
    List<ClubSessionRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final services = {
      for (final row in await db.clubServices.findByIds(
        rows.map((s) => s.serviceId).toSet(),
      ))
        row.id: service(row),
    };
    final coaches = await ProfileObjects.rowsById(
      db,
      rows.map((s) => s.coachProfileId),
    );
    return [
      for (final row in rows)
        ClubSession(
          id: row.id,
          service: services[row.serviceId]!,
          coach: switch (coaches[row.coachProfileId]) {
            final coach? => ProfileObjects.person(coach),
            null => null,
          },
          startsAt: row.startsAt,
          capacity: row.capacity,
          bookedCount: row.bookedCount,
        ),
    ];
  }

  static Future<ClubSession> session(
    DwDatabaseHandle db,
    ClubSessionRow row,
  ) async => (await sessions(db, [row])).single;
}
