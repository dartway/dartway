import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('booking a session flips its card and its spots from the answer '
      'alone', (tester) async {
    final startsAt = DateTime.now().add(const Duration(days: 1));
    final session = ClubSession(
      id: 11,
      service: const ClubService(
        id: 1,
        title: 'Yoga',
        description: 'A slow morning flow.',
        durationMinutes: 60,
        price: 1200,
      ),
      coach: const PersonCard(id: 2, firstName: 'Boris'),
      startsAt: startsAt,
      capacity: 10,
      bookedCount: 3,
    );
    final club = FakeClub()..sessions.add(session);

    // What the real handler does: the session, with one place fewer, goes to
    // everyone on the schedule and the booking to the member's channel — and
    // the answer carries both, since this app listens to both.
    club.server.onCommand<BookSession>((command, call) {
      final booked = session.copyWith(bookedCount: session.bookedCount + 1);
      final booking = SessionBooking(
        id: 100,
        accountId: testSession.id,
        session: booked,
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      );
      call
        ..publish(scheduleChannel, [booked])
        ..publish(club.bookingsChannel, [booking]);
      return DwCallOk(booking);
    });

    final app = await ExampleTestApp.start(tester, club);
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('7 of 10 spots left'), findsOneWidget);

    await app.tap(tester, find.text('Book'));

    final booking = app.server.callsOf<BookSession>().single;
    expect(booking.call, const BookSession(sessionId: 11));
    expect(
      booking.response,
      isA<DwApiOk>().having(
        (ok) => ok.updates.objects,
        'updates',
        hasLength(2),
      ),
    );
    expect(find.text('You are booked!'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Book'), findsNothing);
    expect(find.text('6 of 10 spots left'), findsOneWidget);
    expect(app.server.requestsOf<ListUpcomingSessions>(), hasLength(1));
    expect(app.server.requestsOf<ListMyBookings>(), hasLength(1));
    expect(
      app.server.sent.whereType<DwUpdateMessage>(),
      isEmpty,
      reason: "the author's own socket is not sent what its answer carried",
    );

    await app.stop(tester);
  });

  testWidgets('the schedule is asked from the start of today, once, with the '
      "member's own bookings", (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());

    final now = DateTime.now();
    final request = app.server.requestsOf<ListUpcomingSessions>().single;
    expect(
      request.from.isAtSameMomentAs(DateTime(now.year, now.month, now.day)),
      isTrue,
      reason: '${request.from} is not the start of the local day',
    );
    expect(
      app.server.requestsOf<ListMyBookings>().single,
      ListMyBookings(accountId: testSession.id),
    );
    expect(find.text('No upcoming sessions yet'), findsOneWidget);

    await app.stop(tester);
  });
}
