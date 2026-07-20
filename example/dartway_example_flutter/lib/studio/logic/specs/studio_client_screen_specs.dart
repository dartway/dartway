import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final scheduleStudioSpec = studioSpecForRoute(
  AppNavigationZone.schedule,
  title: 'Schedule',
  purpose: 'The client entry point: upcoming club sessions grouped by day, '
      'booked in two taps. Business goal: turn attention into bookings '
      'with zero friction.',
  discussionQuestions: const [
    'Hide fully booked sessions or show them as sold out?',
    'Show "X of Y spots" live? That is a DTO-level aggregate (level 3).',
  ],
);

final bookingsStudioSpec = studioSpecForRoute(
  AppNavigationZone.bookings,
  title: 'My bookings',
  purpose: 'The client manages own visits: live statuses, cancellation, '
      'a review after an attended session.',
  discussionQuestions: const [
    'Booking reminders: in-app notification or push?',
    'One-tap repeat booking of a past session?',
  ],
);

final newsStudioSpec = studioSpecForRoute(
  AppNavigationZone.news,
  title: 'Club news',
  purpose: 'The retention channel: news and promotions keep clients returning '
      'to the app between visits.',
  discussionQuestions: const [
    'Reactions and comments on posts?',
    'Pin important announcements to the top?',
  ],
);
