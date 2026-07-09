# Changelog

## 0.1.0

- First public release: typed realtime data layer over the DartWay Serverpod
  module (`watchModelList`/`watchModel`/`saveModel`/`deleteModel` with
  skeleton loading states), session management with persistent auth keys,
  connection-aware error handling (`dwReportingOnFailedCall`) and
  out-of-the-box context-rich error alerting via `DwCore.reportError`
  (route, mounted features, action/call, platform, app version, user).
- Re-exports `dartway_flutter` — one import covers the standard DartWay app
  surface.
