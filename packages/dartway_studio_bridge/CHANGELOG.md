# Changelog

## 0.2.0

- **Breaking:** passport texts are single-language plain strings — `StudioText`
  and `StudioLanguage` are removed; `StudioScreenSpec`, `StudioZoneSpec` and
  `DwFeatureSpec` fields are now `String` / `List<String>`, and
  `StudioManifestIndex.crumbLabel` takes no language. Specs are authored in
  whatever language the project team writes; Studio shows them as is.
- **Breaking:** protocol version bumped to 2 (v1 messages are ignored by both
  sides).
- App locale switching: `StudioProjectManifest.supportedLocales`,
  `currentLocale` in the connect snapshot, the `localeRequest` (Studio → app)
  and `localeChanged` (app → Studio) messages,
  `StudioBridgeHostDelegate.onLocaleRequest`, `StudioBridgeHost.reportLocale`,
  `StudioBridgeClient.requestLocale` and the `StudioProjectLocaleChanged`
  event. Apps declaring fewer than two locales are treated as non-switchable.
- `StudioZoneSpec.allowedPersonaIds`: a role-gated zone lists the demo
  personas that can enter it (empty = any), so Studio can switch the session
  to a capable persona before navigating. The app's guards stay the real
  protection.
- **Breaking:** feature declarations (`DwFeature`, `DwFeatureSpec`,
  `scanMountedFeatures`) moved to `dartway_flutter` — they are app semantics,
  not transport. The bridge keeps a wire model `StudioFeatureInfo`
  (id/title/description); the app's binding maps discovered features onto it.

## 0.1.0

- Initial release: spec models (`StudioText`, `StudioScreenSpec`,
  `StudioZoneSpec`, `StudioPersonaSpec`, `StudioProjectManifest`,
  `StudioSessionState`, `StudioManifestIndex`), the versioned postMessage
  protocol, the app-side `StudioBridgeHost` and the Studio-side
  `StudioBridgeClient` + `StudioFrameController` (iframe embedding).
- Runtime feature discovery: the `DwFeature` interface (a widget declares its
  `DwFeatureSpec`), `scanMountedFeatures()`, the `featuresChanged` message and
  `StudioProjectFeaturesChanged` event; the connect manifest snapshot now
  carries the current screen's features.
