## 0.2.0

- `dw.plugins.analytics.saveDashboard` and `deleteDashboard` (#360): run the dashboard commands and
  read `DwListAnalyticsDashboards` again for every screen watching it — the module has no channel
  to announce a change. Reports and the catalog are read as any request,
  `dw.request(DwGetAnalyticsReport(...))`. No widgets: the viewer is the app's, scaffolded into the
  starter's admin panel.
- `dispose()` no longer waits for the account subscription's cancellation, which under a widget
  test's fake time completed only after the test: it now completes once the queue is stored.

## 0.1.0

- First version: analytics on DartWay 1.0 (D-069). See `docs/4-server/analytics.md`.
