import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_example_server/src/entities/club.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_server/dartway_server.dart' hide DwNotAuthenticatedException;
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

/// The example's acceptance: two members of the club, one spot on a personal
/// training, and every screen that shows it staying true without a refresh.
void main() {
  late DwTestDatabase database;
  late DwTestServer server;
  final delivered = <String, String>{};

  const options = DwClientOptions(
    callTimeout: Duration(seconds: 10),
    reconnectDelay: Duration(milliseconds: 50),
    releaseDelay: Duration.zero,
  );

  setUp(() async {
    database = await DwTestDatabase.create(prefix: 'example_test_');
    server = await DwTestServer.start(
      buildExampleServer(
        database: database.config,
        port: 0,
        auth: DwAuth(
          normalize: exampleAuth.normalize,
          onAccountCreated: exampleAuth.onAccountCreated,
          deliverCode: (ctx, kind, identifier, code) async =>
              delivered[identifier] = code,
        ),
      ),
    );
  });

  tearDown(() async {
    await server.stop();
    await database.drop();
  });

  Future<(DwClient, ProfileView)> member(String phone, String name) async {
    final client = await server.connectClient(options: options);
    final ticket = await client.command(
      DwRequestCode(kind: DwIdentifierKind.phone, identifier: phone),
    );
    final session = await client.command(
      DwVerifyCode(
        ticketId: ticket.valueOrThrow.id,
        code: delivered[phone.replaceAll(RegExp(r'\D'), '')]!,
        registration: {'firstName': name},
      ),
    );
    await client.signIn(session.valueOrThrow);
    final profile = await client.fetch(GetMyProfile(accountId: client.accountId!));
    return (client, profile.valueOrThrow!);
  }

  Future<T> eventually<T>(T? Function() probe) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final value = probe();
      if (value != null) return value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('condition not met in time');
  }

  test('sign up creates the profile with the account', () async {
    final (client, profile) = await member('+7 999 000-00-10', 'Vera');
    expect(profile.firstName, 'Vera');
    expect(profile.role, UserRole.client);
    await client.stop();
  });

  test('the last spot goes to one member; both schedules and the booking list '
      'update live, and the second member is refused with a code', () async {
    final service = await server.db.clubServices.insert(
      const ClubService(
        title: 'Personal training',
        description: 'One on one',
        durationMinutes: 60,
        price: 3500,
      ),
    );
    final session = await server.db.clubSessions.insert(
      ClubSession(
        serviceId: service.id!,
        startsAt: DateTime.now().add(const Duration(days: 1)),
        capacity: 1,
      ),
    );

    final (vera, veraProfile) = await member('79990000010', 'Vera');
    final (oleg, _) = await member('79990000011', 'Oleg');
    final today = DateTime.now().subtract(const Duration(hours: 1));

    final olegSchedule = oleg.watch(ListUpcomingSessions(from: today));
    final veraBookings = vera.watch(ListMyBookings(profileId: veraProfile.id));

    List<T>? data<T>(DwRequestState<List<T>> s) =>
        s is DwRequestData<List<T>> && s.live ? s.value : null;

    expect((await eventually(() => data(olegSchedule.state))).single.spotsLeft, 1);
    expect(await eventually(() => data(veraBookings.state)), isEmpty);

    final booked = await vera.command(BookSession(sessionId: session.id!));
    expect(booked.valueOrThrow.status, BookingStatus.booked);

    // Oleg's schedule learns the spot is gone without asking.
    await eventually(() {
      final sessions = data(olegSchedule.state);
      return sessions != null && sessions.single.spotsLeft == 0 ? true : null;
    });
    // Vera's own list shows the booking exactly once.
    final veraList = await eventually(() {
      final list = data(veraBookings.state);
      return list != null && list.isNotEmpty ? list : null;
    });
    expect(veraList.map((b) => b.id), [booked.valueOrThrow.id]);

    final refused = await oleg.command(BookSession(sessionId: session.id!));
    expect(
      (refused as DwRefused).refusal.isCode(ExampleRefusal.noSpotsLeft),
      isTrue,
    );

    final cancelled = await vera.command(
      CancelBooking(bookingId: booked.valueOrThrow.id),
    );
    expect(cancelled.valueOrThrow.status, BookingStatus.cancelled);
    await eventually(() {
      final sessions = data(olegSchedule.state);
      return sessions != null && sessions.single.spotsLeft == 1 ? true : null;
    });

    olegSchedule.close();
    veraBookings.close();
    await vera.stop();
    await oleg.stop();
  });

  test('a new member appears in the admin users table live', () async {
    final (admin, adminProfile) = await member('79990000014', 'Anna');
    final row = (await server.db.userProfiles.findById(adminProfile.id))!;
    await server.db.userProfiles.update(row.copyWith(role: UserRole.admin));

    final users = admin.watch(const ListProfiles());
    List<ProfileView>? live() {
      final s = users.state;
      return s is DwRequestData<List<ProfileView>> && s.live ? s.value : null;
    }

    expect((await eventually(live)).map((p) => p.firstName), ['Anna']);
    final (newcomer, _) = await member('79990000015', 'Oleg');
    await eventually(() => live()?.length == 2 ? true : null);

    users.close();
    await admin.stop();
    await newcomer.stop();
  });

  test('a client cannot read another member\'s bookings or the staff chat',
      () async {
    final (vera, _) = await member('79990000012', 'Vera');
    final (_, olegProfile) = await member('79990000013', 'Oleg');

    final foreign = await vera.fetch(ListMyBookings(profileId: olegProfile.id));
    expect((foreign as DwRefused).refusal.isCode(DwCoreRefusal.forbidden), isTrue);

    final chat = await vera.fetch(const ListChatChannels());
    expect((chat as DwRefused).refusal.isCode(DwCoreRefusal.forbidden), isTrue);
    await vera.stop();
  });
}
