## 3.0.0 - 2026-09-26

### Breaking

**A simple route's `extraPathSegment` replaces its name in the URL instead of prefixing it** (#314). `buildPathSegment` returned `'$extraPathSegment/$coreSegment'` for every descriptor, and a `.simple()` route's core segment is always its enum name — so `editProfile(DwNavigationRouteDescriptor.simple(parent: profile, extraPathSegment: 'edit'))` built `/profile/edit/editProfile`, not the `/profile/edit` every caller actually wanted. Checked against the framework's own rule that route names are one namespace shared by every zone: `extraPathSegment` on a simple route exists precisely to give a page a URL word of its own without forcing every zone to fight over (or copy) the enum name, so a prefix that still appended the name back on could never have been the intent — a live project's eight simple routes using it (`editProfile` → `edit`, `following` → `following`, `notificationSettings` → `notifications`, …) all read as the segment replacing the name, never as a second word next to it, and its five parameterized routes using `extraPathSegment` (see below) are unaffected.

The parameterized descriptor is unchanged: there `extraPathSegment` prefixes the parameter pattern (`:userId`), which is not a name and cannot double up — `userDetail(extraPathSegment: 'users')` still builds `/users/:userId`.

`extraPathSegment` may no longer be the empty string: an assertion catches `''` now, since it used to build a path segment that silently disappeared (`/profile/` instead of `/profile/<something>`), invisible to the duplicate-path check that exists precisely to catch a route nothing can distinguish from another.

The duplicate route name error's own explanation is corrected: it used to say "for a `.simple` route the name is also its URL segment, so the path moves with it", which was only ever true because of this same bug — a project can now rename the enum value freely and keep the URL with `extraPathSegment`.

Any project relying on the old, doubled URL of a simple route with `extraPathSegment` set breaks — and so does every route nested under one, since `fullPath` is built from the parent chain: a plain child of `planPreferences` moved from `/…/plan/planPreferences/<child>` to `/…/plan/<child>`, a parameterized child's `:id` segment moves the same way. See `docs/migrations/2026-09-26-simple-extra-path-segment-replaces-name.md` for what to check and how to bridge old links.

## 2.0.0 - 2026-09-23

### Breaking

**A zone guard is told where the person was going** (#288). `DwNavigationGuard` takes a second argument, a `DwNavigationTarget` — the location asked for (`uri`, `location`), the route's name and its path parameters — so a guard that turns someone away can name the place: "sign in, then back to `/orders/42`". The guard could only answer no, and `options.redirect`, which sees the destination, never runs once a guard has answered: the two did not compose. Every guard gains the parameter: `(state) => …` becomes `(state, target) => …`, or `(state, _) => …`.

## 1.1.2 - 2026-08-19

### Fixed

`isActive` no longer answers `false` for the route that is open.

The check compared the router **template** against the current **address**, so
a route with a parameterized segment anywhere in its chain never matched:
`/project/:projectId/issues` was compared with `/project/7/issues` and the
method answered "not active" without a warning — a navigation item simply
never lit up. Path parameters are now taken from
`GoRouterState.pathParameters` and the comparison runs per path segment.

The semantics around it are unchanged: a route stays active while a descendant
of it is open (a parent tab keeps its highlight on a nested page), a route is
not active merely because its path is a string prefix of the location (`/news`
at `/newsletter`), and a zone root with an empty path is active at its own
address only.

### Changed

A duplicate route name now says which zones declare it.

Route names are global: `DwAppRouter` keeps one registry for the whole app and
resolves every route by name. An enum, though, gives its values a namespace of
their own, so two zones each declaring `projects` compile without a word — and
the failure surfaced far from the declaration, in the first screen that touched
the router. The check itself was there, but it reported the bare name and left
both declarations to be found by hand; worse, when the two zones also collided
on the path (the usual case) the path check ran first, and its message named
neither the route nor the zone.

The name check now runs ahead of the path check — a shared name is the cause,
the shared path its symptom — and the failure carries the whole story:

```
Duplicate route name "projects".
Declared by:
  - AppNavigationZone.projects (navigationZones[0])
  - AdminNavigationZone.projects (navigationZones[1])

Route names are global across navigation zones. DwAppRouter keeps a single
registry for the whole app and resolves routes by name, so a name may be
declared once and only once. ...
```

Duplicate paths and invalid paths are reported the same way, naming the enum
value and the position of its zone in `navigationZones`.

## 1.1.1 - 2026-07-12

### Fixed

Pushing the same route twice no longer crashes the Navigator.

Page keys were derived from the route name and path
(`ValueKey('$name-$path')`), so two entries for the same location on the stack
shared a key and tripped the Navigator's `_debugCheckDuplicatedPageKeys`
assertion. Pages now use go_router's own `state.pageKey`, which is unique per
stack entry (a fresh key for every imperative push, preserved across rebuilds).

Covered by a regression test: pushing `profile` twice must not throw.

## 1.1.0 - 2026-05-22

### ⚠️ Breaking Change

Route enums implementing `DwNavigationRoute` must add the new abstract getter.
The compiler will tell you exactly which enums need it:

```dart
@override
DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
```

---

### Added

- **`statefulShellRouteBuilder`** on `DwNavigationRoute` — wraps the zone in a
  `StatefulShellRoute.indexedStack` where every root route is an independent
  navigation branch. Each branch keeps its own navigator stack, so scroll
  position, sub-routes and widget state survive tab switches. The builder
  receives `StatefulNavigationShell` instead of a plain child widget:
  use `navigationShell.currentIndex` for the active tab index and
  `navigationShell.goBranch(i, initialLocation: ...)` to switch tabs.
  Prefer this over `shellRouteBuilder` for any bottom-navigation-bar layout.

- **`DwGoRouterOptions.onEnter`** (`OnEnter?`, default `null`) — intercepts
  every navigation event before routes are matched. Return `Allow()` to
  proceed, `Block.stop()` to cancel, or `Block.then(cb)` to cancel and run a
  follow-up action (e.g. redirect). Executes before `redirect` and
  `zoneGuards`. Wraps the `OnEnter` API introduced in go_router v14.

- **`DwGoRouterOptions.caseSensitive`** (`bool`, default `true`) — controls
  case-sensitivity for all route paths built by `DwAppRouter`. Set to `false`
  if you need `/Profile` and `/profile` to resolve to the same route.
  Wraps the per-route `caseSensitive` flag introduced in go_router v15.

- **`DwGoRouterOptions.shellNotifyRootObserver`** (`bool`, default `true`) —
  controls whether `ShellRoute` / `StatefulShellRoute` zones fire root
  navigator observer callbacks during inner navigations. Set to `false` to
  suppress them, e.g. when root observers track page views and you don't
  want tab-level nav counted. Wraps `notifyRootObserver` from go_router v14.

### Changed

- `go_router` constraint bumped to `^17.2.3`.
- `flutter_lints` bumped to `^6.0.0`.
- Both bundled examples (`change_notifier_example`, `riverpod_example`)
  migrated from `shellRouteBuilder` to `statefulShellRouteBuilder`.
  Bottom nav tab state is now preserved across switches; the manual
  `rootRouteFromState` index lookup is replaced by `navigationShell.currentIndex`.
- `DwNavigationRoute` member order standardised:
  `descriptor` → `zoneRoot` → `shellRouteBuilder` → `statefulShellRouteBuilder` → `zoneGuards`.
- Both examples now target **web** only (iOS folders removed).

### Fixed

- `DwPageBuilder.slide`: the `from` parameter now correctly describes the
  **entry direction**. `from: AxisDirection.right` now slides the page in from
  the right edge (previously the offset was inverted — pages entered from the
  opposite side).
- `README` example used non-existent `AxisDirection.bottom`; corrected to
  `AxisDirection.down`.

---

## 1.0.1 - 1.0.2

Updated readme, examples and pubspec.yaml for better pub.dev representation.

---

## 1.0.0

Initial public release.
