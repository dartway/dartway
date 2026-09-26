---
title: A simple route's extraPathSegment replaces its name, not prefixes it
affects:
  dartway_router: "3.0.0"
---

## Who is affected

A project with a `.simple()` route descriptor that sets `extraPathSegment` — for example
`editProfile(DwNavigationRouteDescriptor.simple(parent: profile, extraPathSegment: 'edit'))`.
Its URL used to be `/profile/edit/editProfile` (the enum name doubled onto the prefix); it is now
`/profile/edit` (dartway/dartway#314).

A `.parameterized()` route with `extraPathSegment` is unchanged: it still prefixes the parameter
pattern (`extraPathSegment: 'users'` still builds `users/:userId`), so no edit is needed there.

## What to change

Nothing in the route declaration — the new URL is the one the feature was for; `editProfile`'s
descriptor keeps `extraPathSegment: 'edit'` and now correctly resolves to `/profile/edit`.

Anything holding the **old** URL by value has to be updated or given a redirect:

- a stored or bookmarked path (server-sent push payload, saved deep link, analytics event) built
  from the doubled route;
- a test that asserts on the literal path string (`find.text`, a route-path expectation, an
  end-to-end test's URL check).

To keep an old link working rather than editing every place that stored one, add a redirect in
`DwGoRouterOptions.redirect` (already wired into `DwAppRouter`, ahead of zone guards) that maps the
old doubled path to the route's `fullPath`:

    DwGoRouterOptions(
      redirect: (context, state) {
        const old = <String, String>{
          '/profile/edit/editProfile': '/profile/edit',
          // ...every affected route, once.
        };
        return old[state.uri.path];
      },
    )

## How to check

`flutter analyze` (no code changes needed) and, for every simple route using `extraPathSegment`,
confirm its `.fullPath` in a router test no longer repeats the route's enum name.
