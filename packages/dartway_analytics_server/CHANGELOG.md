## 0.2.0

- Reports, the catalog and dashboards (#360): `DwAnalyticsModule` answers `DwGetAnalyticsReport`
  (one parametrised statement over `dw_analytics_event`, time buckets in the viewer's calendar with
  empty buckets as zero, the top values of a property and the rest), `DwGetAnalyticsCatalog`, and
  the dashboard calls over a new table, `dw_analytics_dashboard` (migration
  `20260927_000000_analytics_dashboards`, applied at start, which also indexes
  `dw_analytics_event (occurred_at)` for reports over every event and the catalog).
- `DwAnalyticsModule(readAccess:, editAccess:)`: who reads, and who saves and deletes dashboards
  (by default whoever reads). The framework knows no roles, so the rule is the project's; without
  one every read is refused `dw.forbidden`. `DwAccessRule.anonymous` for either refuses startup.

## 0.1.0

- First version: analytics on DartWay 1.0 (D-069). See `docs/4-server/analytics.md`.
