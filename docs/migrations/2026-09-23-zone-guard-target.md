---
title: A zone guard takes the navigation target as its second argument
affects:
  dartway_core_flutter: "0.20.0-dev.3"
  dartway_router: "2.0.0"
---

## Who is affected

Every project: each zone declares `zoneGuards`, and the zone guard callback now takes two arguments —
the router state, as before, and the `DwNavigationTarget` being entered. A guard written with one
parameter no longer compiles.

## What to change

In every `*_navigation_zone.dart`, give each guard the second parameter. Where the guard does not
need it:

    - (state) => state.isSignedIn
    + (state, _) => state.isSignedIn
          ? DwGuardDecision.allow
          : DwGuardDecision.redirect(AuthNavigationZone.auth.fullPath),

The examples use the current decision contract. For the result-type migration, see
[Pending navigation guards](2026-10-11-pending-navigation-guards.md).

## Optional: back to the link after signing in

What the parameter is for. The skeleton's gates now do this; to do the same, send a signed-out
person to sign-in with where they were going, and send them on once signed in.
`<project>_flutter/lib/core/router/navigation_zones/auth_navigation_zone.dart`:

    List<DwDecisionGuard<AppRouterState>> get zoneGuards => [
      (state, target) => state.isSignedIn
          ? DwGuardDecision.redirect(_returnTo(target))
          : DwGuardDecision.allow,
    ];

    static String signInFrom(DwNavigationTarget target) => Uri(
      path: auth.fullPath,
      queryParameters: target.location == '/' ? {} : {'from': target.location},
    ).toString();

    static String _returnTo(DwNavigationTarget target) {
      final from = target.uri.queryParameters['from'] ?? '';
      final ownPath = from.startsWith('/') && !from.startsWith('//');
      return ownPath ? from : AppNavigationZone.home.fullPath;
    }

and in the zones behind the gate:

    - (state) => state.isSignedIn
    -     ? DwGuardDecision.allow
    -     : DwGuardDecision.redirect(AuthNavigationZone.auth.fullPath),
    + (state, target) => state.isSignedIn
    +     ? DwGuardDecision.allow
    +     : DwGuardDecision.redirect(AuthNavigationZone.signInFrom(target)),

A sign-in screen that navigates somewhere itself after signing in would override this; the
skeleton's does not, and lets the guard decide.

## How to check

`flutter analyze` in the Flutter package: no `list_element_type_not_assignable` on `zoneGuards`.
