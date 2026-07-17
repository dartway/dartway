---
name: dartway-navigation
description: >-
  Правила навигации DartWay Router для Flutter (проекты DartWay): зоны как enum'ы,
  реализующие DwNavigationRoute<AppRouterState>; дескрипторы
  DwNavigationRouteDescriptor.zoneRoot/.simple/.parameterized; гварды зоны в
  zoneGuards; типобезопасные параметры через enum с DwNavigationParamsMixin
  (set/fromPath/fromQuery); роутер собирается DwRouter<T>(routerState:,
  navigationZones:, pageBuilder:, options:). Использовать при создании/правке
  роутов, экранов, редиректов и навигации между зонами.
---

# DartWay Router — навигация

Правила навигации в проектах DartWay. Роутер — обёртка над go_router: `dartway_router` **ре-экспортирует `go_router`**, поэтому `GoRouter`, `context.go` и прочее доступны из того же импорта. См. также `__FLUTTER_PKG__/CLAUDE.md`.

## Жёсткие правила

- **Только enum-роуты** — никаких строковых имён маршрутов в вызовах.
- **Зона = enum**, реализующий `DwNavigationRoute<AppRouterState>`; определения роутов живут в `core/router/`, не в виджетах.
- **Гварды — в зоне** (`zoneGuards`), а не разбросаны по экранам.
- **Параметры — только типобезопасные**, через enum с `DwNavigationParamsMixin`.
- Навигационную логику не мешать с UI.

## Структура

```
lib/core/router/
  router.dart                       // провайдеры + part-директивы
  app_router_state.dart             // ChangeNotifier: на что реагируют гварды
  navigation_zones/
    app_navigation_zone.dart        // part of '../router.dart'
    admin_navigation_zone.dart
    auth_navigation_zone.dart
```

Зоны — `part of '../router.dart'`: так они видят общие импорты и друг друга (гварду из app-зоны нужен `AuthNavigationZone.auth.fullPath`).

## Зона

Каждый роут — значение enum'а с дескриптором. Обязательные члены: `descriptor`, `zoneRoot`, `shellRouteBuilder`, `statefulShellRouteBuilder`, `zoneGuards`.

Дескрипторы: `.zoneRoot(pageWidget:)` — корень зоны; `.simple(pageWidget:, parent:)` — обычная страница; `.parameterized(pageWidget:, parameter:, parent:)` — страница с path-параметром.

```dart
part of '../router.dart';

enum AppNavigationZone implements DwNavigationRoute<AppRouterState> {
  home(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()),
  ),
  profile(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: home,
    ),
  );

  const AppNavigationZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppRouterState> descriptor;

  @override
  String get zoneRoot => ''; // '' — корень сайта; 'admin' → /admin/...

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  /// Гвард возвращает путь для редиректа или null, если пускаем. Так ни один
  /// экран зоны не проверяет авторизацию сам.
  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
      ];
}
```

Зона под роль — те же гварды, по очереди:

```dart
  @override
  String get zoneRoot => 'admin';

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
        (state) => !state.isAdmin ? AppNavigationZone.home.fullPath : null,
      ];
```

## Состояние роутера

`AppRouterState` — `ChangeNotifier`, на который смотрят гварды: он слушает провайдеры и дёргает `notifyListeners()`, из-за чего гварды перепрогоняются. Никакой другой связи между авторизацией и навигацией нет.

```dart
class AppRouterState extends ChangeNotifier {
  AppRouterState(this.ref) {
    ref.listen<bool>(isSignedInProvider, (_, next) {
      isSignedIn = next;
      notifyListeners();
    }, fireImmediately: true);
  }

  final Ref ref;
  bool isSignedIn = false;
}
```

## Сборка роутера

```dart
final appRouterProvider = Provider<DwRouter<AppRouterState>>((ref) {
  final routerState = ref.watch(appRouterStateProvider);
  return DwRouter<AppRouterState>(
    routerState: routerState,
    navigationZones: [
      AppNavigationZone.values,
      AdminNavigationZone.values,
      AuthNavigationZone.values,
    ],
    pageBuilder: DwPageBuilder.fade, // .material / .fade / .slide / .scale
    options: DwGoRouterOptions(
      initialLocation: AppNavigationZone.home.fullPath,
      debugLogDiagnostics: false,
    ),
  );
});
```

В приложении: `MaterialApp.router(routerConfig: ref.watch(appRouterProvider).router)`.

## Переходы

Имя роута — `.name` (enum), полный путь — `.fullPath`. Переход:

```dart
GoRouter.of(context).goNamed(AdminNavigationZone.admin.name);
```

`GoRouter` приезжает из `dartway_router` (ре-экспорт), отдельный импорт `go_router` не нужен. Типобезопасность даёт enum: строковых имён в вызове нет.

## Параметры

```dart
enum AppParams<T> with DwNavigationParamsMixin<T> {
  userProfileId<int>(),
  searchQuery<String>(),
}

// роут:
userDetail(
  DwNavigationRouteDescriptor.parameterized(
    pageWidget: UserDetailPage(),
    parameter: AppParams.userProfileId,
    parent: home,
  ),
),

// переход:
GoRouter.of(context).goNamed(
  AppNavigationZone.userDetail.name,
  pathParameters: AppParams.userProfileId.set(42),
);

// чтение на странице — из BuildContext, не из ref:
final userProfileId = AppParams.userProfileId.fromPath(context);
```

Методы миксина: `set(value)` → мапа для перехода; `fromPath(context)` / `fromQuery(context)` — бросают, если параметра нет; `fromPathOrNull` / `fromQueryOrNull` — вернут null.

## Частые ошибки

- Строковые имена маршрутов и raw-мапы параметров вместо enum'ов.
- Проверка авторизации внутри экрана вместо `zoneGuards`.
- Забытый `parent` у `.simple`/`.parameterized` — роут не встанет в дерево зоны.
- Изменение состояния без `notifyListeners()` — гварды не перепрогонятся.
