## 0.2.0

- Reads of what was recorded (#360): `DwGetAnalyticsReport` — a count of events, distinct
  accounts or distinct installs (`DwAnalyticsMetric`) over a `DwAnalyticsPeriod`, filtered by
  properties (`DwAnalyticsFilter`) and broken down by time bucket or by the top values of a property
  (`DwAnalyticsBreakdown`; a property's values largest first or by label —
  `DwAnalyticsBreakdownOrder` — at most 30) — answering `DwAnalyticsReport`;
  `DwGetAnalyticsCatalog`, the event names and property keys seen in a period.
- `DwAnalyticsPeriod.localDays` ends at now at the latest; `previous` is the same period moved
  back by the whole days it spans.
- Saved dashboards: `DwAnalyticsDashboard` with ordered `DwAnalyticsWidgetSpec`s (indicator, bar,
  pie — a pie only for events broken down by a property), `DwListAnalyticsDashboards`,
  `DwSaveAnalyticsDashboard`, `DwDeleteAnalyticsDashboard`.
- `DwAnalyticsRefusal.reportInvalid` and `dashboardInvalid`.
- `dwAnalyticsProtocolEntries` registers the new calls; a protocol built from it needs no change.

## 0.1.0

- First version: analytics on DartWay 1.0 (D-069). See `docs/4-server/analytics.md`.
