import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('booking a session flips its card and its spots, live', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(days: 1));
    final session = ClubSessionView(
      id: 11,
      service: const ClubServiceView(
        id: 1,
        title: 'Yoga',
        description: 'A slow morning flow.',
        durationMinutes: 60,
        price: 1200,
      ),
      coach: const PersonView(id: 2, firstName: 'Boris'),
      startsAt: startsAt,
      capacity: 10,
      bookedCount: 3,
    );
    final club = FakeClub()..sessions.add(session);

    // What the real handler does: the booking goes to the client's bookings
    // channel and the session, with one place fewer, to everyone on the
    // schedule — the author's connection included.
    club.server.onCommand<BookSession>((command, call) {
      final booked = session.copyWith(bookedCount: session.bookedCount + 1);
      final booking = BookingView(
        id: 100,
        session: booked,
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      );
      club.server
        ..publish(scheduleChannel, [booked])
        ..publish(club.bookingsChannel, [booking]);
      return DwOk(booking);
    });

    final app = await ExampleTestApp.start(tester, club);
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('7 of 10 spots left'), findsOneWidget);

    await app.tap(tester, find.text('Book'));

    expect(
      app.server.commandsOf<BookSession>().single.command,
      const BookSession(sessionId: 11),
    );
    expect(find.text('You are booked!'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Book'), findsNothing);
    expect(find.text('6 of 10 spots left'), findsOneWidget);
    expect(app.server.requestsOf<ListUpcomingSessions>(), hasLength(1));
    expect(app.server.requestsOf<ListMyBookings>(), hasLength(1));

    await app.stop(tester);
  });

  testWidgets('the schedule is asked from the start of today, once', (
    tester,
  ) async {
    final app = await ExampleTestApp.start(tester, FakeClub());

    final now = DateTime.now();
    final request = app.server.requestsOf<ListUpcomingSessions>().single;
    expect(
      request.from.isAtSameMomentAs(DateTime(now.year, now.month, now.day)),
      isTrue,
      reason: '${request.from} is not the start of the local day',
    );
    expect(find.text('No upcoming sessions yet'), findsOneWidget);

    await app.stop(tester);
  });
}
