import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'package:dartway_starter_flutter/core/router/router.dart';
import 'studio_client_screen_specs.dart';

final appZoneStudioSpec = StudioZoneSpec(
  label: 'App',
  rootPath: AppNavigationZone.home.fullPath,
  access: StudioZoneAccess.signedIn,
  screens: [homeStudioSpec, profileStudioSpec],
);

final adminZoneStudioSpec = StudioZoneSpec(
  label: 'Admin',
  rootPath: AdminNavigationZone.admin.fullPath,
  access: StudioZoneAccess.signedIn,
  // Role-gated by the app itself: the router guard and server filters are
  // the protection. Studio only signs in with whatever persona is chosen —
  // a non-admin lands wherever the guards send it.
  screens: [
    dwStudioSpecForRoute(
      AdminNavigationZone.admin,
      title: 'Dashboard',
      purpose:
          'The admin home: headline counters over live data. The future '
          'home of event analytics (visits, conversion, retention).',
      discussionQuestions: const [
        'Which three numbers does the owner of your product check every morning?',
      ],
    ),
    dwStudioSpecForRoute(
      AdminNavigationZone.users,
      title: 'Users',
      purpose:
          'Member management: find a person, see their role, change it '
          'in place.',
      discussionQuestions: const [
        'Deactivate a member instead of deleting?',
        'Per-user test verification codes for store reviewers — manage '
            'them here?',
      ],
    ),
    dwStudioSpecForRoute(
      AdminNavigationZone.settings,
      title: 'Settings',
      purpose:
          'Application settings stored in the AppSetting model — the '
          'business changes its own texts without a redeploy.',
      discussionQuestions: const ['Which other settings belong here?'],
    ),
  ],
);

final authZoneStudioSpec = StudioZoneSpec(
  label: 'Authentication',
  rootPath: AuthNavigationZone.auth.fullPath,
  access: StudioZoneAccess.signedOut,
  screens: [
    dwStudioSpecForRoute(
      AuthNavigationZone.auth,
      title: 'Sign in',
      purpose:
          'Passwordless onboarding: phone number + one-time code. The '
          'fewer steps, the more clients finish registration.',
      discussionQuestions: const [
        'Alternative code channels: Telegram, email?',
      ],
    ),
  ],
);
