import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';
import 'studio_route_specs.dart';

final scheduleStudioSpec = studioSpecForRoute(
  AppNavigationZone.schedule,
  title: const StudioText('Schedule', 'Расписание'),
  purpose: const StudioText(
    'The client entry point: upcoming club sessions grouped by day, '
        'booked in two taps. Business goal: turn attention into bookings '
        'with zero friction.',
    'Точка входа клиента: ближайшие занятия клуба по дням, запись в два '
        'тапа. Бизнес-задача: превращать внимание в записи без трения.',
  ),
  featureSpec: const [
    StudioText(
      'Live list: ref.watchModelList<ClubSession>() — realtime sync, '
          'pagination and loading states out of the box.',
      'Живой список: ref.watchModelList<ClubSession>() — realtime-синк, '
          'пагинация и лоадеры из коробки.',
    ),
    StudioText(
      'Booking rules live on the server in DwCrudConfig.validateSave: '
          'capacity, duplicates, past sessions.',
      'Правила записи живут на сервере в DwCrudConfig.validateSave: '
          'вместимость, дубли, прошедшие занятия.',
    ),
    StudioText(
      'Declarative backend filter narrows the query to upcoming sessions.',
      'Декларативный backend-фильтр сужает выборку до предстоящих занятий.',
    ),
  ],
  discussionQuestions: const [
    StudioText(
      'Hide fully booked sessions or show them as sold out?',
      'Прятать занятия без мест или показывать как sold out?',
    ),
    StudioText(
      'Show "X of Y spots" live? That is a DTO-level aggregate (level 3).',
      'Показывать «X из Y мест» вживую? Это DTO-агрегат (уровень 3).',
    ),
  ],
);

final bookingsStudioSpec = studioSpecForRoute(
  AppNavigationZone.bookings,
  title: const StudioText('My bookings', 'Мои записи'),
  purpose: const StudioText(
    'The client manages own visits: live statuses, cancellation, '
        'a review after an attended session.',
    'Клиент управляет своими визитами: живые статусы, отмена, отзыв '
        'после посещения.',
  ),
  featureSpec: const [
    StudioText(
      'Server access filter: a client physically receives only own '
          'bookings; staff sees all — one function in the config.',
      'Серверный access-фильтр: клиент физически получает только свои '
          'записи, staff — все; одна функция в конфиге.',
    ),
    StudioText(
      'Status changes arrive in realtime (booked → attended by staff).',
      'Смена статуса прилетает в realtime (booked → attended от staff).',
    ),
    StudioText(
      'Review rule in validateSave: own attended booking, one per visit.',
      'Правило отзыва в validateSave: своё посещённое занятие, один отзыв.',
    ),
  ],
  discussionQuestions: const [
    StudioText(
      'Booking reminders: in-app notification or push?',
      'Напоминания о записи: in-app нотификация или пуш?',
    ),
    StudioText(
      'One-tap repeat booking of a past session?',
      'Повтор прошлой записи в один тап?',
    ),
  ],
);

final newsStudioSpec = studioSpecForRoute(
  AppNavigationZone.news,
  title: const StudioText('Club news', 'Новости клуба'),
  purpose: const StudioText(
    'The retention channel: news and promotions keep clients returning '
        'to the app between visits.',
    'Канал удержания: новости и акции возвращают клиента в приложение '
        'между визитами.',
  ),
  featureSpec: const [
    StudioText(
      'Realtime feed with author include — the classic "40 lines of '
          'config" DartWay demo.',
      'Realtime-лента с include автора — классическое демо DartWay '
          '«40 строк конфига».',
    ),
    StudioText(
      'Publishing is staff-only via allowSave; the UI hides the button, '
          'the server enforces the rule.',
      'Публикация только для staff через allowSave; UI прячет кнопку, '
          'правило держит сервер.',
    ),
  ],
  discussionQuestions: const [
    StudioText(
      'Reactions and comments on posts?',
      'Реакции и комментарии к постам?',
    ),
    StudioText(
      'Pin important announcements to the top?',
      'Закреплять важные анонсы сверху?',
    ),
  ],
);
