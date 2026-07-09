# Changelog

## 0.9.0

- First public release: `DwAppRunner` bootstrap, `dw` app core (navigation,
  notifications, services, shared preferences, Telegram web-app support),
  overlay notifications pipeline, base UI kit (`DwButton`, `DwText`,
  `MultiLinkText`, `DwDeviceFrame`, `DwInfiniteListView`, `DwFlutterTheme`)
  and AsyncValue utilities (`dwBuildListAsync`, `DwUiAction`).
- Re-exports `DwFeature` / `DwFeatureSpec` / `scanMountedFeatures` from
  `dartway_studio_bridge` — feature declarations are part of the standard
  DartWay app surface.
- Removed the legacy `zarchive` material-app wrapper and the unused
  `DwButtonNew` draft from the public surface.
