# Changelog

## 0.7.0

**Access is proved by a signature, not by a shared secret** (protocol version 4 — breaking). An app
built against 0.6.0 or earlier will not accept a token, and a Studio on the new protocol presents no
secret: both sides move together.

`studioConnect` now carries an `accessToken` — short-lived, signed by Studio with an **Ed25519** key
and issued for **one origin**, the address the app answers at.

```text
<payload>.<signature>
payload   = base64url( utf8( {"origin":"https://app.example","exp":1765540000} ) )
signature = base64url( ed25519_sign( privateKey, ascii(payload) ) )
```

`verifyStudioBridgeToken` accepts a token only when the signature checks out against Studio's key,
the origin is this app's own, and the expiry is still ahead. Anything else is a plain `false` rather
than an exception: a refused connection looks the same whatever is wrong with it, and the app
carries on running.

**The public key ships inside this package** (`studioSigningPublicKey`). A public key verifies
signatures and cannot make them, so it is harmless in the open, and it is the same for every
project — which is the point: a team connecting its app has nothing to copy out of Studio, nothing
to store and nothing to replace when the pair is rotated. They update the package.

**The signature has to be asymmetric.** An HMAC over a shared secret is simpler and would put that
secret straight back into the app's public web bundle — whatever is baked into a web build is
public. That was the hole in 0.3.0's scheme, and rotating the secret could not close it, because
rotating it meant releasing the app.

**A stolen token travels nowhere.** The origin claim is what the old scheme had no room for: a
secret lifted out of one build worked against every deployment that shared it, indefinitely. A
token works at one address, for minutes.

**What changed in the API:**

- `StudioBridgeHost.attach`: `validateAccessKey` → `validateAccessToken`.
- `studioSignedAccessValidator(appOrigin)` replaces `studioHashAccessValidator(expectedHash)`, and
  `studioAccessKeyHash` goes with the scheme it belonged to. Two ways to authenticate the bridge is
  not compatibility, it is a second door — so the old one is deleted rather than deprecated.
- The build names its own address instead of a hash copied out of Studio:
  `--dart-define=STUDIO_APP_ORIGIN=https://app.example` in place of `STUDIO_KEY_HASH`. **An empty
  define still accepts any connection** — the zero-config local-dev mode is unchanged, and without
  it nobody could run Studio against the build on their laptop.
- `StudioBridgeClient`: `accessKey` (a string read once) → `accessToken`, a supplier asked on every
  connect attempt. A preview outlives any short-lived token, so the reconnect after an app reload
  hours later has to carry a live one; caching and re-issuing is the supplier's business. Attempts
  never overlap, and a supplier that throws leaves that attempt unsent for the retry timer to
  repeat.
- The `crypto` dependency is replaced by `cryptography`.

## 0.6.0

**Studio can ask what is at a point on screen.** A new request/answer pair —
`InspectPointRequestMessage` / `InspectPointResultMessage` — carries the "pencil" tap-to-inspect
flow: Studio names a spot in the live preview, the app answers with the feature declared there, or
with nothing. `StudioBridgeClient.inspectPoint()` is the Studio side; `StudioBridgeHost.attach`
takes an `inspectPoint` callback for the app side (a DartWay app hands it `DwFeature.hitTest`).

**The point travels as fractions of the app's viewport, not pixels.** Studio shows the preview
scaled, framed, letterboxed — whatever the panel needs — and only the app knows its own logical
size. A fraction means the same point under every one of those, so the conversion happens once, in
the app, instead of Studio guessing.

**The request carries an id and the answer echoes it back.** Inspect is the first message that can
be in flight twice: a second tap while a slow first one is still being answered. Matching on
"whatever result arrives next" would resolve the second tap with the first tap's answer — a
confidently wrong passport, which is worse than none. Requests that time out are forgotten, so
their late answers are dropped rather than handed to whoever is waiting now.

An app that predates this message stays silent, and the requester's timeout reads that as "nothing
declared here" — the same as a real miss, never a hang. An app whose `inspectPoint` throws still
answers (with nothing) and reports the error through `FlutterError.reportError`: silence would have
cost Studio its full timeout and disguised a crash as an empty spot.

## 0.5.0

`StudioFeatureInfo` follows `DwFeatureSpec` (package `dartway_flutter` 0.3.0) and carries
`knownIssues`: what is wrong in the feature and worth taking into work. Studio flags a feature that
has any, so open questions are visible from the catalog instead of one passport at a time.

Additive and lenient in both directions, as before: an app built against 0.4.0 sends no
`knownIssues` and decodes fine here, and a Studio on 0.4.0 ignores the new key.

## 0.4.0

**A feature reports what it actually does, not one line about itself.** `StudioFeatureInfo` follows
`DwFeatureSpec` (package `dartway_flutter` 0.2.0): `purpose`, `behaviors`, `requirements` and
`implementationNotes` replace the single `description`. The fields split by audience — `title`,
`purpose` and `behaviors` are what a client reads, the other two are written for the team — and
Studio is expected to show them apart.

All of it travels on every connect and nothing needs storing on the Studio side, which is the point:
a description held in a database is a description that can drift away from the code it describes.

Decoding stays lenient in both directions. An app built against 0.3.0 sends `description` and no
lists — it decodes without error, just without the new fields; an app built against a newer bridge
may send fields this one has never heard of, and those are ignored. Empty lists and a null `purpose`
never reach the wire.

## 0.3.0

**Per-project access control.** The `studioConnect` handshake now carries an `accessKey`, and
`StudioBridgeHost.attach` takes a `validateAccessKey` callback — the app answers with its manifest
only if the key is accepted, otherwise it stays silent (still runs; Studio shows "not connected").

The bridge is agnostic to *how* the key is checked. The shipped default keeps the secret out of the
app's public build: Studio holds a per-project random secret, the app bakes only its **hash** and
compares. `studioAccessKeyHash(secret)` (hex SHA-256) and `studioHashAccessValidator(expectedHash)`
are provided; an empty expected hash accepts any key (zero-config local dev).

```dart
StudioBridgeHost.attach(
  // …
  validateAccessKey: studioHashAccessValidator(
    const String.fromEnvironment('STUDIO_KEY_HASH'),
  ),
);
```

Adds a `crypto` dependency. `StudioBridgeClient` gains an `accessKey` parameter.

## 0.2.0

**Demo personas move from the app to Studio** (protocol version 3 — breaking).

0.1.0 kept persona credentials inside the app so they "never cross the bridge". In practice that
meant a public web build shipped its list of privileged test accounts and a sign-in path for them —
a worse hole than the one avoided. Inverted:

- `StudioProjectManifest` no longer lists personas; `StudioPersonaSpec` is removed. Test users and
  their verification codes are configured in Studio (a platform concern), so the app's build
  contains no test accounts at all.
- `personaRequest` is replaced by `signInRequest` carrying `identifier` + `secret` (a test verification code for OTP flows, a password for password flows).
  The app executes it through its **regular** auth flow — exactly as if the user typed the code
  (DartWay server side: per-user rotatable `testVerificationCode`). No special sign-in path ships
  in the app. `StudioBridgeHostDelegate.onPersonaRequest` → `onSignInRequest`;
  `StudioBridgeClient.requestPersona` → `requestSignIn`.
- `StudioSessionState.activePersonaId` → `userIdentifier`: the app reports who is signed in in its
  own terms; matching a session to a configured persona is Studio's job.
- `StudioZoneSpec.allowedPersonaIds` is removed: role-gating belongs to the app (router guards,
  server filters), and per-zone persona hints proved to be ceremony the app should not carry.
- The origin allowlist (`allowedStudioOrigins`, release-dormant policy) is removed for now:
  zero-config local work first. The channel still pins the origin of the first valid Studio
  message for its replies; an explicit opt-in policy can return later.
- `StudioProjectManifest.features`: the app's complete feature catalog (DartWay apps: the values
  of their feature-registry enum). Studio diffs it on every connect — new features surface
  immediately, a vanished feature with open work is flagged instead of silently unlinking. The
  live per-screen subset still arrives via feature reports.
- `RouteChangedMessage`/`reportRoute` carry an optional `routeName` — the stable route identity
  (the app's route-enum name); the path is the instance context (`/ad/123`).
- `StudioScreenSpec.featureSpec` is removed: the Technical view is fed by the live feature scan
  and the catalog, not by hand-written strings on screen specs.

## 0.1.0

First public release — the open bridge between a DartWay app and
[DartWay Studio](https://dartway.dev) (protocol version 2).

**Screen specs live in the app's code.** `StudioProjectManifest` (zones, screens, personas,
supported locales), `StudioScreenSpec` passports, `StudioZoneSpec` with access rules and
`allowedPersonaIds` for role-gated zones, `StudioPersonaSpec`, `StudioFeatureInfo`. The app is the
single source of truth: Studio receives the manifest over the runtime channel on connect, so a
passport cannot go stale against the build it describes — which is exactly what happens to the same
document kept in a wiki.

**A runtime `postMessage` protocol.** A dual-initiated handshake that survives reloads and hot
restarts, navigation and route reporting, persona sign-in and sign-out, app locale switching, live
reporting of the features mounted on the current screen.

**Credentials never cross the bridge.** Persona sign-in runs entirely inside the app, through the
app's own auth.

**App side:** `StudioBridgeHost` — dormant outside a Studio iframe, and in a release build it
requires an explicit origin allowlist, so an app cannot be previewed by a Studio you did not name.
**Studio side:** `StudioBridgeClient` and `StudioFrameController`.
