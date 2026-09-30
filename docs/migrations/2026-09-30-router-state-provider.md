---
title: The router follows a provider; AppRouterState is a record, not a ChangeNotifier
affects:
  dartway_core_flutter: "0.21.0-dev.17"
  dartway_router: "3.0.0"
  dartway_studio_binding: "0.2.1"
---

## Who is affected

Every project: `DwAppRouter` takes the `ref` of the provider that builds it, and `routerState` is a
provider of the value the guards decide by, no longer a `Listenable`. The router listens to it,
re-runs its guards whenever the value changes and disposes itself with its provider. The
`AppRouterState extends ChangeNotifier` every project holds — with its `// dw:allow-stateful`
marker — no longer fits `DwAppRouter`, and `flutter analyze` fails on the router file.

## What to change

**`<project>_flutter/lib/core/router/app_router_state.dart`** — the class becomes a record and the
provider that derives it. The listens it made become watches; the fields become the record's:

    - // dw:allow-stateful DwAppRouter re-runs its guards on a Listenable …
    - class AppRouterState extends ChangeNotifier {
    -   AppRouterState(Ref ref) {
    -     ref.listen<int?>(dw.accountId, (_, accountId) { … notifyListeners(); }, …);
    -     ref.listen<UserRole?>(myProfileProvider.select(…), (_, next) { … }, …);
    -   }
    -   bool isSignedIn = false;
    -   UserRole? role;
    - }
    + typedef AppRouterState = ({bool isSignedIn, UserRole? role});
    +
    + final appRouterStateProvider = Provider<AppRouterState>(
    +   (ref) => (
    +     isSignedIn: ref.watch(dw.accountId) != null,
    +     role: ref.watch(myProfileProvider.select((profile) => profile.value?.role)),
    +   ),
    + );

A project whose state carries more than these two fields gives the record the same fields, each
watched from the provider it used to listen to. Keep it immutable and with value equality — a
record, or a class with `==` — since an equal value re-runs nothing. Drop the
`package:flutter/foundation.dart` import if nothing else uses it.

**`<project>_flutter/lib/core/router/router.dart`** — delete the old `appRouterStateProvider` (it
moved into the file above), and build the router with `ref` and the provider itself:

    - final appRouterStateProvider = Provider<AppRouterState>((ref) {
    -   final state = AppRouterState(ref);
    -   ref.onDispose(state.dispose);
    -   return state;
    - });
    -
      final appRouterProvider = Provider<DwAppRouter<AppRouterState>>((ref) {
    -   final routerState = ref.watch(appRouterStateProvider);
        final router = DwAppRouter<AppRouterState>(
    -     routerState: routerState,
    +     ref: ref,
    +     routerState: appRouterStateProvider,
          …
        );
        …
    -   ref.onDispose(router.router.dispose);
        return router;
      });

The `ref.onDispose(router.router.dispose)` line has to go: the router disposes itself now, and a
second dispose fails in debug — `dartway check` fails it as `routerDisposedByApp`. The zone files and their guards (`state.isSignedIn`, `state.role`)
do not change.

Keep `MaterialApp.router(routerConfig: ref.watch(appRouterProvider).router)` a watch: Riverpod
pauses a provider nobody listens to, and the router stops following its state with it.

A project with `DwStudioBinding` passes `router:` as before.

## How to check

`flutter analyze` in the Flutter package is clean; `grep -rn "router\.dispose" lib/` finds nothing
(`dart run dartway_cli:dartway check` fails a leftover as `routerDisposedByApp`); the check prints no
`🔓 Allowed by dw:allow-stateful` for `AppRouterState`; signing out of the running app returns to the
sign-in screen, and a link into the app opened signed out ends there after signing in.
