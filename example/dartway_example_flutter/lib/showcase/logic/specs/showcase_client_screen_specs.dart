import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_screen_spec.dart';

const scheduleScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.schedule,
  title: ShowcaseText('Schedule', 'Расписание'),
  purpose: ShowcaseText(
    'The client entry point: upcoming club sessions grouped by day, '
        'booked in two taps. Business goal: turn attention into bookings '
        'with zero friction.',
    'Точка входа клиента: ближайшие занятия клуба по дням, запись в два '
        'тапа. Бизнес-задача: превращать внимание в записи без трения.',
  ),
  featureSpec: [
    ShowcaseText(
      'Live list: ref.watchModelList<ClubSession>() — realtime sync, '
          'pagination and loading states out of the box.',
      'Живой список: ref.watchModelList<ClubSession>() — realtime-синк, '
          'пагинация и лоадеры из коробки.',
    ),
    ShowcaseText(
      'Booking rules live on the server in DwCrudConfig.validateSave: '
          'capacity, duplicates, past sessions.',
      'Правила записи живут на сервере в DwCrudConfig.validateSave: '
          'вместимость, дубли, прошедшие занятия.',
    ),
    ShowcaseText(
      'Declarative backend filter narrows the query to upcoming sessions.',
      'Декларативный backend-фильтр сужает выборку до предстоящих занятий.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText(
      'Hide fully booked sessions or show them as sold out?',
      'Прятать занятия без мест или показывать как sold out?',
    ),
    ShowcaseText(
      'Show "X of Y spots" live? That is a DTO-level aggregate (level 3).',
      'Показывать «X из Y мест» вживую? Это DTO-агрегат (уровень 3).',
    ),
  ],
);

const bookingsScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.bookings,
  title: ShowcaseText('My bookings', 'Мои записи'),
  purpose: ShowcaseText(
    'The client manages own visits: live statuses, cancellation, '
        'a review after an attended session.',
    'Клиент управляет своими визитами: живые статусы, отмена, отзыв '
        'после посещения.',
  ),
  featureSpec: [
    ShowcaseText(
      'Server access filter: a client physically receives only own '
          'bookings; staff sees all — one function in the config.',
      'Серверный access-фильтр: клиент физически получает только свои '
          'записи, staff — все; одна функция в конфиге.',
    ),
    ShowcaseText(
      'Status changes arrive in realtime (booked → attended by staff).',
      'Смена статуса прилетает в realtime (booked → attended от staff).',
    ),
    ShowcaseText(
      'Review rule in validateSave: own attended booking, one per visit.',
      'Правило отзыва в validateSave: своё посещённое занятие, один отзыв.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText(
      'Booking reminders: in-app notification or push?',
      'Напоминания о записи: in-app нотификация или пуш?',
    ),
    ShowcaseText(
      'One-tap repeat booking of a past session?',
      'Повтор прошлой записи в один тап?',
    ),
  ],
);

const newsScreenSpec = ShowcaseScreenSpec(
  route: AppNavigationZone.news,
  title: ShowcaseText('Club news', 'Новости клуба'),
  purpose: ShowcaseText(
    'The retention channel: news and promotions keep clients returning '
        'to the app between visits.',
    'Канал удержания: новости и акции возвращают клиента в приложение '
        'между визитами.',
  ),
  featureSpec: [
    ShowcaseText(
      'Realtime feed with author include — the classic "40 lines of '
          'config" DartWay demo.',
      'Realtime-лента с include автора — классическое демо DartWay '
          '«40 строк конфига».',
    ),
    ShowcaseText(
      'Publishing is staff-only via allowSave; the UI hides the button, '
          'the server enforces the rule.',
      'Публикация только для staff через allowSave; UI прячет кнопку, '
          'правило держит сервер.',
    ),
  ],
  discussionQuestions: [
    ShowcaseText(
      'Reactions and comments on posts?',
      'Реакции и комментарии к постам?',
    ),
    ShowcaseText(
      'Pin important announcements to the top?',
      'Закреплять важные анонсы сверху?',
    ),
  ],
);
