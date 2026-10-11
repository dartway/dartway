# How does a guard wait for facts it does not know yet?

Signing in can finish before the profile arrives. A guard that reads an unknown
role as permission to proceed builds the destination, then redirects once the
profile loads. That produces a frame of a page the person should never have seen.

`DwDecisionGuard` returns `DwGuardDecision.allow`, `.redirect(path)` or `.pending`.
Unknown router-state fields are nullable; a guard reading one handles null explicitly
with pending. The example's admin zone waits for the role:

```dart
(state, _) => switch (state.role) {
  null => DwGuardDecision.pending,
  UserRole.admin => DwGuardDecision.allow,
  _ => DwGuardDecision.redirect(AppNavigationZone.schedule.fullPath),
},
```

This is in `example/dartway_example_flutter/lib/core/router/navigation_zones/admin_navigation_zone.dart`.
The preceding sign-in guard redirects a signed-out person before checking the role.
Guards decide in order; allow continues, redirect or pending ends that evaluation.

The app supplies one loading page through `DwGoRouterOptions.pendingBuilder`.
While pending, the router builds that page in place of the target and the zone's
shell chrome. A shell's Navigator remains mounted offstage, so system Back keeps
go_router's normal pop behaviour. The URL stays the same, no extra history entry
appears, and the target's widget never builds. When the router-state provider
changes, guards run again and the allowed page or redirect replaces loading. A
pending answer without a loading builder fails with an error naming the missing
option.

A test can import `package:dartway_router/testing.dart` and call
`dwCheckPendingGuards` with all zones, representative known states and a setter for
every nullable field. Each setter returns the state with that field null; Dart
records cannot enumerate fields at runtime. The helper fails if a guard allows an
unknown value where the corresponding known value redirects. Supply concrete
`targets` for parameterized or query-sensitive guards. A widget regression checks
that the destination's build counter stays zero through loading and redirect.
