# Changelog

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
