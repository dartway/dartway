import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';
import 'studio_client_screen_specs.dart';
import 'studio_club_screen_specs.dart';
import 'studio_route_specs.dart';

final clubZoneStudioSpec = StudioZoneSpec(
  label: 'Club app',
  rootPath: AppNavigationZone.schedule.fullPath,
  access: StudioZoneAccess.signedIn,
  screens: [
    scheduleStudioSpec,
    bookingsStudioSpec,
    newsStudioSpec,
    chatStudioSpec,
    profileStudioSpec,
    servicesStudioSpec,
  ],
);

final adminZoneStudioSpec = StudioZoneSpec(
  label: 'Admin',
  rootPath: AdminNavigationZone.admin.fullPath,
  access: StudioZoneAccess.signedIn,
  // Role-gated by the app itself: the router guard and server filters are
  // the protection. Studio only signs in with whatever persona is chosen —
  // a non-admin lands wherever the guards send it.
  screens: [
    studioSpecForRoute(
      AdminNavigationZone.admin,
      title: 'Dashboard',
      purpose: 'The admin home: headline counters over live data. The future '
          'home of event analytics (visits, conversion, retention).',
      discussionQuestions: const [
        'Which three numbers does a club owner check every morning?',
      ],
    ),
    studioSpecForRoute(
      AdminNavigationZone.users,
      title: 'Users',
      purpose: 'Member management: find a person, see their role, change it '
          'in place.',
      discussionQuestions: const [
        'Deactivate a member instead of deleting?',
        'Per-user test verification codes for store reviewers — manage '
            'them here?',
      ],
    ),
    studioSpecForRoute(
      AdminNavigationZone.settings,
      title: 'Settings',
      purpose: 'Application settings stored in the AppSetting model — the '
          'club changes its own texts without redeploys.',
      discussionQuestions: const [
        'Which other settings belong here: working hours, booking limits?',
      ],
    ),
  ],
);

final authZoneStudioSpec = StudioZoneSpec(
  label: 'Authentication',
  rootPath: AuthNavigationZone.auth.fullPath,
  access: StudioZoneAccess.signedOut,
  screens: [
    studioSpecForRoute(
      AuthNavigationZone.auth,
      title: 'Sign in',
      purpose: 'Passwordless onboarding: phone number + one-time code. The '
          'fewer steps, the more clients finish registration.',
      discussionQuestions: const [
        'Alternative code channels: Telegram, email?',
      ],
    ),
  ],
);
