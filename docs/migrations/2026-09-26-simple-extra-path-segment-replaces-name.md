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

**Every descendant of such a route moves too, not only the route itself.** `fullPath` is built
from the parent chain — a route's own segment appended to its parent's `fullPath` — so a child
declared under the affected route inherits the new, shorter address automatically:

- a plain child `x` of `planPreferences` (`extraPathSegment: 'plan'`) moved from
  `/…/plan/planPreferences/x` to `/…/plan/x`;
- a parameterized child moved the same way — `/…/plan/planPreferences/:id` is now `/…/plan/:id`,
  the id itself untouched.

Nothing has to change in the child's own declaration; its `fullPath` is simply different now,
which is exactly what everything below needs to account for.

A `.parameterized()` route with `extraPathSegment` is unchanged: it still prefixes the parameter
pattern (`extraPathSegment: 'users'` still builds `users/:userId`), so no edit is needed there,
and nothing under it moves either.

## What to change

Nothing in the route declarations — the new URLs are the ones the feature was for; `editProfile`'s
descriptor keeps `extraPathSegment: 'edit'` and now correctly resolves to `/profile/edit`, with
its own descendants following.

Anything holding an **old** URL by value has to be updated or given a redirect:

- a stored or bookmarked path (server-sent push payload, saved deep link, analytics event) built
  from the doubled route or from one of its descendants;
- a tool that keys anything by screen path outside the router itself — for example, a Studio-style
  binding that reports the current screen by `route.fullPath` for a remote panel or analytics: its
  reported path for every affected route and descendant changes too, and anything that stores or
  matches on that string (a saved "last screen", a panel bookmark) needs the same update;
- a test that asserts on the literal path string (`find.text`, a route-path expectation, an
  end-to-end test's URL check).

**Redirect old links by prefix, not by exact match** — an exact-match table only handles the
routes named directly, and misses every descendant. Rewrite the common *prefix* instead and keep
whatever followed it, so a child's segment or a parameterized child's id travels through
untouched:

    DwGoRouterOptions(
      redirect: (context, state) {
        // Old prefix -> new prefix, for every route whose extraPathSegment
        // changed its own address. The old prefix is BOTH segments the bug
        // built (extraPathSegment, then the enum name) — not just the enum
        // name. List the route itself; descendants are handled by the
        // "starts with" check below, not by listing them too.
        const renamedPrefixes = <String, String>{
          '/profile/edit/editProfile': '/profile/edit',
          '/profile/plan/planPreferences': '/profile/plan',
          // ...every other route in "Who is affected" whose old and new
          // segment differ; a route whose extraPathSegment happens to equal
          // an existing distinct word doesn't need an entry.
        };
        final path = state.uri.path;
        for (final entry in renamedPrefixes.entries) {
          if (path == entry.key || path.startsWith('${entry.key}/')) {
            final rest = path.substring(entry.key.length); // '' or '/…'
            return state.uri.replace(path: '${entry.value}$rest').toString();
          }
        }
        return null;
      },
    )

This is a small, one-time rewrite rule — not a new redirect system — built entirely from
`DwGoRouterOptions.redirect`, which `DwAppRouter` already wires in.

**`DwGoRouterOptions.redirect` runs *after* zone guards are checked for the currently matched
route, not ahead of them** (`dw_app_router.dart`: guards are checked first, `options.redirect` is
called last). An old URL matches no declared route, so no guard runs on that first pass and this
rewrite applies; GoRouter then re-evaluates the redirect chain at the freshly rewritten address,
where it **is** a declared route — so if that route sits behind a zone guard, the guard runs next,
exactly as it would for anyone navigating there directly. Consequence: an old link into a route
that is (or has since become) guarded does not bypass the guard — a signed-out visitor following
an old link lands wherever the guard sends them (e.g. sign-in), not straight at the rewritten
page. If the guard's own redirect needs to send them on afterwards, it should compute that from
the now-rewritten target, not from the old address.

## How to check

`flutter analyze` needs no code change. To catch every moved path, including descendants, print
every route's `fullPath` from the project's own `navigationZones` and diff the list against the
one from before this upgrade (the previous `dartway_router` lock, or a copy saved before running
`dartway update`):

    test('every route\'s fullPath, to diff against the pre-upgrade list', () {
      for (final zone in navigationZones) {
        for (final route in zone) {
          // ignore: avoid_print
          print('${route.runtimeType}.${route.name}\t${route.fullPath}');
        }
      }
    });

Any line whose path differs from the saved list is a route this migration touched — directly, if
it is one of the routes named in "Who is affected", or as a descendant otherwise. Confirm each one
is covered by the redirect above, or does not need to be.
