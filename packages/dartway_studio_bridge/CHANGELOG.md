# Changelog

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
