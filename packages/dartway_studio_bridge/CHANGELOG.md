# Changelog

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
