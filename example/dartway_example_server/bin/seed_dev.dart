import 'dart:io';

import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/club.dart';
import 'package:dartway_example_server/src/entities/content.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_example_server/src/example_auth.dart';
import 'package:dartway_server/dartway_server.dart';

/// Development data: three personas who sign in with the code `111111`, a
/// price list, a week of sessions and a staff chat. Refuses to run twice.
///
/// `dart run bin/seed_dev.dart` against the database in `DW_DATABASE_*`, after
/// the server has migrated it once.
Future<void> main() async {
  final database = await DwDatabase.open(
    DwDatabaseConfig.fromEnvironment(Platform.environment),
  );
  try {
    await database.db.transaction((db) async {
      if (await db.clubServices.exists()) {
        stdout.writeln('Already seeded.');
        return;
      }
      final accounts = DwAccounts(db, exampleAuth);

      Future<UserProfile> persona(String phone, String name, UserRole role) async {
        final account = await accounts.ensure(DwIdentifierKind.phone, phone);
        final profile = (await db.userProfiles.findFirst(
          where: (t) => t.accountId.equals(account.accountId),
        ))!;
        return db.userProfiles.update(
          profile.copyWith(
            firstName: name,
            role: role,
            testVerificationCode: const DwPatch.set('111111'),
          ),
        );
      }

      await persona('79990000001', 'Anna', UserRole.admin);
      final coach = await persona('79990000002', 'Boris', UserRole.staff);
      await persona('79990000003', 'Vera', UserRole.client);

      final services = await db.clubServices.insertAll([
        const ClubService(
          title: 'Yoga',
          description: 'A slow morning flow for every level.',
          durationMinutes: 60,
          price: 1200,
        ),
        const ClubService(
          title: 'Strength',
          description: 'Barbell basics in a small group.',
          durationMinutes: 50,
          price: 1500,
        ),
        const ClubService(
          title: 'Personal training',
          description: 'One coach, one client, your plan.',
          durationMinutes: 60,
          price: 3500,
        ),
      ]);

      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await db.clubSessions.insertAll([
        for (var d = 1; d <= 7; d++) ...[
          ClubSession(
            serviceId: services[0].id!,
            coachProfileId: coach.id,
            startsAt: day.add(Duration(days: d, hours: 9)),
            capacity: 12,
          ),
          ClubSession(
            serviceId: services[1].id!,
            coachProfileId: coach.id,
            startsAt: day.add(Duration(days: d, hours: 18)),
            capacity: 8,
          ),
          if (d.isOdd)
            ClubSession(
              serviceId: services[2].id!,
              coachProfileId: coach.id,
              startsAt: day.add(Duration(days: d, hours: 12)),
              capacity: 1,
            ),
        ],
      ]);

      await db.chatChannels.insert(const ChatChannel(title: 'Front desk'));
      await db.newsPosts.insert(
        NewsPost(
          authorProfileId: coach.id!,
          title: 'The club is open',
          text: 'Book your first class in the schedule.',
          createdAt: DateTime.now(),
        ),
      );
      stdout.writeln('Seeded: personas 79990000001/2/3, code 111111.');
    });
  } finally {
    await database.close();
  }
}
