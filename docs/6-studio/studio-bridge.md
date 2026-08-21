# DartWay Studio Bridge

Every DartWay app can describe itself for [DartWay Studio](https://dartway.dev)
— the closed platform that shows a live preview of your running app with a
screen map, screen passports and a demo-persona switcher.

The open `dartway_studio_bridge` package is the only integration surface:

- **Spec models** — declare navigation zones and screen passports
  (`StudioScreenSpec`, plain single-language strings — written in whatever
  language your team works in) in your app's code. Screens are identified by
  route path strings, so any router works.
- **Runtime protocol** — a versioned `postMessage` protocol between Studio and
  the app's web build running in an iframe: Studio navigates the live app,
  switches its UI locale (when the manifest declares `supportedLocales`) and
  asks what is declared at a point on screen; the app reports route, session
  and locale changes.
- **Demo personas are configured in Studio, not in the app.** Test users and
  their verification codes live in the platform's project config; on switch
  Studio sends them over the bridge and the app runs its **regular** auth flow
  with them (DartWay server side: per-user rotatable `testVerificationCode`).
  A public web build therefore ships no test accounts and no special sign-in
  path. Role-gating of zones stays entirely in the app — guards and server
  filters, not spec metadata.
- **`DwStudioBinding`** — the app half, and the thing a Flutter project actually
  mounts. It ships as its own package, `dartway_studio_binding`: one widget in
  `MaterialApp.builder` that attaches the host, reports the route, the mounted
  features, the session and the language, and runs what Studio asks for. The
  project supplies only what the framework cannot know — the manifest, the
  screen passports, and which profile field names the signed-in user:

  ```dart
  builder: (context, child) => DwStudioBinding(
    core: dw,
    manifest: appStudioManifest,
    router: ref.watch(appRouterProvider),
    describeUser: (profile) =>
        DwStudioUser(identifier: profile.phone, label: profile.firstName),
    validateAccessToken: studioSignedAccessValidator(
      const String.fromEnvironment('STUDIO_APP_ORIGIN'),
    ),
    child: child ?? const SizedBox.shrink(),
  ),
  ```

  It is a package rather than something a project copies because none of it
  refers to any domain — it is protocol wiring nobody edits, and while it
  travelled by copy-paste the two copies in this repository had already drifted
  apart. Build on `StudioBridgeHost.attach` directly when an app needs a report
  cadence of its own. Either way the host is inert unless the app runs on web
  embedded in an iframe; the channel pins the origin of the first valid Studio
  message for its replies.
- **Access is proved by a signature.** Studio presents a short-lived token,
  signed with its own Ed25519 key and issued for a single origin — the address
  your build answers at — and the app accepts the connection only if that token
  passes its `validateAccessToken`. A token taken off the wire is therefore
  useless anywhere else, and it expires on its own.

  The gate is on **everything**, not on the manifest alone: until a token has
  been accepted the app runs no command it is sent and reports nothing back, so
  a page that embedded the build without presenting anything can neither drive
  it nor read its feature passports.

  **A refusal is answered, once it is a refusal of something.** If the token
  presented parses as a signed Studio token and then fails the check — expired,
  or signed by another key — the app replies `connectRefused`. Anything else (an
  empty token, a guess, noise) is met with silence as before, so a stranger who
  guessed the preview's URL does not learn there is a bridge here at all. The
  distinction is the whole value: "this build carries no bridge" and "your
  signature is stale" are two different repairs and used to look identical.

  Your build holds no secret and copies nothing out of Studio: the public half
  of the pair ships inside the bridge package, and a public key can only check
  signatures, never make them. The build names one thing — where it answers:
  `--dart-define=STUDIO_APP_ORIGIN=https://app.example`, wired through the
  shipped `studioSignedAccessValidator`. Leave the define out and the build
  accepts any connection, which is what makes running Studio against your local
  build a zero-config affair.
- **Features** arrive per screen, as the app navigates: every widget that
  implements `DwFeature` declares its `DwFeatureSpec` next to itself, and the
  binding reports the ones currently mounted. What a feature says about itself
  — `purpose`, `behaviors`, `requirements`, `implementationNotes`,
  `knownIssues` — travels over the bridge on every connect, so Studio renders
  it live and stores none of it: there is nothing that can drift away from the
  code. A feature with a non-empty `knownIssues` is flagged in the catalog, so
  the open questions of a project are visible without opening every passport.

  `manifest.features` stays in the protocol for the *whole-project* catalog,
  but a running app cannot fill it: Dart has no reflection, so only mounted
  widgets are observable. Enumerating every feature of a project is a job for
  static analysis of the sources, not for the app.

- **Tap to inspect.** Studio can point at a spot in the live preview and get
  the feature declared there (`DwFeature.hitTest` on the app side), so a
  passport is reachable by pointing rather than by knowing the feature's id.
  The point crosses the bridge as fractions of the app's viewport, not pixels —
  Studio may be showing the preview scaled or framed, and only the app knows
  its own logical size, so the app converts. A feature is matched on the area
  it actually paints into: something scaled down, scrolled out of its viewport
  or clipped away does not answer for a point where the user sees nothing.

## Asking whether an app has a bridge at all

Studio has a second reason to talk to an app: not to preview it, but to find out
whether it answers. `probeStudioBridge(appUrl: …)` performs exactly one
handshake and returns one of three things:

```dart
switch (await probeStudioBridge(appUrl: url, accessToken: myTokenSupplier)) {
  StudioHandshakeResult.accepted => 'connected',
  StudioHandshakeResult.rejected => 'the signature was refused',
  StudioHandshakeResult.silent   => 'no answer',
}
```

The frame is created and removed inside the call — nothing to render, nothing to
know about. That matters because the preview's own `StudioFrameController` hands
out a *platform view*: its iframe is not in the document until the embedder lays
it out, and a detached iframe never fetches its `src`, so no layout means no
load means no handshake. Asking this question through the preview therefore cost
a 1×1 frame parked on screen for the lifetime of the app.

`silent` covers several causes at once — no bridge in the build, a page that
never loaded, a deployment that forbids being framed, an older app refusing in
silence. Cross-origin they are one silence and cannot be separated from here:
check that the URL serves a page, and that it permits `frame-ancestors`, as
steps of their own before the probe.

See the package [README](../packages/dartway_studio_bridge/README.md) for the
full API of the wire, `dartway_studio_binding` for the app half, and
`example/dartway_example_flutter/lib/core/studio/` for what a project is left
holding: its manifest and its screen passports, and nothing else.

## Apps that are not Flutter

Studio previews a web build in an iframe, and nothing in the protocol is
Flutter-specific — so an app written in React or Vue connects to the same
Studio, unmodified. The app half of the bridge exists a second time as
`js/studio-bridge` (`@dartway/studio-bridge` on npm): one core plus two thin
bindings (`/react`, `/vue`), speaking the same protocol version, checking the
same signature against the same shipped public key.

One thing differs, and not on the wire: a JS app **can** enumerate its features,
because a declaration is a component and components are what a framework already
tracks — where a Flutter app reports what is mounted, a React or Vue app
declares `<StudioFeature>` and the registry does the rest.

The two implementations are kept honest by golden wire strings in the JS
package's tests: the Dart encoder's exact output, key order included. Change the
protocol on one side and those tests fail — which is the point, since the two
packages version independently and a pilot team's preview is a poor place to
discover a rename.
