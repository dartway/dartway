# Example — a screen that explains itself

A screen passport lives in code, next to the screen it describes. That is the whole point: a
document in a wiki drifts from the app the day after it is written; this one cannot, because it
ships with the build.

```dart
final homeSpec = StudioScreenSpec(
  path: '/',
  title: 'Home',
  purpose: 'The first thing a signed-in user sees. Business goal: make the '
      'next action obvious in under a second.',
  featureSpec: [
    'Live list via watchModelList — realtime, typed, no endpoint.',
    'The greeting reads the profile from the session, not from a fetch.',
  ],
  discussionQuestions: [
    'Should the empty state sell the feature, or get out of the way?',
  ],
);
```

Group the screens into zones and declare the app once:

```dart
final manifest = StudioProjectManifest(
  projectName: 'My App',
  zones: [
    StudioZoneSpec(
      label: 'App',
      rootPath: '/',
      access: StudioZoneAccess.signedIn,
      screens: [homeSpec, profileSpec],
    ),
    StudioZoneSpec(
      label: 'Admin',
      rootPath: '/admin',
      access: StudioZoneAccess.signedIn,
      // Studio switches to a listed persona before entering a gated zone. The
      // router guard and the server filters remain the real protection.
      allowedPersonaIds: ['admin-alex'],
      screens: [dashboardSpec],
    ),
  ],
  personas: [
    StudioPersonaSpec(
      id: 'admin-alex',
      label: 'Admin · Alex',
      identifier: '79990000001',
    ),
  ],
  supportedLocales: const ['en', 'ru'],
);
```

The host side connects the running web build to Studio. It returns `null` when there is nothing to
attach to — not web, not embedded, or the origin is not permitted — and the app carries on exactly
as before:

```dart
final host = StudioBridgeHost.attach(
  manifest: manifest,
  delegate: this, // implements StudioBridgeHostDelegate: navigate, switch persona, set locale
  currentPath: () => router.currentPath,
  currentSession: () => StudioSessionState(
    isSignedIn: session.isSignedIn,
    activePersonaId: session.personaId,
  ),
  currentLocale: () => locale.languageCode,
  allowedStudioOrigins: const ['https://dartway.studio'],
);
```

`allowedStudioOrigins` is the security model of the bridge. **In a release build an empty allowlist
means no Studio may connect at all** — you opt in to a Studio origin, you never forget to opt out.
In debug the channel stays permissive, so a local Studio works without ceremony.

Studio receives the manifest over the runtime channel on connect, so it can never go stale against
the build it is previewing. **Credentials never cross the bridge** — persona sign-in happens inside
the app, through the app's own auth.

The canonical wiring is `example/dartway_example_flutter/lib/studio/` in the
[DartWay monorepo](https://github.com/dartway/dartway).
