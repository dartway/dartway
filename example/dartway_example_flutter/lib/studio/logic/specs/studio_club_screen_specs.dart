import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final chatStudioSpec = studioSpecForRoute(
  AppNavigationZone.chat,
  title: 'Team chat',
  purpose: 'Internal coordination of the club staff — shift handovers, '
      'questions, announcements — without leaving the product.',
  discussionQuestions: const [
    'Multiple channels and mentions?',
    'File attachments in chat?',
  ],
);

final profileStudioSpec = studioSpecForRoute(
  AppNavigationZone.profile,
  title: 'Profile',
  purpose: 'The client account: personal data, entry to the price list, '
      'session management.',
  discussionQuestions: const [
    'Avatar upload via DartWay cloud storage?',
  ],
);

final servicesStudioSpec = studioSpecForRoute(
  AppNavigationZone.services,
  title: 'Services',
  purpose: 'The club price list: what the club offers, how long it takes and '
      'what it costs.',
  discussionQuestions: const [
    'Service photos (cloud storage upload)?',
    'Service categories?',
  ],
);
