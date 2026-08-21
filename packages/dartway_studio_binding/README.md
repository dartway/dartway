# dartway_studio_binding

The app half of the [DartWay Studio](https://dartway.dev) wiring: one widget
that connects a Flutter app to Studio's live preview.

`dartway_studio_bridge` is the wire — the protocol both sides depend on. This
package is the side that speaks it: it attaches the host, reports the route, the
features mounted on screen, the session and the language, and executes what
Studio asks for.

## Why it is a package

None of this refers to any domain. It is protocol wiring nobody edits, and it
used to be scaffolded into every project by copy-paste — a binding widget, a
persona sign-in flow, a session adapter and a route adapter. That drifts: the
guard that stops an empty passport flashing in Studio between screens once lived
in one copy and was missing from the other, and neither copy knew the other
existed.

It is not part of the core, because the screen identity Studio binds to is the
route's declared name — a `dartway_router` concept, and a dependency that has no
business on apps that never open Studio. It is not part of the bridge either:
the bridge's version means the wire, and host-side changes bumping it would turn
"the bridge changed, catch up" into noise.

## Use

Mount it in `MaterialApp.builder` — outside the router subtree, so the route is
observed through the router delegate rather than a `GoRouterState` that only
exists below the router.

```dart
MaterialApp.router(
  routerConfig: router.router,
  builder: (context, child) => DwStudioBinding(
    core: dw,
    manifest: appStudioManifest,
    router: ref.watch(appRouterProvider),
    describeUser: (profile) =>
        DwStudioUser(identifier: profile.phone, label: profile.firstName),
    locale: DwStudioLocale(
      provider: appLocaleProvider,
      select: (code) =>
          ref.read(appLocaleProvider.notifier).selectLanguageCode(code),
    ),
    validateAccessToken: studioSignedAccessValidator(
      const String.fromEnvironment('STUDIO_APP_ORIGIN'),
    ),
    child: child ?? const SizedBox.shrink(),
  ),
);
```

The widget renders `child` untouched and stays inert outside an iframe, so a
production build carries it at no cost and needs no flag to turn it off.

## What the project still supplies

Four things, because the framework cannot know them:

| | |
|---|---|
| `manifest` | What the app declares about itself: its zones and their screens |
| `describeUser` | Which profile field is the identity Studio matches its personas against, and which one names the user on screen |
| `locale` | The app's own language provider and switcher — omit it and Studio's language switcher stays inert, which is right for an app that ships one language |
| `validateAccessToken` | Who may drive this app. Pass `studioSignedAccessValidator(...)`; left null, any Studio is accepted — right on a laptop, wide open in production |

Screen passports stay in the project too. Build them from routes rather than
from path strings, so a path refactor cannot leave a passport pointing at a
screen that no longer exists:

```dart
final scheduleStudioSpec = dwStudioSpecForRoute(
  AppNavigationZone.schedule,
  title: 'Schedule',
  purpose: 'What is on this week.',
);
```

## Features

A widget that *is* a product feature implements `DwFeature` and declares its
`DwFeatureSpec` next to itself. The binding reports the ones currently mounted,
re-scanning over a short window after each route change — a screen is not on
screen at the moment the route naming it changes.

Only the last re-scan may report an empty screen. An early one often lands
between screens and finds nothing; that is "not ready yet", not "has no
features", and Studio takes these reports at face value.
