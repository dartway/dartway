---
name: dartway-navigation
description: >-
  Правила навигации DartWay Router для Flutter (проекты DartWay): enum-роуты
  через NavigationZoneRoute, типобезопасные параметры через NavigationParamsMixin,
  переходы только через context-extensions (goNamed/pushTo/replaceWith), доступ к
  параметрам через ref.watchNavigationParam, централизованные redirects/guards в
  DwRouter.config(), DwBottomNavigationBar/DwMenuItem, фабрики переходов. Использовать
  при создании/правке роутов, навигации между экранами, редиректов и нижней навигации.
---

# DartWay Router — навигация

Официальные правила навигации в DartWay. `dartway_router` активно развивается — это текущие best practices. Применять для всего Flutter-кода. См. также `__FLUTTER_PKG__/CLAUDE.md`.

## Жёсткие правила

- **Только enum-роуты** — никаких строковых имён маршрутов.
- **Только типобезопасные параметры** через enum с `NavigationParamsMixin` — никаких raw-строк/мап.
- **Переходы только через context-extensions** (`context.goNamed`/`context.pushTo`/`context.replaceWith`) — никогда `router.go()` напрямую.
- **Redirects/guards — централизованно** в `DwRouter.config()`, не разбросаны по виджетам.
- Навигационную логику не мешать с UI — определения роутов изолированы в `router/`.

## Структура

```
lib/
  router/
    app_router.dart
    zones/
      app_routes.dart
```

## Определение роутов

Роуты — enum, реализующий `NavigationZoneRoute`. `SimpleNavigationRouteDescriptor` для статических страниц, `ParameterizedNavigationRouteDescriptor` — для страниц с path-параметрами. Каждый enum реализует `descriptor` и `root`.

## Параметры

```dart
enum AppParams<T> with NavigationParamsMixin<T> {
  userId<int>(),
  categoryId<int>(),
  searchQuery<String>(),
  isEnabled<bool>(),
}
```

Передача параметров и чтение:

```dart
context.pushTo(
  AppRoutes.userDetail,
  pathParameters: AppParams.userId.set(123),
);

// В виджете — только через ref, предпочитай watch для реактивности:
final userId = ref.watchNavigationParam(AppParams.userId);
```

## Инициализация роутера

```dart
final appRouterProvider = dwRouterStateProvider(
  DwRouter.config()
    .addNavigationZones([AppRoutes.values])
    .setInitialLocation(AppRoutes.home.routePath)
    .setPageFactory(DwPageBuilders.material)
    .setNotFoundPage(const NotFoundPageWidget()),
);
```

`MaterialApp.router` инициализируется роутером из `ref.watch(appRouterProvider)`. Всегда задавай `.setInitialLocation(...)` и `.setNotFoundPage(...)`.

## Redirects & Guards

```dart
DwRouter.config()
  .addNavigationZones([AppRoutes.values])
  .setRedirect((context, currentRoute) {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated && currentRoute == AppRoutes.profile) {
      return AppRoutes.home;
    }
    return null;
  });
```

## UI навигации

- Нижняя навигация — `DwBottomNavigationBar` (не изобретать свою).
- Пункты меню — `DwMenuItem` (icon/svg/custom).
- Бейджи — `NotificationBadge` или кастомный виджет.

## Переходы (transitions)

Встроенные фабрики `DwPageBuilders.material/.fade/.slide/.scale`. Кастомные — через `CustomTransitionPage`. Длительность ≤ 400ms.

## Полный пример

```dart
// app_router.dart
enum AppParams<T> with NavigationParamsMixin<T> {
  userId<int>(),
  categoryId<int>(),
}

enum AppRoutes implements NavigationZoneRoute {
  home(SimpleNavigationRouteDescriptor(page: HomePage())),
  profile(SimpleNavigationRouteDescriptor(page: ProfilePage())),
  userDetail(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(),
    parameter: AppParams.userId,
  ));

  const AppRoutes(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}

final appRouterProvider = dwRouterStateProvider(
  DwRouter.config()
    .addNavigationZones([AppRoutes.values])
    .setInitialLocation(AppRoutes.home.routePath)
    .setPageFactory(DwPageBuilders.material)
    .setNotFoundPage(const NotFoundPageWidget()),
);
```

## Частые ошибки

- Строковые имена маршрутов / raw-мапы параметров.
- Прямой вызов `router.go()`.
- Забытые `descriptor`/`root`, отсутствие not-found страницы.
- Redirect-логика, размазанная по виджетам.
