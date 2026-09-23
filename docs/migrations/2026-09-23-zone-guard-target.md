---
title: A zone guard takes the navigation target as its second argument
affects:
  dartway_core_flutter: "0.20.0-dev.3"
  dartway_router: "2.0.0"
---

## Who is affected

Every project: each zone declares `zoneGuards`, and `DwNavigationGuard` now takes two arguments —
the router state, as before, and the `DwNavigationTarget` being entered. A guard written with one
parameter no longer compiles.

## What to change

In every `*_navigation_zone.dart`, give each guard the second parameter. Where the guard does not
need it:

    - (state) => state.isSignedIn ? null : AuthNavigationZone.auth.fullPath,
    + (state, _) => state.isSignedIn ? null : AuthNavigationZone.auth.fullPath,

## Optional: back to the link after signing in

What the parameter is for. The skeleton's gates now do this; to do the same, send a signed-out
person to sign-in with where they were going, and send them on once signed in.
`<project>_flutter/lib/core/router/navigation_zones/auth_navigation_zone.dart`:

    List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
      (state, target) => state.isSignedIn
          ? _returnTo(target) ?? AppNavigationZone.home.fullPath
          : null,
    ];

    static String signInFrom(DwNavigationTarget target) => Uri(
      path: auth.fullPath,
      queryParameters: target.location == '/' ? null : {'from': target.location},
    ).toString();

    static String? _returnTo(DwNavigationTarget target) {
      final from = target.uri.queryParameters['from'];
      final ownPath = from != null && from.startsWith('/') && !from.startsWith('//');
      return ownPath ? from : null;
    }

and in the zones behind the gate:

    - (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
    + (state, target) =>
    +     state.isSignedIn ? null : AuthNavigationZone.signInFrom(target),

A sign-in screen that navigates somewhere itself after signing in would override this; the
skeleton's does not, and lets the guard decide.

## How to check

`flutter analyze` in the Flutter package: no `list_element_type_not_assignable` on `zoneGuards`.
