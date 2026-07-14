import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';
import '../studio_personas.dart';
import 'studio_client_screen_specs.dart';
import 'studio_route_specs.dart';

final appZoneStudioSpec = StudioZoneSpec(
  label: 'App',
  rootPath: AppNavigationZone.home.fullPath,
  access: StudioZoneAccess.signedIn,
  screens: [
    homeStudioSpec,
    profileStudioSpec,
  ],
);

final adminZoneStudioSpec = StudioZoneSpec(
  label: 'Admin',
  rootPath: AdminNavigationZone.admin.fullPath,
  access: StudioZoneAccess.signedIn,
  // Role-gated: Studio switches to Alex before entering; the router guard
  // and server filters remain the real protection.
  allowedPersonaIds: [StudioPersonas.adminAlex.id],
  screens: [
    studioSpecForRoute(
      AdminNavigationZone.admin,
      title: 'Dashboard',
      purpose: 'The admin home: headline counters over live data. The future '
          'home of event analytics (visits, conversion, retention).',
      featureSpec: const [
        'Counters are plain watchModelList calls — the same realtime CRUD '
            'the client app uses, no separate admin API.',
        'The whole zone is guarded by role: non-admins are redirected by '
            'the router guard, and the server filters the data anyway.',
        'Adaptive shell: a navigation rail on desktop, a bottom bar on '
            'phones — try switching the preview frame.',
      ],
      discussionQuestions: const [
        'Which three numbers does a club owner check every morning?',
      ],
    ),
    studioSpecForRoute(
      AdminNavigationZone.users,
      title: 'Users',
      purpose: 'Member management: find a person, see their role, change it '
          'in place.',
      featureSpec: const [
        'The users list is admin-only on the server — the same UserProfile '
            'model the app uses, filtered by role.',
        'Role editing is guarded by validateSave on the server: the UI '
            'dropdown is a convenience, not the protection.',
        'Search and role filter are client-side over the live list.',
      ],
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
      featureSpec: const [
        'AppSetting is a regular CRUD model: admin-only writes, public '
            'reads — the app picks up changes in realtime.',
      ],
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
      featureSpec: const [
        'Model-driven auth: the flow is saveModel of DwAuthRequest and '
            'DwAuthVerification — no custom endpoints.',
        'Session persists across restarts via the authentication key '
            'manager.',
        'Test personas sign in with a per-user test verification code — '
            'that is how the persona switcher works.',
      ],
      discussionQuestions: const [
        'Alternative code channels: Telegram, email?',
      ],
    ),
  ],
);
