# DartWay Studio Bridge

The open bridge between a DartWay app and [DartWay Studio](https://dartway.dev):
screen specs declared in the app's code plus a versioned `postMessage` protocol
that lets Studio preview, navigate and drive a running web build of the app.

The app is the single source of truth: Studio receives the manifest (navigation
zones, screen passports, demo personas) over the runtime channel on connect, so
it can never go stale relative to the running build. Credentials never cross
the bridge — persona sign-in runs entirely inside the app.

## Declaring specs (app side)

```dart
final scheduleSpec = StudioScreenSpec(
  path: '/schedule',
  title: StudioText('Schedule', 'Расписание'),
  purpose: StudioText('Weekly class timetable...', 'Расписание занятий...'),
  featureSpec: [StudioText('Realtime list via DwRepository', '...')],
  discussionQuestions: [StudioText('Should slots be bookable here?', '...')],
);

final manifest = StudioProjectManifest(
  projectName: 'My App',
  zones: [
    StudioZoneSpec(
      label: StudioText('Client app', 'Приложение клиента'),
      rootPath: '/schedule',
      access: StudioZoneAccess.signedIn,
      screens: [scheduleSpec /* ... */],
    ),
  ],
  personas: [
    StudioPersonaSpec(id: 'client', label: 'Client · Ivan', identifier: '7999...'),
  ],
);
```

## Attaching the host (app side)

```dart
final host = StudioBridgeHost.attach(
  manifest: manifest,
  delegate: myDelegate, // navigate / persona sign-in / sign-out executors
  currentPath: () => router.currentPath,
  currentSession: () => mySessionState,
);
host?.reportRoute(newPath);     // on router changes
host?.reportSession(newState);  // on auth changes
```

`attach` returns null when the app is not running on web inside an iframe, or
when a release build has no explicit `allowedStudioOrigins` — the app stays
fully functional and the bridge dormant (secure by default).

## Connecting (Studio side)

```dart
final controller = createStudioFrameController(appUrl: 'http://localhost:8090/');
final client = StudioBridgeClient(channel: controller.channel)..start();
// render: HtmlElementView(viewType: controller.viewType)
client.events.listen(...); // connected / route changed / session changed
client.requestNavigation('/schedule');
```

The handshake is dual-initiated and survives reloads and hot restarts of either
side. Protocol details live in `StudioBridgeProtocol`.
