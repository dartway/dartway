import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';

/// Screen passports: what a screen is *for*, what it does, and what is still
/// open about it. They live in code next to the screens they describe, and
/// DartWay Studio renders them beside the running app.
///
/// Write one per screen you add. The questions are not decoration — they are
/// what you ask the person who ordered the feature.

final homeStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.home,
  title: 'Home',
  purpose:
      'The starter screen. Replace it with the entry point of your '
      'domain — the one screen that makes the product worth opening.',
  discussionQuestions: const [
    'What is the first thing a user should see after signing in?',
  ],
);

final profileStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.profile,
  title: 'Profile',
  purpose:
      'The user manages their own data and signs out. Admins reach the '
      'admin panel from here.',
  discussionQuestions: const [
    'Which profile fields does your domain actually need?',
  ],
);
