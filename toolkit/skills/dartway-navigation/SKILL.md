---
name: dartway-navigation
description: >-
  DartWay Router navigation rules for Flutter (DartWay projects): zones as enums
  implementing DwNavigationRoute<AppRouterState>; descriptors
  DwNavigationRouteDescriptor.zoneRoot/.simple/.parameterized; zone guards in
  zoneGuards; type-safe parameters via an enum with DwNavigationParamsMixin
  (set/fromPath/fromQuery); the router is assembled with DwRouter<T>(routerState:,
  navigationZones:, pageBuilder:, options:). Use when creating or editing routes,
  screens, redirects and navigation between zones.
---

# DartWay Router — navigation

Navigation rules for DartWay projects. The router is a wrapper over go_router: `dartway_router` **re-exports `go_router`**, so `GoRouter`, `context.go` and the rest are available from the same import. See also `__FLUTTER_PKG__/CLAUDE.md`.

## Hard rules

- **Enum routes only** — no string route names in calls.
- **A zone is an enum** implementing `DwNavigationRoute<AppRouterState>`; route definitions live in `core/router/`, not in widgets.
- **Guards live in the zone** (`zoneGuards`), not scattered across screens.
- **Parameters are type-safe only**, via an enum with `DwNavigationParamsMixin`.
- Do not mix navigation logic with UI.

## Structure

```
lib/core/router/
  router.dart                       // providers + part directives
  app_router_state.dart             // ChangeNotifier: what the guards react to
  navigation_zones/
    app_navigation_zone.dart        // part of '../router.dart'
    admin_navigation_zone.dart
    auth_navigation_zone.dart
```

Zones are `part of '../router.dart'`: that way they see the shared imports and each other (a guard in the app zone needs `AuthNavigationZone.auth.fullPath`).

## A zone

Every route is an enum value with a descriptor. Required members: `descriptor`, `zoneRoot`, `shellRouteBuilder`, `statefulShellRouteBuilder`, `zoneGuards`.

Descriptors: `.zoneRoot(pageWidget:)` — the zone root; `.simple(pageWidget:, parent:)` — a regular page; `.parameterized(pageWidget:, parameter:, parent:)` — a page with a path parameter.

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
  String get zoneRoot => ''; // '' — the site root; 'admin' → /admin/...

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  /// A guard returns a redirect path, or null if access is allowed. That way no
  /// screen in the zone checks authorization on its own.
  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
      ];
}
```

A role-specific zone — the same guards, one after another:

```dart
  @override
  String get zoneRoot => 'admin';

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
        (state) => !state.isAdmin ? AppNavigationZone.home.fullPath : null,
      ];
```

## Router state

`AppRouterState` is a `ChangeNotifier` the guards watch: it listens to providers and calls `notifyListeners()`, which makes the guards re-run. There is no other link between authorization and navigation.

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

## Assembling the router

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

In the app: `MaterialApp.router(routerConfig: ref.watch(appRouterProvider).router)`.

## Transitions

The route name is `.name` (the enum), the full path is `.fullPath`. A transition:

```dart
GoRouter.of(context).goNamed(AdminNavigationZone.admin.name);
```

`GoRouter` comes from `dartway_router` (the re-export), a separate `go_router` import is not needed. Type safety comes from the enum: there are no string names in the call.

## Parameters

```dart
enum AppParams<T> with DwNavigationParamsMixin<T> {
  userProfileId<int>(),
  searchQuery<String>(),
}

// route:
userDetail(
  DwNavigationRouteDescriptor.parameterized(
    pageWidget: UserDetailPage(),
    parameter: AppParams.userProfileId,
    parent: home,
  ),
),

// transition:
GoRouter.of(context).goNamed(
  AppNavigationZone.userDetail.name,
  pathParameters: AppParams.userProfileId.set(42),
);

// reading it on the page — from BuildContext, not from ref:
final userProfileId = AppParams.userProfileId.fromPath(context);
```

Mixin methods: `set(value)` → the map for a transition; `fromPath(context)` / `fromQuery(context)` — throw if the parameter is missing; `fromPathOrNull` / `fromQueryOrNull` — return null.

## Common mistakes

- String route names and raw parameter maps instead of enums.
- Checking authorization inside a screen instead of `zoneGuards`.
- A forgotten `parent` on `.simple`/`.parameterized` — the route will not take its place in the zone tree.
- Changing state without `notifyListeners()` — the guards will not re-run.
