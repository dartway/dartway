import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

/// Screen passports: what a screen is *for*, what it does, and what is still
/// open about it. They live in code next to the screens they describe, and
/// DartWay Studio renders them beside the running app.
///
/// Write one per screen you add. The questions are not decoration — they are
/// what you ask the person who ordered the feature.

final homeStudioSpec = studioSpecForRoute(
  AppNavigationZone.home,
  title: 'Home',
  purpose: 'The starter screen. Replace it with the entry point of your '
      'domain — the one screen that makes the product worth opening.',
  featureSpec: const [
    'Reads the app name from the database through the generic CRUD: '
        'ref.watchModelList<AppSetting>() — a typed live list, no endpoint.',
    'Change the value in the admin panel and it updates here without a '
        'reload. That is the whole realtime path, on the first screen.',
  ],
  discussionQuestions: const [
    'What is the first thing a user should see after signing in?',
  ],
);

final profileStudioSpec = studioSpecForRoute(
  AppNavigationZone.profile,
  title: 'Profile',
  purpose: 'The user manages their own data and signs out. Admins reach the '
      'admin panel from here.',
  featureSpec: const [
    'The user model is the app\'s own UserProfile — add fields freely, the '
        'framework does not own it.',
    'The admin button is role-gated in the UI; the router guard and the '
        'server access filters are the real protection.',
  ],
  discussionQuestions: const [
    'Which profile fields does your domain actually need?',
  ],
);
