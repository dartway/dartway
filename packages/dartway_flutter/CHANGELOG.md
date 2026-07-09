# Changelog

## 0.1.0

- First public release: `DwAppRunner` bootstrap, `dw` app core (navigation,
  notifications, services, shared preferences, Telegram web-app support),
  overlay notifications pipeline, base UI kit (`DwButton`, `DwText`,
  `MultiLinkText`, `DwDeviceFrame`, `DwInfiniteListView`, `DwFlutterTheme`)
  and AsyncValue utilities (`dwBuildListAsync`, `DwUiAction`).
- Feature declarations moved in from the Studio bridge: `DwFeature`,
  `DwFeatureSpec` and `scanMountedFeatures` are app semantics and now live
  here — feature catalogs, error-report context, analytics; a Studio binding
  maps them onto the bridge wire model.
- Error reporting pipeline: `dw.errorContext` (route source + custom lazy
  entries), `DwErrorReport`/`DwErrorSource`, `dw.handleError` captures an
  app-state snapshot (route, mounted features, action label, platform,
  version) and dispatches through the overridable `reportError`;
  `DwConfig.onErrorReport` and `DwConfig.appVersion` added. `DwAppRunner`
  routes uncaught zone errors into the pipeline by default.
- `DwUiAction.create`: new optional `label` (names the action in error
  reports; falls back to the notification texts) and `confirmation`
  (`DwUiConfirmation` + built-in `DwConfirmDialog`, customizable via
  `DwConfig.confirmDialogBuilder`) — declining skips the action entirely.
- Removed the legacy `zarchive` material-app wrapper and the unused
  `DwButtonNew` draft from the public surface.
