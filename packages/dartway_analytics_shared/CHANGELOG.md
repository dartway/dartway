## 0.2.0

- Reads of what was recorded (#360): `DwGetAnalyticsReport` — a count of events, distinct
  accounts or distinct installs (`DwAnalyticsMetric`) over a `DwAnalyticsPeriod`, filtered by
  properties (`DwAnalyticsFilter`) and broken down by time bucket or by the top values of a property
  (`DwAnalyticsBreakdown`) — answering `DwAnalyticsReport`; `DwGetAnalyticsCatalog`, the event
  names and property keys seen in a period.
- Saved dashboards: `DwAnalyticsDashboard` with ordered `DwAnalyticsWidgetSpec`s (indicator, bar,
  pie), `DwListAnalyticsDashboards`, `DwSaveAnalyticsDashboard`, `DwDeleteAnalyticsDashboard`.
- `DwAnalyticsRefusal.reportInvalid` and `dashboardInvalid`.
- `dwAnalyticsProtocolEntries` registers the new calls; a protocol built from it needs no change.

## 0.1.0

- First version: analytics on DartWay 1.0 (D-069). See `docs/4-server/analytics.md`.
