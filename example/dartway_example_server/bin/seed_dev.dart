import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    show dwAuthenticationHandler;
import 'package:serverpod/serverpod.dart';
import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/endpoints.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

const _adminPhone = '79990000001';
const _coachPhone = '79990000002';
const _clientPhone = '79990000003';

/// Dev-only seed: a fitness club with an admin, a coach, a client, a price
/// list, a week of sessions, the team chat and a welcome post.
/// Sign in with any seeded phone — the OTP code is logged to the console.
Future<void> main(List<String> args) async {
  if (!args.join(' ').contains('development') &&
      !args.contains('development')) {
    stderr.writeln('seed_dev.dart runs only with: --mode development');
    exitCode = 2;
    return;
  }

  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: dwAuthenticationHandler,
  );
  initDartwayCore(pod);

  final session = await pod.createSession(enableLogging: false);
  try {
    await _seed(session);
    stdout.writeln('Dev seed completed. Sign in with (OTP code in console):');
    stdout.writeln(' - admin:  $_adminPhone');
    stdout.writeln(' - coach:  $_coachPhone');
    stdout.writeln(' - client: $_clientPhone');
  } finally {
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
}

Future<void> _seed(Session session) async {
  final admin = await _ensureProfile(session, _adminPhone, 'Alex',
      role: UserRole.admin);
  final coach = await _ensureProfile(session, _coachPhone, 'Maria',
      role: UserRole.staff);
  await _ensureProfile(session, _clientPhone, 'Ivan', role: UserRole.client);

  final services = <ClubService>[];
  for (final (title, description, minutes, price, capacity) in [
    ('Group workout', 'Full-body group training', 60, 900, 12),
    ('Yoga class', 'Morning yoga for everyone', 90, 1100, 8),
    ('Personal training', 'One-on-one with a coach', 60, 2500, 1),
  ]) {
    var service = (await ClubService.db.find(session,
            where: (t) => t.title.equals(title), limit: 1))
        .firstOrNull;
    service ??= await ClubService.db.insertRow(
      session,
      ClubService(
        title: title,
        description: description,
        durationMinutes: minutes,
        price: price,
      ),
    );
    services.add(service);

    // A week of sessions per service, one per day at fixed hours.
    final startHour = 9 + services.length * 2;
    for (var day = 1; day <= 7; day++) {
      final now = DateTime.now();
      final startsAt =
          DateTime(now.year, now.month, now.day, startHour).add(
        Duration(days: day),
      );
      final existing = await ClubSession.db.count(
        session,
        where: (t) =>
            t.serviceId.equals(service!.id!) & t.startsAt.equals(startsAt),
      );
      if (existing == 0) {
        await ClubSession.db.insertRow(
          session,
          ClubSession(
            serviceId: service.id!,
            coachProfileId: coach.id!,
            startsAt: startsAt,
            capacity: capacity,
          ),
        );
      }
    }
  }

  final channelCount = await ChatChannel.db.count(session);
  if (channelCount == 0) {
    await ChatChannel.db.insertRow(
      session,
      ChatChannel(title: 'Club team', createdAt: DateTime.now()),
    );
  }

  final newsCount = await NewsPost.db.count(session);
  if (newsCount == 0) {
    await NewsPost.db.insertRow(
      session,
      NewsPost(
        authorProfileId: admin.id!,
        title: 'Welcome to DartWay Fitness!',
        text: 'Our new app is live: browse the schedule, book sessions '
            'and follow club news right here.',
        createdAt: DateTime.now(),
      ),
    );
  }

  final settingCount = await AppSetting.db.count(
    session,
    where: (t) => t.settingKey.equals('clubName'),
  );
  if (settingCount == 0) {
    await AppSetting.db.insertRow(
      session,
      AppSetting(settingKey: 'clubName', settingValue: 'DartWay Fitness'),
    );
  }
}

Future<UserProfile> _ensureProfile(
  Session session,
  String phone,
  String firstName, {
  required UserRole role,
}) async {
  final existing = (await UserProfile.db.find(session,
          where: (t) => t.userIdentifier.equals(phone), limit: 1))
      .firstOrNull;
  if (existing != null) return existing;

  return UserProfile.db.insertRow(
    session,
    UserProfile(
      userIdentifier: phone,
      phone: phone,
      firstName: firstName,
      role: role,
      agreedForMarketingCommunications: false,
      conditionsAcceptedAt: DateTime.now(),
    ),
  );
}
