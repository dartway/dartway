import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_screen_spec.dart';

const chatScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.chat,
  title: ShowcaseText('Team chat', 'Чат команды'),
  purpose: ShowcaseText(
    'Internal coordination of the club staff — shift handovers, questions, '
        'announcements — without leaving the product.',
    'Внутренняя координация команды клуба — передача смен, вопросы, '
        'объявления — не выходя из продукта.',
  ),
  featureSpec: [
    ShowcaseText(
      'A realtime chat is ~40 lines of DwCrudConfig — no sockets code.',
      'Realtime-чат — это ~40 строк DwCrudConfig, без кода сокетов.',
    ),
    ShowcaseText(
      'Secure-by-default: clients never receive chat data — one '
          'staff-only access filter line, not scattered UI checks.',
      'Secure-by-default: клиент не получает данные чата вообще — одна '
          'строка staff-фильтра, а не проверки по всему UI.',
    ),
    ShowcaseText(
      'Try it: switch persona to Client Ivan — the tab disappears.',
      'Проверь: переключись на клиента Ивана — вкладка исчезнет.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText('Multiple channels and mentions?', 'Каналы и упоминания?'),
    ShowcaseText('File attachments in chat?', 'Вложения в чате?'),
  ],
);

const profileScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.profile,
  title: ShowcaseText('Profile', 'Профиль'),
  purpose: ShowcaseText(
    'The client account: personal data, entry to the price list, session '
        'management.',
    'Аккаунт клиента: личные данные, вход в прайс-лист, управление '
        'сессией.',
  ),
  featureSpec: [
    ShowcaseText(
      'Profile editing guarded by allowSave: self or admin only.',
      'Редактирование профиля под allowSave: только сам или админ.',
    ),
    ShowcaseText(
      'Privilege escalation guard: only the admin can change roles — '
          'a validateSave rule, not a UI convention.',
      'Защита от эскалации привилегий: роль меняет только админ — '
          'правило в validateSave, а не договорённость в UI.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText(
      'Avatar upload via DartWay cloud storage?',
      'Загрузка аватара через cloud storage DartWay?',
    ),
  ],
);

const servicesScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.services,
  title: ShowcaseText('Services', 'Услуги'),
  purpose: ShowcaseText(
    'The club price list: what the club offers, how long it takes and '
        'what it costs.',
    'Прайс-лист клуба: что предлагает клуб, сколько длится и стоит.',
  ),
  featureSpec: [
    ShowcaseText(
      'Level-1 CRUD: a public read-only list, admin-managed content.',
      'CRUD первого уровня: публичный список, контентом управляет админ.',
    ),
    ShowcaseText(
      'Nested navigation: Profile › Services via the parent route chain.',
      'Вложенная навигация: Профиль › Услуги через parent-цепочку роутов.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText(
      'Service photos (cloud storage upload)?',
      'Фото услуг (загрузка в cloud storage)?',
    ),
    ShowcaseText('Service categories?', 'Категории услуг?'),
  ],
);
