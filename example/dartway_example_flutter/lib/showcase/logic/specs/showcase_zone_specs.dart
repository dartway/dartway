import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_client_screen_specs.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_club_screen_specs.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_screen_spec.dart';

const appZoneShowcaseSpec = ShowcaseZoneSpec(
  label: ShowcaseText('Club app', 'Приложение клуба'),
  rootRoute: AppNavigationZone.schedule,
  screens: [
    scheduleScreenSpec,
    bookingsScreenSpec,
    newsScreenSpec,
    chatScreenSpec,
    profileScreenSpec,
    servicesScreenSpec,
  ],
);

const authZoneShowcaseSpec = ShowcaseZoneSpec(
  label: ShowcaseText('Authentication', 'Авторизация'),
  rootRoute: AuthNavigationZone.auth,
  screens: [
    ShowcaseScreenSpec(
      route: AuthNavigationZone.auth,
      title: ShowcaseText('Sign in', 'Вход'),
      purpose: ShowcaseText(
        'Passwordless onboarding: phone number + one-time code. The fewer '
            'steps, the more clients finish registration.',
        'Онбординг без паролей: телефон + одноразовый код. Чем меньше '
            'шагов, тем больше клиентов доходит до конца.',
      ),
      featureSpec: [
        ShowcaseText(
          'Model-driven auth: the flow is saveModel of DwAuthRequest and '
              'DwAuthVerification — no custom endpoints.',
          'Model-driven авторизация: весь флоу — saveModel моделей '
              'DwAuthRequest и DwAuthVerification, без своих эндпоинтов.',
        ),
        ShowcaseText(
          'Session persists across restarts via the authentication key '
              'manager.',
          'Сессия переживает перезапуск через менеджер ключей авторизации.',
        ),
        ShowcaseText(
          'Dev mode uses the fixed code 000000 — that is how the persona '
              'switcher above works.',
          'В dev-режиме фиксированный код 000000 — так работает '
              'переключатель персон выше.',
        ),
      ],
      discussionQuestions: [
        ShowcaseText(
          'Alternative code channels: Telegram, email?',
          'Альтернативные каналы кода: Telegram, email?',
        ),
      ],
    ),
  ],
);
