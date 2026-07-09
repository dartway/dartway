# DartWay Studio Bridge

The open bridge between a DartWay app and [DartWay Studio](https://dartway.dev):
screen specs declared in the app's code plus a versioned `postMessage` protocol
that lets Studio preview, navigate and drive a running web build of the app.

The app is the single source of truth: Studio receives the manifest (navigation
zones, screen passports, demo personas) over the runtime channel on connect, so
it can never go stale relative to the running build. Credentials never cross
the bridge — persona sign-in runs entirely inside the app.

## Declaring specs (app side)

Passport texts are plain strings — write them in whatever language your team
works in; Studio shows them as is.

```dart
final scheduleSpec = StudioScreenSpec(
  path: '/schedule',
  title: 'Schedule',
  purpose: 'Weekly class timetable...',
  featureSpec: ['Realtime list via DwRepository'],
  discussionQuestions: ['Should slots be bookable here?'],
);

final manifest = StudioProjectManifest(
  projectName: 'My App',
  zones: [
    StudioZoneSpec(
      label: 'Client app',
      rootPath: '/schedule',
      access: StudioZoneAccess.signedIn,
      screens: [scheduleSpec /* ... */],
    ),
    StudioZoneSpec(
      label: 'Admin',
      rootPath: '/admin',
      access: StudioZoneAccess.signedIn,
      // Role-gated zone: Studio switches to a listed persona before entering.
      allowedPersonaIds: ['admin'],
      screens: [/* ... */],
    ),
  ],
  personas: [
    StudioPersonaSpec(id: 'client', label: 'Client · Ivan', identifier: '7999...'),
  ],
  // Declare two or more locales to get a locale switcher in Studio; the app
  // executes the switch itself via StudioBridgeHostDelegate.onLocaleRequest.
  supportedLocales: ['en', 'ru'],
);
```

## Attaching the host (app side)

```dart
final host = StudioBridgeHost.attach(
  manifest: manifest,
  delegate: myDelegate, // navigate / persona sign-in / sign-out / locale executors
  currentPath: () => router.currentPath,
  currentSession: () => mySessionState,
  currentLocale: () => myLocale.languageCode, // omit if not localized
);
host?.reportRoute(newPath);     // on router changes
host?.reportSession(newState);  // on auth changes
host?.reportLocale(newLocale);  // on locale changes
```

`attach` returns null when the app is not running on web inside an iframe, or
when a release build has no explicit `allowedStudioOrigins` — the app stays
fully functional and the bridge dormant (secure by default).

## Connecting (Studio side)

```dart
final controller = createStudioFrameController(appUrl: 'http://localhost:8091/');
final client = StudioBridgeClient(channel: controller.channel)..start();
// render: HtmlElementView(viewType: controller.viewType)
client.events.listen(...); // connected / route / session / locale changed
client.requestNavigation('/schedule');
client.requestLocale('ru');
```

The handshake is dual-initiated and survives reloads and hot restarts of either
side. Protocol details live in `StudioBridgeProtocol`.
