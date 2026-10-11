---
title: Navigation guards wait for unknown facts
affects:
  dartway_router: "3.1.0-dev.0"
---

## Who is affected

Projects adopting pending decisions, and code that inspects guards through
`DwNavigationRoute.zoneGuards`. Existing zone declarations returning String?
still compile through the deprecated `DwNavigationGuard` adapter: null means
allow. They do not wait for unknown facts. Projects with `dart analyze --fatal-infos`
must adopt decision guards or acknowledge the legacy declaration's deprecation.

The route interface now accepts both legacy and decision callbacks. A caller
that explicitly stores an interface callback's answer as String? must handle
both return contracts instead of narrowing the answer to String?. Typed getters
on an application's own zone keep their declared return type.

## What to change

When adopting pending decisions, declare the zone's guard list as
`List<DwDecisionGuard<AppRouterState>>`. Replace null with `DwGuardDecision.allow`
only where the facts are known, and paths with `DwGuardDecision.redirect(path)`.
A field that can be unknown must be nullable in the router-state record; handle
null explicitly with `DwGuardDecision.pending`.

Supply the app's one loading page as `DwGoRouterOptions.pendingBuilder` when any
guard can return pending. Without it, a pending answer fails with a diagnostic.
Keep the router-state provider immutable and the router provider watched: its
existing refresh subscription re-runs the decisions as facts arrive.

If the project keeps legacy guards temporarily, retain the strict analysis gate
and add a targeted `// ignore: deprecated_member_use` at each old guard-list
declaration. Remove those acknowledgements when adopting decision guards.

Tests inspecting guards through the shared route interface must account for
`DwGuardDecision` as well as the legacy String? answer. For unknown-field checks,
use `dwCheckPendingGuards` from `package:dartway_router/testing.dart`: pass every
zone, representative known states (including redirecting values), and a setter
for each nullable field that replaces it with null. Supply concrete targets for
guards reading parameters or query values.

## How to check

Run analyze and the guard tests. In a widget regression, hold the session or
profile fact unknown, assert only the pending page is shown and the target's
build counter is zero, then supply the fact and assert the allowed page or
redirect. The pending URL must stay unchanged and add no history entry.
