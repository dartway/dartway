# Changelog

## 0.1.0

- First public release of the open bridge between a DartWay app and DartWay
  Studio (protocol version 2):
  - **Spec models** declared in the app's code and delivered on connect:
    `StudioProjectManifest` (zones, screens, personas, supported locales),
    `StudioScreenSpec` passports (single-language plain strings),
    `StudioZoneSpec` with access rules and `allowedPersonaIds` (role-gated
    zones name the demo personas that can enter), `StudioPersonaSpec`,
    `StudioFeatureInfo` (wire model of the features mounted on the current
    screen), `StudioManifestIndex` lookup helpers.
  - **Runtime postMessage protocol**: dual-initiated handshake that survives
    reloads and hot restarts, navigation and route reporting, persona
    sign-in/sign-out (credentials never cross the bridge), app locale
    switching (`localeRequest`/`localeChanged`), live feature reporting.
  - **App side** `StudioBridgeHost` (dormant outside a Studio iframe;
    release builds require an explicit origin allowlist) and **Studio side**
    `StudioBridgeClient` + `StudioFrameController` (iframe embedding).
