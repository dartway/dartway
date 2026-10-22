import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Schedule rows → client objects, using the read's explicit includes.
abstract final class ScheduleObjects {
  static ClubService service(ClubServiceRow row) => ClubService(
    id: row.id,
    title: row.title,
    description: row.description,
    durationMinutes: row.durationMinutes,
    price: row.price,
    imageUrl: row.imageUrl,
  );

  static List<DwRelationInclude> includes(ClubSessionTable t) => [
    t.service,
    t.coachProfile,
  ];

  static List<ClubSession> sessions(List<ClubSessionRow> rows) => [
    for (final row in rows) sessionObject(row),
  ];

  static ClubSession sessionObject(ClubSessionRow row) => ClubSession(
    id: row.id,
    service: service(row.one(ClubSessionRow.tableDef.service)),
    coach: switch (row.one(ClubSessionRow.tableDef.coachProfile)) {
      final coach? => ProfileObjects.person(coach),
      null => null,
    },
    startsAt: row.startsAt,
    capacity: row.capacity,
    bookedCount: row.bookedCount,
  );

  /// After a write, read its explicit relation projection in one statement.
  static Future<ClubSession> session(
    DwDatabaseHandle db,
    ClubSessionRow row,
  ) async => sessionObject(
    (await db.clubSessions.findById(row.id, include: includes))!,
  );
}
