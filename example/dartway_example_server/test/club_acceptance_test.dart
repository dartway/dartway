import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/club.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/club_harness.dart';

/// The example's acceptance: members of the club on real clients, over real
/// HTTP and the real live socket, against the real server and database.
void main() {
  late ClubHarness club;

  setUpAll(() async => club = await ClubHarness.start());
  tearDownAll(() => club.stop());

  Future<ClubSessionRow> sessionWithSpots(int capacity) async {
    final service = await club.db.clubServices.insert(
      const ClubServiceRow(
        title: 'Personal training',
        description: 'One on one',
        durationMinutes: 60,
        price: 3500,
      ),
    );
    return club.db.clubSessions.insert(
      ClubSessionRow(
        serviceId: service.id!,
        startsAt: DateTime.now().add(const Duration(days: 1)),
        capacity: capacity,
      ),
    );
  }

  test('signing up creates the profile, named at registration', () async {
    final vera = await club.member('+7 999 000-00-10', 'Vera');
    final profile = await vera.client.fetch(const GetMyProfile());
    expect(profile.valueOrThrow.firstName, 'Vera');
    expect(profile.valueOrThrow.role, UserRole.client);
    expect(profile.valueOrThrow.accountId, vera.accountId);
    expect(profile.valueOrThrow.phone, '79990000010');
  });

  test('a member changes the phone they sign in with by code, without signing '
      'in again; the profile on screen follows', () async {
    final nina = await club.member('79990000070', 'Nina');
    final profile = nina.client.watch(const GetMyProfile());
    addTearDown(profile.close);
    await dwWaitUntil(() => profile.isLive);

    final ticket = await nina.client.command(
      const DwRequestIdentifierCode(
        kind: DwIdentifierKind.phone,
        identifier: '+7 999 000-00-71',
      ),
    );
    final identity = await nina.client.command(
      DwConfirmIdentifier(
        ticketId: ticket.valueOrThrow.id,
        code: club.delivered['79990000071']!,
        replace: true,
      ),
    );
    expect(identity.valueOrThrow.value, '79990000071');
    expect(identity.valueOrThrow.accountId, nina.accountId);
    expect(dataOf(profile.state)!.phone, '79990000071');

    final accounts = club.server.server.accounts;
    expect(
      await accounts.find(DwIdentifierKind.phone, '79990000071'),
      nina.accountId,
    );
    expect(await accounts.find(DwIdentifierKind.phone, '79990000070'), isNull);
  });

  test('the last spot goes to one member: the other schedule follows over the '
      "socket, the author's bookings follow from the response alone", () async {
    final session = await sessionWithSpots(1);
    final vera = await club.member('79990000011', 'Vera');
    final oleg = await club.member('79990000012', 'Oleg');
    final from = DateTime.now().subtract(const Duration(hours: 1));

    final olegSchedule = oleg.client.watch(ListUpcomingSessions(from: from));
    final veraBookings = vera.client.watch(const ListMyBookings());
    final veraSchedule = vera.client.watch(ListUpcomingSessions(from: from));
    addTearDown(() {
      olegSchedule.close();
      veraBookings.close();
      veraSchedule.close();
    });
    await dwWaitUntil(
      () => olegSchedule.isLive && veraBookings.isLive && veraSchedule.isLive,
    );
    int spotsLeft(DwRequestWatch<List<ClubSession>> watch) =>
        dataOf(watch.state)!.singleWhere((s) => s.id == session.id).spotsLeft;
    expect(spotsLeft(olegSchedule), 1);
    expect(dataOf(veraBookings.state), isEmpty);

    final booked = await vera.client.command(
      BookSession(sessionId: session.id!),
    );
    expect(booked.valueOrThrow.status, BookingStatus.booked);
    expect(booked.valueOrThrow.accountId, vera.accountId);
    // Applied before the command completed: the response carried both.
    expect(dataOf(veraBookings.state)!.map((b) => b.id), [
      booked.valueOrThrow.id,
    ]);
    expect(spotsLeft(veraSchedule), 0);

    await dwWaitUntil(() => spotsLeft(olegSchedule) == 0);
    expect(
      oleg.live.updatesOn(const DwLiveChannel(ExampleChannel.schedule)),
      isNotEmpty,
      reason: "Oleg's schedule changed over the socket",
    );

    final refused = await oleg.client.command(
      BookSession(sessionId: session.id!),
    );
    expect(
      refused,
      isA<DwCallRefused<SessionBooking>>().having(
        (r) => r.refusal.isCode(ExampleRefusal.noSpotsLeft),
        'noSpotsLeft',
        isTrue,
      ),
    );

    final cancelled = await vera.client.command(
      CancelBooking(bookingId: booked.valueOrThrow.id),
    );
    expect(cancelled.valueOrThrow.status, BookingStatus.cancelled);
    expect(dataOf(veraBookings.state)!.single.status, BookingStatus.cancelled);
    await dwWaitUntil(() => spotsLeft(olegSchedule) == 1);

    // Nothing was read twice, and nothing of Vera's own came back to her over
    // the socket.
    expect(vera.http.posts('ListMyBookings'), 1);
    expect(vera.http.posts('ListUpcomingSessions'), 1);
    expect(oleg.http.posts('ListUpcomingSessions'), 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      vera.live.updatesOn(
        DwLiveChannel(ExampleChannel.bookings, vera.accountId),
      ),
      isEmpty,
    );
    expect(
      vera.live.updatesOn(const DwLiveChannel(ExampleChannel.schedule)),
      isEmpty,
    );
  });

  test('refusals travel as codes with honest HTTP statuses', () async {
    final session = await sessionWithSpots(1);
    final vera = await club.member('79990000013', 'Vera');
    final caller = club.server.caller(token: vera.session.token);
    addTearDown(caller.close);

    // A rule: 422 with the code.
    final full = await club.db.clubSessions.update(
      session.copyWith(bookedCount: 1),
    );
    final noSpots = await caller.call(BookSession(sessionId: full.id!));
    expect(noSpots.status, 422);
    expect(noSpots.refusal.isCode(ExampleRefusal.noSpotsLeft), isTrue);

    // Validation, on the server as on the client: 422 naming the field.
    final invalid = await caller.call(
      const ReviewVisit(bookingId: 1, rating: 9),
    );
    expect(invalid.status, 422);
    expect(invalid.refusal.isCode(ExampleRefusal.ratingOutOfRange), isTrue);
    expect(invalid.refusal.field, 'rating');
    final local = await vera.client.command(
      const ReviewVisit(bookingId: 1, rating: 9),
    );
    expect(local, isA<DwCallRefused<SessionBooking>>());
    expect(vera.http.posts('ReviewVisit'), 0, reason: 'refused before sending');

    // Absent: 404.
    final missing = await caller.call(const BookSession(sessionId: 987654));
    expect(missing.status, 404);
    expect(missing.refusal.isCode(DwCoreRefusal.notFound), isTrue);

    // A staff call: 403. ("My" requests name no account, so there is no
    // one else's to ask for.)
    final staffOnly = await caller.call(
      const SendChatMessage(channelId: 1, text: 'hi'),
    );
    expect(staffOnly.status, 403);

    // No session: 401.
    final anonymous = club.server.caller();
    addTearDown(anonymous.close);
    final unauthenticated = await anonymous.call(const ListNews());
    expect(unauthenticated.status, 401);
    expect(unauthenticated.response, isA<DwApiUnauthenticated>());
  });

  test(
    "closed access: a member subscribes to their own bookings only",
    () async {
      final vera = await club.member('79990000014', 'Vera');
      final oleg = await club.member('79990000015', 'Oleg');

      // Oleg's bookings: no request names them, and his channel is his alone.
      final socket = await club.server.openLive();
      addTearDown(socket.close);
      await socket.authenticate(vera.session.token);
      final foreign =
          await socket.subscribe('bookings:${oleg.accountId}')
              as DwSubscriptionRefusedMessage;
      expect(foreign.refusal?.isCode(DwCoreRefusal.forbidden), isTrue);
      expect(
        await socket.subscribe('bookings:${vera.accountId}'),
        isA<DwSubscribedMessage>(),
      );
    },
  );

  test("an admin changing a member's role: the member's own profile follows "
      "live, and the admin's own profile is not touched by it", () async {
    final admin = await club.memberWithRole(
      '79990000023',
      'Anna',
      UserRole.admin,
    );
    final member = await club.member('79990000024', 'Pavel');
    final adminProfile = admin.client.watch(const GetMyProfile());
    final memberProfile = member.client.watch(const GetMyProfile());
    addTearDown(() {
      adminProfile.close();
      memberProfile.close();
    });
    await dwWaitUntil(() => adminProfile.isLive && memberProfile.isLive);
    final before = dataOf(adminProfile.state)!;
    expect(before.role, UserRole.admin);

    final changed = await admin.client.command(
      ChangeRole(
        profileId: dataOf(memberProfile.state)!.id,
        role: UserRole.staff,
      ),
    );
    expect(changed.valueOrThrow.accountId, member.accountId);
    await dwWaitUntil(() => dataOf(memberProfile.state)?.role == UserRole.staff);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      dataOf(adminProfile.state),
      before,
      reason:
          "a UserProfile went to profile:${member.accountId}, which the "
          "admin's own profile does not declare",
    );
  });

  test('the members table pages with its total', () async {
    final admin = await club.memberWithRole(
      '79990000016',
      'Admin',
      UserRole.admin,
    );
    for (var i = 1; i <= 5; i++) {
      await club.member('7999002000$i', 'Pager $i');
    }
    Future<DwTablePage<UserProfile>> page(int number) async =>
        (await admin.client.fetch(
          ListUserProfiles(page: number, pageSize: 2, search: 'pager'),
        )).valueOrThrow;

    final first = await page(1);
    expect(first.total, 5);
    expect(first.pageCount, 3);
    expect(first.items.map((p) => p.firstName), ['Pager 1', 'Pager 2']);
    final last = await page(3);
    expect(last.items.map((p) => p.firstName), ['Pager 5']);
    expect(last.total, 5);

    final staff = await club.memberWithRole(
      '79990000017',
      'Staff',
      UserRole.staff,
    );
    final refused = await staff.client.fetch(const ListUserProfiles());
    expect(
      refused,
      isA<DwCallRefused<DwTablePage<UserProfile>>>().having(
        (r) => r.refusal.isCode(DwCoreRefusal.forbidden),
        'forbidden',
        isTrue,
      ),
    );
  });

  test('a new member reaches the admin table live; a role change updates its '
      'row in place', () async {
    final admin = await club.memberWithRole(
      '79990000018',
      'Admin',
      UserRole.admin,
    );
    await club.member('79990000019', 'Newcomer A');
    const request = ListUserProfiles(search: 'newcomer');
    final table = admin.client.watchTable(request);
    addTearDown(table.close);
    await dwWaitUntil(() => table.isLive);
    expect(dataOf(table.state)!.total, 1);
    expect(admin.http.posts('ListUserProfiles'), 1);

    await club.member('79990000020', 'Newcomer B');
    await dwWaitUntil(() => dataOf(table.state)?.total == 2);
    expect(dataOf(table.state)!.items.map((p) => p.firstName), [
      'Newcomer A',
      'Newcomer B',
    ]);
    expect(admin.http.posts('ListUserProfiles'), 2, reason: 'read once more');

    final newcomer = dataOf(table.state)!.items.last;
    final changed = await admin.client.command(
      ChangeRole(profileId: newcomer.id, role: UserRole.staff),
    );
    expect(changed.valueOrThrow.role, UserRole.staff);
    expect(dataOf(table.state)!.items.last.role, UserRole.staff);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      admin.http.posts('ListUserProfiles'),
      2,
      reason: 'the row came in the response; the page was not read again',
    );
  });
}
