---
title: Navigation guards wait for unknown facts
affects:
  dartway_router: "4.0.0-dev.0"
---

## Who is affected

Every project declaring zone guards. The String? guard contract is replaced by
`DwDecisionGuard`; each guard now returns `DwGuardDecision.allow`,
`DwGuardDecision.redirect(path)`, or `DwGuardDecision.pending`.

## What to change

Declare `zoneGuards` as `List<DwDecisionGuard<AppRouterState>>`. Map the old
answers as follows: `null` becomes `DwGuardDecision.allow`, and a path becomes
`DwGuardDecision.redirect(path)`. A field that can be unknown must be nullable
in the router-state record; handle null explicitly with
`DwGuardDecision.pending`.

Supply the app's one loading page as `DwGoRouterOptions.pendingBuilder` when any
guard can return pending. Without it, a pending answer fails with a diagnostic.
Keep the router-state provider immutable and the router provider watched: its
existing refresh subscription re-runs the decisions as facts arrive.

For unknown-field checks, use `dwCheckPendingGuards` from
`package:dartway_router/testing.dart`: pass every zone, representative known
states (including redirecting values), and a setter for each nullable field that
replaces it with null. Supply concrete targets for guards reading parameters or
query values.

## How to check

Run analyze and the guard tests. In a widget regression, hold the session or
profile fact unknown, assert only the pending page is shown and the target's
build counter is zero, then supply the fact and assert the allowed page or
redirect. The pending URL must stay unchanged and add no history entry.
