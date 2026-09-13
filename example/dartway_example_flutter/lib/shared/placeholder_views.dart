import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Stand-in data the loading skeletons are drawn from. A skeleton is the real
/// widget built over one of these, so it has the shape of what is coming
/// rather than a spinner. Never shown as data.
abstract final class PlaceholderViews {
  static final _day = DateTime(2026);

  static const coach = PersonView(id: 0, firstName: 'Coach');

  static const service = ClubServiceView(
    id: 0,
    title: 'Group workout',
    description: 'One hour group workout',
    durationMinutes: 60,
    price: 1000,
  );

  static final session = ClubSessionView(
    id: 0,
    service: service,
    coach: coach,
    startsAt: _day,
    capacity: 10,
    bookedCount: 0,
  );

  static final booking = BookingView(
    id: 0,
    session: session,
    status: BookingStatus.booked,
    createdAt: _day,
  );

  static final newsPost = NewsPostView(
    id: 0,
    title: 'Club news',
    text: 'What is happening at the club this week.',
    author: coach,
    createdAt: _day,
  );

  static final chatMessage = ChatMessageView(
    id: 0,
    channelId: 0,
    text: 'A message to the team',
    author: coach,
    createdAt: _day,
  );

  static const profile = ProfileView(
    id: 0,
    phone: '79990000000',
    firstName: 'Member',
    role: UserRole.client,
    agreedForMarketing: false,
  );

  static const counters = AdminCountersView(
    members: 0,
    upcomingSessions: 0,
    newsPosts: 0,
  );

  /// [count] copies of [item], for a list skeleton.
  static List<T> listOf<T>(T item, int count) => List.filled(count, item);
}
