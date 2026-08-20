import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:dartway_example_flutter/core/router/router.dart';

final chatStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.chat,
  title: 'Team chat',
  purpose:
      'Internal coordination of the club staff — shift handovers, '
      'questions, announcements — without leaving the product.',
  discussionQuestions: const [
    'Multiple channels and mentions?',
    'File attachments in chat?',
  ],
);

final profileStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.profile,
  title: 'Profile',
  purpose:
      'The client account: personal data, entry to the price list, '
      'session management.',
  discussionQuestions: const ['Avatar upload via DartWay cloud storage?'],
);

final servicesStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.services,
  title: 'Services',
  purpose:
      'The club price list: what the club offers, how long it takes and '
      'what it costs.',
  discussionQuestions: const [
    'Service photos (cloud storage upload)?',
    'Service categories?',
  ],
);
