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
  case-sensitivity for all route paths built by `DwRouter`. Set to `false`
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
