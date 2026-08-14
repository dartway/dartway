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
  // Accept only a Studio holding a token signed for this app's own address.
  // Nothing secret is baked in: the key that checks the signature ships with
  // this package, and the build names only where it answers.
  validateAccessToken: studioSignedAccessValidator(
    const String.fromEnvironment('STUDIO_APP_ORIGIN'),
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

## Access control

The `studioConnect` handshake carries an `accessToken`; the host answers with
its manifest only if `validateAccessToken` accepts it. A refusal is answered
with `ConnectRefusedMessage` — but **only when the token was a token**: it has
to parse as a signed Studio token (`looksLikeStudioBridgeToken`) and then fail
the check. An empty, absent or garbled one is met with silence as before, so a
stranger who guessed the preview's URL learns nothing, while a Studio — which
signs correctly by construction — is told that its signature is stale rather
than left guessing whether the app has a bridge at all. A build in the
zero-config mode accepts everyone and so refuses nobody.

The gate covers every command, not just
the manifest — otherwise an embedding page could walk the app through its
screens without presenting anything. It covers the app's own reports too
(`reportRoute`, `reportSession`, `reportLocale`, `reportFeatures`): they are
dropped until a Studio is let in, since whoever connects is handed the whole
state in the handshake response anyway.

The token is short-lived, signed by Studio with an Ed25519 key, and issued for
**one origin**: the address your build answers at. A token lifted off the wire
is worthless anywhere else, and it expires on its own.

```text
<payload>.<signature>
payload   = base64url( utf8( {"origin":"https://app.example","exp":1765540000} ) )
signature = base64url( ed25519_sign( privateKey, ascii(payload) ) )
```

`exp` is whole seconds since the Unix epoch, and the signature covers the
payload *segment as written* — so signer and verifier agree byte for byte
without agreeing on how a map is serialised.

**Your build holds no secret.** The public half of Studio's pair ships in this
package as `studioSigningPublicKey`: a public key checks signatures and cannot
make them, it is the same for every project, and it changes only when you
update the package. There is nothing to copy out of Studio, store, or rotate.
The signature must be asymmetric for exactly this reason — an HMAC over a
shared secret would put that secret back into a public web bundle.

`studioSignedAccessValidator('')` — a build that names no origin — **accepts
any connection**. That is the zero-config local-dev mode: Studio on your laptop
previews your local build without anyone issuing keys. A deployed build names
its address (`--dart-define=STUDIO_APP_ORIGIN=https://app.example`) and from
then on only a signed token gets in.

## Connecting (Studio side)

```dart
final controller = createStudioFrameController(appUrl: 'http://localhost:8091/');
final client = StudioBridgeClient(
  channel: controller.channel,
  // Asked for once per connect attempt, not read once: tokens expire long
  // before a preview is closed, so the supplier caches a live one and issues
  // a fresh one when it runs out.
  accessToken: () => myTokenCache.tokenFor(project),
)..start();
// render: HtmlElementView(viewType: controller.viewType)
client.events.listen(...); // connected / route / session / locale changed
client.requestNavigation('/schedule');
client.requestLocale('ru');
```

The handshake is dual-initiated and survives reloads and hot restarts of either
side. Protocol details live in `StudioBridgeProtocol`.

## Asking one question (Studio side)

Sometimes the question is not "preview this app" but "does this URL answer at
all". `probeStudioBridge` performs a single handshake and returns what came
back:

```dart
final result = await probeStudioBridge(
  appUrl: 'https://feature-x.preview.example.com/',
  accessToken: () => myTokenCache.tokenFor(project),
);
// accepted — the app took the token
// rejected — the app answered and refused it: a stale signature or a foreign key
// silent   — nobody answered inside the timeout
```

The frame is created and removed inside the call: nothing to render, nothing to
hold on to. `StudioFrameController` cannot serve this — it hands out a platform
view, so its iframe is not in the document until the embedder lays it out, and a
detached iframe never fetches its `src`. No layout, no load, no handshake; the
frame has to be *somewhere* on screen for the question to be asked at all. The
probe owns its element instead, in a hidden container outside the widget tree.

`silent` is several answers at once — no bridge in the build, a page that never
loaded, a deployment that refuses to be framed, an older app refusing without a
word. Cross-origin those cannot be told apart from here, and they never will be.
Check that the URL serves a page, and that it permits `frame-ancestors`, as
separate steps before this one.

`runStudioHandshake(channel)` is the same state machine over a channel you
already own — what the probe is with the frame taken out of it.
