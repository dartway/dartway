import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';
import 'studio_client_screen_specs.dart';
import 'studio_club_screen_specs.dart';
import 'studio_route_specs.dart';

final clubZoneStudioSpec = StudioZoneSpec(
  label: const StudioText('Club app', 'Приложение клуба'),
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

final authZoneStudioSpec = StudioZoneSpec(
  label: const StudioText('Authentication', 'Авторизация'),
  rootPath: AuthNavigationZone.auth.fullPath,
  access: StudioZoneAccess.signedOut,
  screens: [
    studioSpecForRoute(
      AuthNavigationZone.auth,
      title: const StudioText('Sign in', 'Вход'),
      purpose: const StudioText(
        'Passwordless onboarding: phone number + one-time code. The fewer '
            'steps, the more clients finish registration.',
        'Онбординг без паролей: телефон + одноразовый код. Чем меньше '
            'шагов, тем больше клиентов доходит до конца.',
      ),
      featureSpec: const [
        StudioText(
          'Model-driven auth: the flow is saveModel of DwAuthRequest and '
              'DwAuthVerification — no custom endpoints.',
          'Model-driven авторизация: весь флоу — saveModel моделей '
              'DwAuthRequest и DwAuthVerification, без своих эндпоинтов.',
        ),
        StudioText(
          'Session persists across restarts via the authentication key '
              'manager.',
          'Сессия переживает перезапуск через менеджер ключей авторизации.',
        ),
        StudioText(
          'Dev mode uses the fixed code 000000 — that is how the persona '
              'switcher works.',
          'В dev-режиме фиксированный код 000000 — так работает '
              'переключатель персон.',
        ),
      ],
      discussionQuestions: const [
        StudioText(
          'Alternative code channels: Telegram, email?',
          'Альтернативные каналы кода: Telegram, email?',
        ),
      ],
    ),
  ],
);
