import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The spot capacity of the session under test.
const _capacity = 5;

/// How many clients go for those spots at the same moment.
const _contenders = 20;

void main() {
  withServerpod(
    'Given a club session with limited capacity',
    (sessionBuilder, endpoints) {
      late Session session;
      late ClubSession clubSession;
      late List<UserProfile> clients;
      late UserProfile coach;
      late ClubService service;

      setUp(() async {
        initDartwayCore(
          passwords: const {
            'dwVerificationCodeSalt': 'test-verification-code-salt',
            'dwAuthKeySalt': 'test-auth-key-salt',
          },
        );

        session = sessionBuilder.build();
        await _wipeTables(session);

        clients = await _seedClients(session, _contenders);
        coach = await _seedCoach(session);

        // Book as staff: `allowSave` lets staff act for any client, so the
        // assertions land on the capacity rule rather than on permissions.
        session = sessionBuilder
            .copyWith(
              authentication: AuthenticationOverride.authenticationInfo(
                '${coach.id!}',
                {},
              ),
            )
            .build();
        service = await ClubService.db.insertRow(
          session,
          ClubService(
            title: 'Morning yoga',
            description: 'A test class',
            durationMinutes: 60,
            price: 1000,
          ),
        );
        clubSession = await ClubSession.db.insertRow(
          session,
          ClubSession(
            serviceId: service.id!,
            coachProfileId: coach.id!,
            startsAt: DateTime.now().toUtc().add(const Duration(days: 1)),
            capacity: _capacity,
          ),
        );
      });

      tearDown(() async => _wipeTables(session));

      test(
        'twenty clients booking at once fill it exactly to capacity, no further',
        () async {
          // The regression this pins: capacity used to be checked in
          // `validateSave`, which runs before the transaction opens. Twenty
          // concurrent saves all counted the same four-of-five and all got in,
          // so the session sold more spots than it has.
          await Future.wait([
            for (final client in clients) _book(session, clubSession, client),
          ]);

          final booked = await SessionBooking.db.count(
            session,
            where: (t) =>
                t.clubSessionId.equals(clubSession.id!) &
                t.status.equals(BookingStatus.booked),
          );

          expect(booked, _capacity);
        },
      );

      test('the same client cannot take two spots at once', () async {
        final client = clients.first;

        await Future.wait([
          for (var i = 0; i < 4; i++) _book(session, clubSession, client),
        ]);

        final ownBookings = await SessionBooking.db.count(
          session,
          where: (t) =>
              t.clubSessionId.equals(clubSession.id!) &
              t.clientProfileId.equals(client.id!) &
              t.status.equals(BookingStatus.booked),
        );

        expect(ownBookings, 1);
      });

      test('a rejected booking answers with its reason, not a crash', () async {
        for (var i = 0; i < _capacity; i++) {
          final response = await _bookRaw(session, clubSession, clients[i]);
          expect(response.isOk, isTrue);
        }

        final overflow = await _bookRaw(session, clubSession, clients[_capacity]);

        expect(overflow.isOk, isFalse);
        expect(overflow.error, 'No spots left for this session');
      });
    },
    runMode: 'test',
    applyMigrations: true,
    // A race cannot be observed inside a single rolled-back transaction: these
    // need real, separately committed ones. Cleanup is explicit.
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Books a spot through the real save pipeline, swallowing the rejection —
/// callers that race only care about the final row count.
Future<void> _book(
  Session session,
  ClubSession clubSession,
  UserProfile client,
) async {
  await _bookRaw(session, clubSession, client);
}

/// Runs the booking through the CRUD config the endpoint would use.
Future<DwApiResponse<DwModelWrapper>> _bookRaw(
  Session session,
  ClubSession clubSession,
  UserProfile client,
) {
  final booking = SessionBooking(
    clubSessionId: clubSession.id!,
    clientProfileId: client.id!,
    status: BookingStatus.booked,
    createdAt: DateTime.now().toUtc(),
  );

  final className = DwModelWrapper(object: booking).dwMappingClassname;
  final saveConfig = DwCore.instance.getCrudConfig(className)?.saveConfig;

  if (saveConfig == null) {
    throw StateError('No save config for $className');
  }

  return saveConfig.save(session, booking);
}

Future<UserProfile> _seedCoach(Session session) => UserProfile.db.insertRow(
  session,
  UserProfile(
    userIdentifier: '+79990001000',
    phone: '+79990001000',
    firstName: 'Coach',
    role: UserRole.staff,
    agreedForMarketingCommunications: false,
    conditionsAcceptedAt: DateTime.now().toUtc(),
  ),
);

Future<List<UserProfile>> _seedClients(Session session, int count) async {
  final profiles = <UserProfile>[];
  for (var i = 0; i < count; i++) {
    profiles.add(
      await UserProfile.db.insertRow(
        session,
        UserProfile(
          userIdentifier: '+7999000$i',
          phone: '+7999000$i',
          firstName: 'Client $i',
          role: UserRole.client,
          agreedForMarketingCommunications: false,
          conditionsAcceptedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }
  return profiles;
}

Future<void> _wipeTables(Session session) async {
  await SessionBooking.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await ClubSession.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await UserProfile.db.deleteWhere(session, where: (t) => Constant.bool(true));
}
