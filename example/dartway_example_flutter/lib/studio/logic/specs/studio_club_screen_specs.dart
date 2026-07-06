import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final chatStudioSpec = studioSpecForRoute(
  AppNavigationZone.chat,
  title: const StudioText('Team chat', 'Чат команды'),
  purpose: const StudioText(
    'Internal coordination of the club staff — shift handovers, questions, '
        'announcements — without leaving the product.',
    'Внутренняя координация команды клуба — передача смен, вопросы, '
        'объявления — не выходя из продукта.',
  ),
  featureSpec: const [
    StudioText(
      'A realtime chat is ~40 lines of DwCrudConfig — no sockets code.',
      'Realtime-чат — это ~40 строк DwCrudConfig, без кода сокетов.',
    ),
    StudioText(
      'Secure-by-default: clients never receive chat data — one '
          'staff-only access filter line, not scattered UI checks.',
      'Secure-by-default: клиент не получает данные чата вообще — одна '
          'строка staff-фильтра, а не проверки по всему UI.',
    ),
    StudioText(
      'Try it: switch persona to Client Ivan — the tab disappears.',
      'Проверь: переключись на клиента Ивана — вкладка исчезнет.',
    ),
  ],
  discussionQuestions: const [
    StudioText('Multiple channels and mentions?', 'Каналы и упоминания?'),
    StudioText('File attachments in chat?', 'Вложения в чате?'),
  ],
);

final profileStudioSpec = studioSpecForRoute(
  AppNavigationZone.profile,
  title: const StudioText('Profile', 'Профиль'),
  purpose: const StudioText(
    'The client account: personal data, entry to the price list, session '
        'management.',
    'Аккаунт клиента: личные данные, вход в прайс-лист, управление '
        'сессией.',
  ),
  featureSpec: const [
    StudioText(
      'Profile editing guarded by allowSave: self or admin only.',
      'Редактирование профиля под allowSave: только сам или админ.',
    ),
    StudioText(
      'Privilege escalation guard: only the admin can change roles — '
          'a validateSave rule, not a UI convention.',
      'Защита от эскалации привилегий: роль меняет только админ — '
          'правило в validateSave, а не договорённость в UI.',
    ),
  ],
  discussionQuestions: const [
    StudioText(
      'Avatar upload via DartWay cloud storage?',
      'Загрузка аватара через cloud storage DartWay?',
    ),
  ],
);

final servicesStudioSpec = studioSpecForRoute(
  AppNavigationZone.services,
  title: const StudioText('Services', 'Услуги'),
  purpose: const StudioText(
    'The club price list: what the club offers, how long it takes and '
        'what it costs.',
    'Прайс-лист клуба: что предлагает клуб, сколько длится и стоит.',
  ),
  featureSpec: const [
    StudioText(
      'Level-1 CRUD: a public read-only list, admin-managed content.',
      'CRUD первого уровня: публичный список, контентом управляет админ.',
    ),
    StudioText(
      'Nested navigation: Profile › Services via the parent route chain.',
      'Вложенная навигация: Профиль › Услуги через parent-цепочку роутов.',
    ),
  ],
  discussionQuestions: const [
    StudioText(
      'Service photos (cloud storage upload)?',
      'Фото услуг (загрузка в cloud storage)?',
    ),
    StudioText('Service categories?', 'Категории услуг?'),
  ],
);
