---
name: dartway-navigation
description: >-
  DartWay Router navigation rules for Flutter (DartWay projects): zones as enums
  implementing DwNavigationRoute<AppRouterState>; descriptors
  DwNavigationRouteDescriptor.zoneRoot/.simple/.parameterized; zone guards in
  zoneGuards; type-safe parameters via an enum with DwNavigationParamsMixin
  (set/fromPath/fromQuery); AppRouterState is a record held by a provider; the router is
  assembled in a provider with DwAppRouter<T>(ref:, routerState: <provider>,
  navigationZones:, pageBuilder:, options:). A screen is a route — no Navigator.push or
  MaterialPageRoute; dialogs and sheets through the kit; back from a page is
  goNamed(parent) or the AppBar's leading button, Navigator.of(context).pop only
  closes a dialog or a sheet; what a screen opens on is a route parameter, not a focus notifier;
  "new" is its own route, never id 0. Use when creating or editing routes,
  screens, redirects and navigation between zones.
---

# DartWay Router — navigation

Navigation rules for DartWay projects. The router is a wrapper over go_router: `dartway_router` **re-exports `go_router`**, so `GoRouter`, `context.go` and the rest are available from the same import — and `dartway_core_flutter` re-exports `dartway_router`, so a project imports neither separately. See also `.claude/CLAUDE.md`.

## Hard rules

- **Enum routes only** — no string route names in calls.
- **A zone is an enum** implementing `DwNavigationRoute<AppRouterState>`; route definitions live in `core/router/`, not in widgets.
- **Route names are global** — a name belongs to the whole app, not to its enum. The same value in two zones is an error; see [Route names are global](#route-names-are-global).
- **Guards live in the zone** (`zoneGuards`), not scattered across screens.
- **Parameters are type-safe only**, via an enum with `DwNavigationParamsMixin`.
- Do not mix navigation logic with UI.
- **A screen is a route.** No `Navigator.push`, no `MaterialPageRoute`/`CupertinoPageRoute`/
  `PageRouteBuilder` outside `ui_kit/` and `core/router/`: a pushed page has no address, no guard,
  and nothing a link can reopen. Dialogs and sheets open through the kit (`context.showAppDialog`,
  `context.showAppBottomSheet`). Both are `forbiddenNavigationCall` in `dart run dartway_cli:dartway check`.
- **Back from a page is the router's; `pop` is a dialog's or a sheet's.** A page goes back with
  `GoRouter.of(context).goNamed(<parent>.name)` or the `AppBar`'s own leading button — both keep
  the address true. `Navigator.of(context).pop(value)` closes a dialog or a sheet, called with
  **the builder's own context** (the one the dialog or the sheet was built with), so it closes that
  route and nothing under it. `Navigator.pop(context)`, `GoRouter.of(context).pop()` and
  `context.pop()` fail the check; `Navigator.of(context).pop` on a page is not caught by it and is
  still wrong.
- **Transitions go through the context**, with one exception that is a fact rather than a
  preference — see [The one transition that has no context](#the-one-transition-that-has-no-context).

## Structure

```
lib/core/router/
  router.dart                       // providers + part directives
  app_router_state.dart             // record + provider: what the guards decide by
  navigation_zones/
    app_navigation_zone.dart        // part of '../router.dart'
    admin_navigation_zone.dart
    admin_params.dart               // the admin zone's parameter enum
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
  /// screen in the zone checks authorization on its own. It is told the
  /// `DwNavigationTarget` being entered, so a sign-in gate remembers where the
  /// person was going.
  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state, target) =>
            state.isSignedIn ? null : AuthNavigationZone.signInFrom(target),
      ];
}
```

**Back to the link after signing in is already wired**: `AuthNavigationZone.signInFrom(target)`
sends a signed-out person to sign-in with `?from=<where they were going>`, and the auth zone's
guard sends them on once signed in. A gate into a new zone uses `signInFrom`, not
`AuthNavigationZone.auth.fullPath`; the sign-in screen never navigates after signing in on its own,
or the link is lost.

A role-specific zone — the same guards, one after another:

```dart
  @override
  String get zoneRoot => 'admin';

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state, target) =>
            state.isSignedIn ? null : AuthNavigationZone.signInFrom(target),
        // Only once the role is known: an admin opening /admin while the
        // profile is still loading must not be sent away for it.
        (state, _) => state.role != null && state.role != UserRole.admin
            ? AppNavigationZone.home.fullPath
            : null,
      ];
```

A guard decides what the user is **shown**, never what they may **read**: the admin zone's data is
kept from everyone else by the server's access rules (`dartway-access`), and a guard that is wrong
costs a screen, not a leak.

## Router state

`AppRouterState` is an immutable record, and `appRouterStateProvider` derives it from the providers the guards depend on. The router follows that provider: whenever the record changes it re-runs the guards on the location shown, so signing in leaves the sign-in screen and signing out returns to it — nothing navigates by hand, and there is no other link between authorization and navigation. An equal record re-runs nothing, so put in it only what the guards read. No `ChangeNotifier`, no `Listenable`: the router keeps go_router's refresh to itself.

The skeleton's derives from two things: `dw.accountId` — known from the stored session at start, before the server has answered, so a signed-in user opens straight into the app — and the role on the signed-in profile (`myProfileProvider` in `core/profile/`), which is a live request, so a role an admin changes re-runs the guards without a reload.

```dart
typedef AppRouterState = ({bool isSignedIn, UserRole? role});

final appRouterStateProvider = Provider<AppRouterState>(
  (ref) => (
    isSignedIn: ref.watch(dw.accountId) != null,
    // `null` while signed out and while the profile has not loaded yet.
    role: ref.watch(myProfileProvider.select((profile) => profile.value?.role)),
  ),
);
```

## Assembling the router

```dart
final appRouterProvider = Provider<DwAppRouter<AppRouterState>>(
  (ref) => DwAppRouter<AppRouterState>(
    ref: ref, // follows routerState through it, and is disposed with this provider
    routerState: appRouterStateProvider, // the provider, not ref.watch of it
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
  ),
);
```

In the app: `MaterialApp.router(routerConfig: ref.watch(appRouterProvider).router)`. The watch is what keeps the guards following: Riverpod pauses a provider nobody listens to, and its subscriptions with it. Watch nothing inside `appRouterProvider` — a rebuild is a new router and a lost navigation stack.

## Route names are global

`navigationZones` is where the names of every zone meet. Each zone is an enum,
and an enum gives its values a namespace of their own — so
`AppNavigationZone.projects` and `AdminNavigationZone.projects` both compile
without a word of complaint. The router works the other way round: it keeps a
**single registry for the whole app** and resolves every route by name
(`goNamed(...)`, `topRouteFromState`), so one name can belong to one route only.
Two zones owning a concept called `projects` is the natural thing to write, and
it is an error.

`DwAppRouter` refuses to assemble in that case and names both declarations:

```
Duplicate route name "projects".
Declared by:
  - AppNavigationZone.projects (navigationZones[0])
  - AdminNavigationZone.projects (navigationZones[1])
```

The router is usually built inside a provider, so the throw lands wherever that
provider is first read — typically the first screen, or a widget test that has
nothing to do with navigation. Read the message, not the stack.

For a `.simple` route the name is also its URL segment by default, so renaming
one moves its path with it — unless the descriptor sets `extraPathSegment`,
which **replaces** the enum name in the URL rather than prefixing it: keep
`/admin/projects` while calling the value `projectAdmin` with
`DwNavigationRouteDescriptor.simple(extraPathSegment: 'projects')`. Reach for
this when the collision is real (two zones need the same word in the URL);
otherwise pick the word that describes *that* screen —
`AdminNavigationZone.projectAdmin` at `/admin/projectAdmin` — rather than
adding a segment just to dodge the collision.

## Transitions

The route name is `.name` (the enum), the full path is `.fullPath`. A transition:

```dart
GoRouter.of(context).goNamed(AdminNavigationZone.admin.name);
```

`GoRouter` comes from `dartway_router` (the re-export), a separate `go_router` import is not needed. Type safety comes from the enum: there are no string names in the call.

### The one transition that has no context

A transition **not started by a gesture in the tree** takes the navigation
function from the router instead, because at that moment nobody holds a context:

- a tapped push notification — its handler lives outside the widget tree, is
  set up before the first frame and long before the router exists, and what it
  hands over is a payload, not a place in the tree;
- a cold start from the same tap — the tap happened before there was an app;
- a deep link, and a reply from a background handler.

This is not a loophole in the rule above; it is a place the rule does not reach.
Every push integration meets it, and meets it identically, so a project that
writes it correctly looks like a project that broke the convention — and the
next agent arrives to "fix" working code. Hence this section.

**The boundary, which is the part that matters:**

- **one seam per application**, in `core/` — not a helper each feature reaches
  for. The moment two of them exist, a transition from a gesture will go through
  one of them and the rule really is broken;
- it **holds the router**, it does not rebuild routing logic: the payload maps to
  a route name and parameters, and the transition is the router's own;
- it **cancels its subscription when the tree is destroyed**, because it
  outlives the widgets by construction;
- inside a widget the rule is unchanged: `GoRouter.of(context).goNamed(...)`.
  "There was no context" is a fact about the callback, not an opinion about
  convenience.

Mark it, so it is re-read when the framework grows one of its own:

```dart
// TODO(dartway, checked: <ref>): navigating from a payload with no context;
// the framework hands over the payload and stops there.
```

The framework can hand over the payload; **which route a payload means is the
application's**, so a seam of some shape stays the application's either way.

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

## What a screen opens on is its address

**A screen's subject is a route parameter, never a one-shot notifier.** "Open the chat and scroll to
this message", "open the plan on this day" — the thing to show goes in the address
(`pathParameters: AppParams.messageId.set(id)`, or a query parameter), and the page reads it with
`fromPath` / `fromQueryOrNull`. A provider set just before `goNamed` and cleared by the page once read
("focus this") is lost on a reload, a link and a back gesture, races the page's first build, and has
no shape a check can see — so it is written here.

**"New" is a route of its own, never an id nobody has.** A create screen beside an edit screen is two
descriptors — `.simple(pageWidget: CourseEditorPage(), parent: courses)` for the new one and
`.parameterized(…, parameter: AdminParams.courseId)` for an existing one — not the edit route opened
with `courseId.set(0)` and an `if (id == 0)` in the page. `0` and `-1` are not ids: a route parameter
set to one (`…Params.<name>.set(0)`) fails the check (`sentinelId`); the comparison in the page and
a command sent with id `0` for "create" are the same mistake, left to reading; "none" is `null`.

## Common mistakes

- String route names and raw parameter maps instead of enums.
- Checking authorization inside a screen instead of `zoneGuards`.
- The same route name in two zones — the enums have separate namespaces, the router does not.
- A forgotten `parent` on `.simple`/`.parameterized` — the route will not take its place in the zone tree.
- `Navigator.push(MaterialPageRoute(…))` for a screen, `showDialog` from a feature, a page closed with `pop`.
- A "focus" provider instead of a route parameter; id `0` for "new".
- Changing state without `notifyListeners()` — the guards will not re-run.
