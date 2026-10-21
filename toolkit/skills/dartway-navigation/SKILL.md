---
name: dartway-navigation
description: "Declare zones, routes, typed parameters and guards; navigate through the app router and kit."
---

# DartWay — navigation (`dartway-navigation`)

The router wraps go_router; `dartway_core_flutter` re-exports both, so no separate import. The
skeleton's `__FLUTTER_PKG__/lib/core/router/` is the reference: `router.dart` (the provider that builds
`DwAppRouter`, zones as `part` files), `app_router_state.dart` (what the guards decide by),
`navigation_zones/`.

## Zones and routes

A zone is an enum implementing `DwNavigationRoute<AppRouterState>`; every route is a value with a
descriptor — `.zoneRoot(pageWidget:)`, `.simple(pageWidget:, parent:)`,
`.parameterized(pageWidget:, parameter:, parent:)` — and the zone declares `zoneRoot` (`''` or
`'admin'`), `shellRouteBuilder`, `statefulShellRouteBuilder` and `zoneGuards`. A route without a
`parent` sits at the top of its zone, not under the screen it belongs to. Route definitions live in
`core/router/`, never in widgets; calls use enum values, never strings.

```dart
enum AppNavigationZone implements DwNavigationRoute<AppRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage(), parent: home));
  // … descriptor, zoneRoot, shell builders

  @override
  List<DwDecisionGuard<AppRouterState>> get zoneGuards => [
    (state, target) => switch (state.isSignedIn) {
      null => DwGuardDecision.pending,
      false => DwGuardDecision.redirect(AuthNavigationZone.signInFrom(target)),
      true => DwGuardDecision.allow,
    },
  ];
}
```

- **Guards live in the zone** and return `DwGuardDecision.allow`, `.redirect(path)` or `.pending`.
  A guard decides only on known facts; unknown → `pending`, never `allow`. Unknown fields in the
  router-state record are nullable; a guard reading one handles `null` explicitly. A guard that
  lets `null` through to a page is a **review blocker**. Guards decide what the user is shown,
  never what they may read (`dartway-access`). A gate into a new zone uses `signInFrom(target)`;
  the sign-in screen never navigates on its own.
- **One loading page**: provide `DwGoRouterOptions.pendingBuilder` when guards can be pending.
  The router shows it in place of the target inside the zone's unchanged shell, preserves the
  URL and history, and re-runs guards on state
  changes. It never builds a target frame while undecided.
- **Guard tests**: import `package:dartway_router/testing.dart` and run `dwCheckPendingGuards`
  with every zone, representative known states (including redirecting values), and a `nullableFields`
  map from each nullable field's name to a function replacing it with null. Dart records cannot
  enumerate fields at runtime, so list every nullable field explicitly. Supply concrete `targets`
  for parameterized or query-sensitive guards. The helper fails if an unknown value allows a
  target where a known value redirects. Keep a widget regression proving no target frame builds.
- **The router state** is an immutable record from `appRouterStateProvider`, holding only what guards
  read; the router re-runs the guards when it changes — sign-in and sign-out navigate by themselves.
- **`DwAppRouter(ref:, routerState: appRouterStateProvider, …)`** is built in a provider that watches
  nothing (a rebuild is a new router and a lost stack), disposes itself with it
  (`routerDisposedByApp`), and must be watched — `MaterialApp.router(routerConfig:
  ref.watch(appRouterProvider).router)` — or Riverpod pauses it.
- **Route names are global** (`routeNameDuplicated`): the router resolves by name across zones. Pick
  the word that describes that screen (`projectAdmin`); `extraPathSegment` replaces the URL segment
  when two zones truly need the same word.

## Going somewhere

```dart
GoRouter.of(context).goNamed(
  AppNavigationZone.userDetail.name,
  pathParameters: AppParams.userProfileId.set(42),
);
```

- **Parameters are typed**: `enum AppParams<T> with DwNavigationParamsMixin<T> { userProfileId<int>() }`;
  `set(value)` for the transition, `fromPath(context)` / `fromQuery(context)` (throw) or
  `fromPathOrNull` / `fromQueryOrNull` on the page.
- **A screen is a route; a dialog or sheet opens through the kit** (`context.showAppDialog`,
  `showAppBottomSheet`) — `forbiddenNavigationCall`; a yes/no before an action is not a dialog but
  `dw.action(…, confirmation: DwUiConfirmation(…))`. **Back from a page** is `goNamed(<parent>.name)` or
  the `AppBar`'s leading button; `Navigator.of(context).pop(value)` closes only a dialog or a sheet, with
  the builder's own context — on a page the check does not catch it and it is still wrong.
- **Asking before leaving a page** is the route descriptor's `onExit`, not `PopScope`: `PopScope` misses
  browser back and forward, a typed URL and a header link on the web; `onExit` is asked on every way out.
  Descriptors are `const`, so it is a top-level function or a static method —
  `onExit: askBeforeLeaving` with `Future<bool> askBeforeLeaving(BuildContext context,
  DwNavigationTarget leaving)` — that reads whether to ask from app state
  (`ProviderScope.containerOf(context)`), opens the sheet from `context`, and answers `true` to leave,
  `false` to stay. It also fires on a sign-out redirect and a tab switch, so it checks its own
  precondition first and answers `true` when there is nothing to ask.
- **A screen's subject is its address**: "open the chat at this message" is a path or query parameter,
  never a provider set before `goNamed` and cleared by the page (lost on reload, link and back).
- **"New" is its own route** (`.simple` for create beside `.parameterized` for edit), never an id `0` or
  `-1` (`sentinelId`); "none" is `null`.

## The one transition with no context

A tapped push notification, a cold start from it, a deep link or a background reply has a payload and
no place in the tree. It goes through **one seam per app, in `core/`**, that holds the router, maps the
payload to a route name and parameters, and cancels its subscription with the tree; inside widgets the
rule above is unchanged. For a push tap the framework hands the payload over through
`dw.plugins.push.opened`; which route it means is the app's. Worked example, in the framework repository's example (on GitHub, not in this project):
[`push_opened_listener.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/lib/core/push/push_opened_listener.dart).
