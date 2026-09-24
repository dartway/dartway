# How does an app talk to DartWay Studio?

Through `dartway_studio_bridge`, an open package with two halves: **spec models** an app declares in
its own code, and a **versioned `postMessage` protocol** between Studio and the app's web build
running in an iframe. [DartWay Studio](https://dartway.dev) is the closed platform on the other end:
a live preview of the running app with its screen map, screen passports, the features on the current
screen, and a demo-persona switcher.

The package is a satellite (`packages/dartway_studio_bridge`, version `0.10.0`, versioned on its own):
it depends on Flutter and nothing of the DartWay core, so it is true of any Flutter web app, and its
README (`packages/dartway_studio_bridge/README.md`) is the full reference of its API.

**The app half is `packages/dartway_studio_binding`** (`0.2.0`): one widget, `DwStudioBinding`,
mounted in `MaterialApp.builder`. It attaches the bridge, reports the route (path and declared
name), the features mounted on screen, the session and the language, and executes what Studio asks
— navigate, switch persona, change language. Who is signed in comes from the project's own provider
(`user:`), mapped to `DwStudioUser`; the persona switch runs the app's regular sign-in by code with
the code Studio holds (`DwAuthConfig.fixedCode` accepts it), so the app ships no test users.

`deploy run` passes the build the address it answers on as `STUDIO_APP_ORIGIN`, which
`studioSignedAccessValidator` checks a connecting Studio's token against: a token taken from one
stand is useless on another.

## Why the app describes itself, and Studio stores nothing

**The app is the single source of truth for its structure.** Studio receives the manifest — navigation
zones, screen passports, supported locales — over the runtime channel on every connect, so it cannot
go stale relative to the build it is showing. Features travel the same way: what a feature says
about itself is declared next to its code in a `DwFeatureSpec` (see
[Features and specs](../3-flutter/features-and-specs.md)), and an app reports the ones currently
mounted — `DwFeatureWidget.scanMounted()` — rather than a catalogue kept anywhere else.

**Demo personas are the opposite: a platform concern.** Test users and their codes are configured in
Studio's project settings and never ship inside the app's public web build. On a switch Studio sends
the credentials over the bridge and the app runs its **regular** sign-in with them — so a public
build carries no test accounts and no special sign-in path. Role gating stays entirely in the app:
guards and server rules, not spec metadata.

## The spec models

| Model | What it declares |
|---|---|
| `StudioProjectManifest` | `projectName`, `zones`, `features`, `supportedLocales` — what the app sends on connect |
| `StudioZoneSpec` | A labelled group of screens with a root path and `StudioZoneAccess` (`signedIn`, `signedOut`, `any`) |
| `StudioScreenSpec` | A screen passport keyed by its route path: `title`, `purpose`, `parentPath`, `discussionQuestions` |
| `StudioFeatureInfo` | One feature on the wire: `id`, `title`, `purpose`, `behaviors`, `requirements`, `implementationNotes`, `knownIssues` |
| `StudioSessionState` | Whether someone is signed in, their identifier and label, and whether a requested sign-in is in progress |
| `StudioManifestIndex` | Looks a reported address up among the declared screens: exact path, then template (`/profile/:id`), then the deepest non-root prefix |

Screens are identified by plain path strings, so any router works. Passport texts are plain strings
in whatever language the team writes its specs in; Studio shows them as they are.

`manifest.features` stays in the protocol for a whole-project catalogue, but a running Flutter app
cannot fill it: Dart has no reflection, so only mounted widgets are observable. Enumerating every
feature of a project is a job for static analysis of the sources.

## The protocol

Every message is a JSON string `{"dartwayStudioBridge": 4, "type": "…", "payload": {…}}`, and both
sides ignore an envelope of another version. The types are the constants of
`StudioBridgeProtocol`:

| Direction | Types |
|---|---|
| Studio → app | `studioConnect` (with the access token), `navigateRequest`, `signInRequest`, `signOutRequest`, `localeRequest`, `inspectPointRequest` |
| App → Studio | `appReady`, `manifest`, `connectRefused`, `routeChanged`, `sessionChanged`, `featuresChanged`, `localeChanged`, `inspectPointResult` |

The handshake is initiated from both ends and survives reloads and hot restarts of either side. The
app pins the origin of the first valid Studio message for its replies.

**Adding a message type does not bump the version; changing the meaning of one does.** The version is
checked strictly, so a bump silences every build already in the field in both directions the moment it
ships. A new type costs nothing: an old side drops the envelope it does not recognise and carries on —
which is how `connectRefused` arrived inside version 4.

**Tap to inspect** crosses the bridge as fractions of the app's viewport, not pixels: Studio may show
the preview scaled or framed, and only the app knows its own logical size. The app converts the point
and answers with the feature declared there (`DwFeatureWidget.hitTest` in a DartWay app). Each request
carries an id the app echoes back, so a second tap never receives the first one's answer, and an app
that does not know the message stays silent until Studio's timeout reports "nothing here".

## Access is proved by a signature

Studio presents a short-lived token, signed with its Ed25519 key and issued for **one origin** — the
address the build answers at:

```text
<payload>.<signature>
payload   = base64url( utf8( {"origin":"https://app.example","exp":1765540000} ) )
signature = base64url( ed25519_sign( privateKey, ascii(payload) ) )
```

A token lifted off the wire is worthless anywhere else, and it expires on its own. **The build holds
no secret**: the public half of the key pair ships inside the package as `studioSigningPublicKey`,
and a public key can only check signatures. The signature has to be asymmetric for exactly this
reason — an HMAC over a shared secret would put the secret back into a public web bundle.

A build names one thing, where it answers — `--dart-define=STUDIO_APP_ORIGIN=https://app.example` —
through `studioSignedAccessValidator(const String.fromEnvironment('STUDIO_APP_ORIGIN'))`. **A build
that names no origin accepts any connection**, which is what makes previewing a local build
zero-config.

**The gate is on everything.** Until a token is accepted the app runs no command it is sent and
reports nothing, so a page that embedded the build without presenting a token can neither drive it
nor read its passports. **A refusal is answered only when it refuses something**: a token that parses
as a signed Studio token (`looksLikeStudioBridgeToken`) and then fails — expired, or signed by another
key — gets `connectRefused`; an empty or garbled one gets silence, so a stranger who guessed the
preview's address learns nothing, while Studio is told its signature is stale instead of wondering
whether the app has a bridge at all.

## The two sides in the package

**App side.** `StudioBridgeHost.attach(manifest:, delegate:, currentPath:, currentSession:, …)`
connects a Flutter web app to the embedding window; a `StudioBridgeHostDelegate` executes navigation,
sign-in with credentials, sign-out and locale switches, and the host's `report…` methods send changes
back. It returns null when the app is not running on web inside an iframe, so the app stays fully
functional and the bridge dormant. This is the low-level surface a binding is built on.

**Studio side.** `createStudioFrameController` hosts the app in an iframe and `StudioBridgeClient`
drives it. `probeStudioBridge(appUrl:, accessToken:)` asks one question — does this URL answer — with a
single handshake in a frame it creates and removes itself, and returns a `StudioHandshakeResult`:
`accepted`, `rejected` (the app refused the token), or `silent`. Silent covers several causes at
once — no bridge in the build, a page that never loaded, a deployment that forbids framing — which
cross-origin cannot be told apart, so check that the URL serves a page and permits `frame-ancestors`
as steps of their own.

## When a connection is silent

A channel drops what is not for it and says nothing, which is right for a page's `window` — a shared
bus — and useless for the one real fault: **an app and a Studio on different protocol versions**, quiet
at each other and looking exactly like a stranger's message.

- `StudioBridgeProtocol.envelopeVersionOf(data)` reads the envelope version out of raw postMessage
  data: null for a foreign message, the version for ours. Decoding cannot tell those apart.
- `onMessageDropped`, taken by `createStudioFrameController`, `openStudioProbeFrame`,
  `probeStudioBridge` and `StudioBridgeHost.attach`, receives a `StudioMessageDrop` for every refused
  message, naming the step (`StudioMessageDropReason`: `notAMessageEvent`, `foreignOrigin`,
  `foreignSource`, `nonStringData`, `notAnEnvelope`, `versionMismatch`, `unknownType`). The last one
  means the other side is newer, which is not a fault. Without an observer nothing changes.

## Apps that are not Flutter

Nothing in the protocol is Flutter-specific. `js/studio-bridge` (`@dartway/studio-bridge` on npm) is
the app side for JavaScript apps — one core and two thin bindings, `/react` and `/vue` — speaking the
same protocol version and checking the same signature against the same public key. A JS app **can**
enumerate its features, because a declaration is a component and a framework already tracks
components. The two implementations are versioned independently and kept in step by wire tests on the
JS side that hold its encodings to the Dart encoder's exact output.
