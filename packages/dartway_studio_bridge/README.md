# DartWay Studio Bridge

The open bridge between a DartWay app and [DartWay Studio](https://dartway.dev):
screen specs declared in the app's code plus a versioned `postMessage` protocol
that lets Studio preview, navigate and drive a running web build of the app.

The app is the single source of truth for its structure: Studio receives the
manifest (navigation zones, screen passports, supported locales) over the
runtime channel on connect, so it can never go stale relative to the running
build. Demo personas are the opposite — a platform concern: test users and
their codes are configured in Studio and never ship inside the app's public
web build. Studio signs in by sending the credentials to the app, which runs
its regular auth flow with them.

## Declaring specs (app side)

Passport texts are plain strings — write them in whatever language your team
works in; Studio shows them as is.

```dart
final scheduleSpec = StudioScreenSpec(
  path: '/schedule',
  title: 'Schedule',
  purpose: 'Weekly class timetable...',
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
      // Role-gating is the app's own job (router guards, server filters) —
      // the zone spec only says a session is needed at all.
      screens: [/* ... */],
    ),
  ],
  // Left empty on purpose: a running app cannot enumerate its own features —
  // Dart has no reflection, so only the mounted ones are observable, and those
  // are reported per screen (see `reportFeatures` below). The whole-project
  // catalog is a job for static analysis of the sources.
  features: const [],
  // Declare two or more locales to get a locale switcher in Studio; the app
  // executes the switch itself via StudioBridgeHostDelegate.onLocaleRequest.
  supportedLocales: ['en', 'ru'],
);
```

## Attaching the host (app side)

```dart
final host = StudioBridgeHost.attach(
  manifest: manifest,
  delegate: myDelegate, // navigate / sign-in with credentials / sign-out / locale
  currentPath: () => router.currentPath,
  currentSession: () => mySessionState,
  currentFeatures: mountedFeatureInfos, // the features on screen right now
  currentLocale: () => myLocale.languageCode, // omit if not localized
  // Accept only a Studio that presents this project's secret. The build bakes
  // only the secret's HASH; the secret itself stays in Studio.
  validateAccessKey: studioHashAccessValidator(
    const String.fromEnvironment('STUDIO_KEY_HASH'),
  ),
  inspectPoint: featureAtPoint, // what is declared at a point (see below)
);
host?.reportRoute(newPath, routeName: 'scheduleList'); // on router changes
host?.reportSession(newState);  // on auth changes
host?.reportLocale(newLocale);  // on locale changes
host?.reportFeatures(newPath, mountedFeatureInfos()); // after the frame settles
```

## Reporting features

A feature says what it is next to its own code, and the app reports the ones
currently on screen — so what Studio shows is what the running build actually
does, with nothing stored on the Studio side that could drift away from it.

The bridge does not care how the app finds its features. DartWay apps let each
widget declare a `DwFeatureSpec` (package `dartway_flutter`) and collect the
mounted ones:

```dart
List<StudioFeatureInfo> mountedFeatureInfos() => [
      for (final feature in DwFeature.scanMounted())
        StudioFeatureInfo(
          id: feature.id,                 // 'schedule/session-list' — a contract; never renamed in place
          title: feature.title,
          purpose: feature.purpose,       // why it exists for the user; null for a part that serves a screen
          behaviors: feature.behaviors,   // what it observably does, one checkable statement per entry
          requirements: feature.requirements,
          implementationNotes: feature.implementationNotes,
          knownIssues: feature.knownIssues,   // what is wrong here and worth taking into work
        ),
    ];
```

`title`, `purpose` and `behaviors` are what a client reads; `requirements`,
`implementationNotes` and `knownIssues` are written for the team, and Studio
shows them apart. A feature with a non-empty `knownIssues` is flagged in the
catalog, so open questions are visible without reading every passport.

Report after the new screen has built — a route change fires before its widgets
mount, so reporting in the same turn describes the screen you just left. See
`example/dartway_example_flutter/lib/core/studio/studio_bridge_binding.dart` for the
reference binding.

## Inspecting a point (the "pencil" flow)

Studio can also ask the other question — not "what is on this screen" but "what
is *here*", from a tap in the live preview:

```dart
final feature = await client.inspectPoint(0.42, 0.65); // Studio side
```

The point travels as **fractions** of the app's viewport (0.0 top/left, 1.0
bottom/right), never pixels: Studio shows the preview scaled, framed or
letterboxed, and only the app knows its own logical size. The app converts once,
on its side:

```dart
StudioFeatureInfo? featureAtPoint(double horizontal, double vertical) {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  final feature = DwFeature.hitTest(
    Offset(horizontal * size.width, vertical * size.height),
  );
  return feature == null ? null : toWireModel(feature);
}
```

Each request carries an id the app echoes back, so a second tap sent while a
slow first one is still being answered gets its own answer instead of the
previous one's. An app that predates the message stays silent and the caller's
timeout reports "nothing here" — a miss, never a hang.

`attach` returns null when the app is not running on web inside an iframe —
the app stays fully functional and the bridge dormant. The channel pins the
origin of the first valid Studio message for its replies.

**Access control.** The `studioConnect` handshake carries an `accessKey`; the
host answers with its manifest only if `validateAccessKey` accepts it,
otherwise it stays silent (Studio shows "not connected"). The bridge is
agnostic to *how* you check — the shipped `studioHashAccessValidator(hash)`
keeps the secret out of the public build: Studio holds a per-project random
secret, the app bakes only its hash (`studioAccessKeyHash`, hex SHA-256) and
compares. An empty expected hash accepts any key (zero-config local dev).

## Connecting (Studio side)

```dart
final controller = createStudioFrameController(appUrl: 'http://localhost:8091/');
final client = StudioBridgeClient(
  channel: controller.channel,
  accessKey: project.accessSecret, // the raw secret; the app checks its hash
)..start();
// render: HtmlElementView(viewType: controller.viewType)
client.events.listen(...); // connected / route / session / locale changed
client.requestNavigation('/schedule');
client.requestLocale('ru');
```

The handshake is dual-initiated and survives reloads and hot restarts of either
side. Protocol details live in `StudioBridgeProtocol`.
