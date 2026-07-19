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
      // Role-gating is the app's own job — router guard and server filters.
      // The spec only tells Studio a signed-in session is needed at all.
      screens: [dashboardSpec],
    ),
  ],
  supportedLocales: const ['en', 'ru'],
);
```

Note what is **not** declared: demo personas. Test users and their codes are a
platform concern — they live in Studio's project config, so your public web
build ships no test accounts.

The host side connects the running web build to Studio. It returns `null` when there is nothing to
attach to — not web, not embedded, or the origin is not permitted — and the app carries on exactly
as before:

```dart
final host = StudioBridgeHost.attach(
  manifest: manifest,
  delegate: this, // implements StudioBridgeHostDelegate: navigate, sign in, set locale
  currentPath: () => router.currentPath,
  currentSession: () => StudioSessionState(
    isSignedIn: session.isSignedIn,
    userIdentifier: session.phone, // Studio matches it to its personas
  ),
  currentLocale: () => locale.languageCode,
);
```

The channel pins the origin of the first valid Studio message and replies only there. An origin
allowlist existed in 0.1.0 and was removed for now: zero-config local work first; an embedding page
can only drive what the bridge exposes (navigation, test sign-in), and an explicit opt-in policy
can return later.

Studio receives the manifest over the runtime channel on connect, so it can never go stale against
the build it is previewing. Persona sign-in is `onSignInRequest(identifier, secret)`:
Studio sends the credentials from its config, and the app runs its **regular** auth flow with them
— exactly as if the user typed the code (DartWay server side: per-user rotatable
`testVerificationCode`). No special sign-in path ships in the app.

The canonical wiring is `example/dartway_example_flutter/lib/studio/` in the
[DartWay monorepo](https://github.com/dartway/dartway).
