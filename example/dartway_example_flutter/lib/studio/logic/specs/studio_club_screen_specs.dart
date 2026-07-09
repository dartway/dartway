import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final chatStudioSpec = studioSpecForRoute(
  AppNavigationZone.chat,
  title: 'Team chat',
  purpose: 'Internal coordination of the club staff — shift handovers, '
      'questions, announcements — without leaving the product.',
  featureSpec: const [
    'A realtime chat is ~40 lines of DwCrudConfig — no sockets code.',
    'Secure-by-default: clients never receive chat data — one '
        'staff-only access filter line, not scattered UI checks.',
    'Try it: switch persona to Client Ivan — the tab disappears.',
  ],
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
  featureSpec: const [
    'Profile editing guarded by allowSave: self or admin only.',
    'Privilege escalation guard: only the admin can change roles — '
        'a validateSave rule, not a UI convention.',
  ],
  discussionQuestions: const [
    'Avatar upload via DartWay cloud storage?',
  ],
);

final servicesStudioSpec = studioSpecForRoute(
  AppNavigationZone.services,
  title: 'Services',
  purpose: 'The club price list: what the club offers, how long it takes and '
      'what it costs.',
  featureSpec: const [
    'Level-1 CRUD: a public read-only list, admin-managed content.',
    'Nested navigation: Profile › Services via the parent route chain.',
  ],
  discussionQuestions: const [
    'Service photos (cloud storage upload)?',
    'Service categories?',
  ],
);
