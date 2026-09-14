import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/club.dart';
import 'package:dartway_example_server/src/entities/content.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Development data: three personas who sign in with the code `111111`, a
/// price list, a week of sessions, a staff chat and enough members to page
/// through the admin table. Refuses to run twice.
///
/// `dart run bin/seed_dev.dart` against the database in `DW_DATABASE_*`, after
/// the server has migrated it once.
Future<void> main() async {
  final database = await DwPostgresDatabase.open(
    DwDatabaseConfig.fromEnvironment(Platform.environment),
  );
  try {
    final db = database.db;
    if (await db.clubServices.exists()) {
      stdout.writeln('Already seeded.');
      return;
    }
    // One transaction: a seed that fails half-way leaves nothing behind.
    await db.transaction((tx) async {
      // No server runs during seeding, so nobody is subscribed: the seed's auth
      // creates the profile without publishing anything.
      final accounts = DwAccountService(
        tx,
        DwAuthConfig(
          normalize: exampleAuth.normalize,
          deliverCode: exampleAuth.deliverCode,
          onAccountCreated: (ctx, accountId, kind, identifier, registration) =>
              createProfile(ctx.db, accountId, identifier, registration),
        ),
      );

      Future<UserProfileRow> persona(
        String phone,
        String name,
        UserRole role, {
        String? fixedCode,
      }) async {
        final account = await accounts.ensure(DwIdentifierKind.phone, phone);
        final profile = (await tx.userProfiles.findFirst(
          where: (t) => t.accountId.equals(account.accountId),
        ))!;
        return tx.userProfiles.update(
          profile.copyWith(
            firstName: name,
            role: role,
            testVerificationCode: fixedCode == null
                ? const DwFieldPatch.keep()
                : DwFieldPatch.set(fixedCode),
          ),
        );
      }

      await persona('79990000001', 'Anna', UserRole.admin, fixedCode: '111111');
      final coach = await persona(
        '79990000002',
        'Boris',
        UserRole.staff,
        fixedCode: '111111',
      );
      await persona(
        '79990000003',
        'Vera',
        UserRole.client,
        fixedCode: '111111',
      );
      await persona(
        '79990000004',
        'Galina',
        UserRole.staff,
        fixedCode: '111111',
      );
      // Members to page through: the admin table shows ten at a time.
      const names = [
        'Daria',
        'Egor',
        'Zhanna',
        'Ilya',
        'Kira',
        'Lev',
        'Maria',
        'Nikita',
        'Olga',
        'Pavel',
        'Raisa',
        'Semyon',
        'Tamara',
        'Ulyana',
        'Fedor',
      ];
      for (final (index, name) in names.indexed) {
        await persona(
          '7999100${index.toString().padLeft(4, '0')}',
          name,
          UserRole.client,
        );
      }

      final services = await tx.clubServices.insertAll([
        const ClubServiceRow(
          title: 'Yoga',
          description: 'A slow morning flow for every level.',
          durationMinutes: 60,
          price: 1200,
        ),
        const ClubServiceRow(
          title: 'Strength',
          description: 'Barbell basics in a small group.',
          durationMinutes: 50,
          price: 1500,
        ),
        const ClubServiceRow(
          title: 'Personal training',
          description: 'One coach, one client, your plan.',
          durationMinutes: 60,
          price: 3500,
        ),
      ]);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tx.clubSessions.insertAll([
        for (var day = 1; day <= 7; day++) ...[
          ClubSessionRow(
            serviceId: services[0].id!,
            coachProfileId: coach.id,
            startsAt: today.add(Duration(days: day, hours: 9)),
            capacity: 12,
          ),
          if (day.isOdd)
            ClubSessionRow(
              serviceId: services[2].id!,
              coachProfileId: coach.id,
              startsAt: today.add(Duration(days: day, hours: 12)),
              capacity: 1,
            ),
          ClubSessionRow(
            serviceId: services[1].id!,
            coachProfileId: coach.id,
            startsAt: today.add(Duration(days: day, hours: 18)),
            capacity: 8,
          ),
        ],
      ]);

      final desk = await tx.chatChannels.insert(
        const ChatChannelRow(title: 'Front desk'),
      );
      // A history long enough to scroll back through.
      await tx.chatMessages.insertAll([
        for (var i = 1; i <= 45; i++)
          ChatMessageRow(
            channelId: desk.id!,
            authorProfileId: coach.id!,
            text: 'Shift note #$i',
            createdAt: now.subtract(Duration(minutes: 5 * (46 - i))),
          ),
      ]);
      await tx.newsPosts.insert(
        NewsPostRow(
          authorProfileId: coach.id!,
          title: 'The club is open',
          text: 'Book your first class in the schedule.',
          createdAt: now,
        ),
      );
    });
    stdout.writeln(
      'Seeded: admin 79990000001, staff 79990000002 and 79990000004, '
      'client 79990000003 — code 111111.',
    );
  } finally {
    await database.close();
  }
}
