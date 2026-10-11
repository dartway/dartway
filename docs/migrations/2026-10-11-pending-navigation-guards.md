---
title: Rewrite navigation guards as decisions
affects:
  dartway_router: "4.0.0-dev.0"
---

## Who is affected

Every project with a `DwNavigationRoute.zoneGuards` declaration. The router now
requires `List<DwDecisionGuard<RouterState>>`; the former nullable-string guard
type and adapter were removed.

## What to change

Change each guard list to `List<DwDecisionGuard<AppRouterState>>`, then rewrite
every answer explicitly:

```dart
// Before
return '/login';
return null;

// After
return DwGuardDecision.redirect('/login');
return DwGuardDecision.allow;
```

When a fact is not loaded yet, return `DwGuardDecision.pending` instead of
allowing the route. Supply the app's loading page as
`DwGoRouterOptions.pendingBuilder` whenever a guard can return pending.

## How to check

Run `flutter analyze` and the navigation tests. Use `dwCheckPendingGuards` from
`package:dartway_router/testing.dart` to verify that each nullable router-state
field produces pending rather than allow while it is unknown.
