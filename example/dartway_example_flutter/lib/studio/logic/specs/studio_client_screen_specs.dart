import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final scheduleStudioSpec = studioSpecForRoute(
  AppNavigationZone.schedule,
  title: 'Schedule',
  purpose: 'The client entry point: upcoming club sessions grouped by day, '
      'booked in two taps. Business goal: turn attention into bookings '
      'with zero friction.',
  featureSpec: const [
    'Live list: ref.watchModelList<ClubSession>() — realtime sync, '
        'pagination and loading states out of the box.',
    'Booking rules live on the server in DwCrudConfig.validateSave: '
        'capacity, duplicates, past sessions.',
    'Declarative backend filter narrows the query to upcoming sessions.',
  ],
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
  featureSpec: const [
    'Server access filter: a client physically receives only own '
        'bookings; staff sees all — one function in the config.',
    'Status changes arrive in realtime (booked → attended by staff).',
    'Review rule in validateSave: own attended booking, one per visit.',
  ],
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
  featureSpec: const [
    'Realtime feed with author include — the classic "40 lines of '
        'config" DartWay demo.',
    'Publishing is staff-only via allowSave; the UI hides the button, '
        'the server enforces the rule.',
  ],
  discussionQuestions: const [
    'Reactions and comments on posts?',
    'Pin important announcements to the top?',
  ],
);
