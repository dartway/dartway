import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/schedule/schedule_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// Booking the club's sessions, on real clients over real HTTP and the
/// live socket, against the real server and database.
void main() {
  late AppHarness club;

  setUpAll(() async => club = await AppHarness.start());
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

  test('the last spot goes to one member: the other schedule follows over the '
      "socket, the author's bookings follow from the response alone", () async {
    final session = await sessionWithSpots(1);
    final vera = await club.signUp('79990000011', firstName: 'Vera');
    final oleg = await club.signUp('79990000012', firstName: 'Oleg');
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
      oleg.live.updatesOn(const DwLiveChannel(DartwayExampleChannel.schedule)),
      isNotEmpty,
      reason: "Oleg's schedule changed over the socket",
    );

    final refused = await oleg.client.command(
      BookSession(sessionId: session.id!),
    );
    expect(
      refused,
      isA<DwCallRefused<SessionBooking>>().having(
        (r) => r.refusal.isCode(DartwayExampleRefusal.noSpotsLeft),
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
        DwLiveChannel(DartwayExampleChannel.bookings, vera.accountId),
      ),
      isEmpty,
    );
    expect(
      vera.live.updatesOn(const DwLiveChannel(DartwayExampleChannel.schedule)),
      isEmpty,
    );
  });

  test('refusals travel as codes with honest HTTP statuses', () async {
    final session = await sessionWithSpots(1);
    final vera = await club.signUp('79990000013', firstName: 'Vera');
    final caller = club.server.caller(token: vera.session.token);
    addTearDown(caller.close);

    // A rule: 422 with the code.
    final full = await club.db.clubSessions.update(
      session.copyWith(bookedCount: 1),
    );
    final noSpots = await caller.call(BookSession(sessionId: full.id!));
    expect(noSpots.status, 422);
    expect(noSpots.refusal.isCode(DartwayExampleRefusal.noSpotsLeft), isTrue);

    // Validation, on the server as on the client: 422 naming the field.
    final invalid = await caller.call(
      const ReviewVisit(bookingId: 1, rating: 9),
    );
    expect(invalid.status, 422);
    expect(
      invalid.refusal.isCode(DartwayExampleRefusal.ratingOutOfRange),
      isTrue,
    );
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
      final vera = await club.signUp('79990000014', firstName: 'Vera');
      final oleg = await club.signUp('79990000015', firstName: 'Oleg');

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
}
