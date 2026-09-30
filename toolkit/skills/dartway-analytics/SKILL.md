---
name: dartway-analytics
description: >-
  Product analytics in the project's own Postgres: DwAnalyticsModule with readAccess, the protocol
  composed with dwAnalyticsProtocolEntries, the event enum in the shared package, the app plugin
  DwAnalytics (dw.plugins.analytics.track), server-side ctx.analytics.track, reports
  (DwGetAnalyticsReport), dashboards and the admin viewer, and SQL. Use when a feature must be
  measured, when the team needs a dashboard, or when numbers look wrong.
---

# DartWay — analytics (`dartway-analytics`)

Events stay in the project's Postgres; nothing goes to a third party. The full page:
`docs/4-server/analytics.md` in the framework repository.

**Wiring.** `enum <Project>Event with DwAnalyticsEvent { … }` in `__SHARED_PKG__` — lowerCamelCase names
of what happened (`orderPlaced`); both protocols include `dwAnalyticsProtocolEntries`;
`DwAnalyticsModule(readAccess: …)` in the server's `modules:` — the skeleton's admin rule or narrower
(without it every read is `dw.forbidden`; `anonymous` refuses to start; `editAccess` defaults to it);
`DwAnalytics(attribution: …)` in the app's `plugins:`.

**Tracking.**

- In the app, where it happened — a tap handler, a state change, never `build`:
  `dw.plugins.analytics.track(Event.x, {'key': value})`. It never throws; events batch and send in the
  background.
- On the server what only the server knows (a payment settled): `await ctx.analytics.track(Event.x,
  properties: {…})` in the command's transaction.
- Properties: strings, numbers, booleans, at most 30, flat — ids, amounts, variants; **never personal
  data**. Name them so a non-developer can pick them from a list.

**Reading.** A number the team watches is a dashboard widget, not code: the skeleton's viewer in
`lib/admin/analytics/` (source the project owns) builds number, bar and pie widgets from the catalog of
recorded names. In code: `dw.request(DwGetAnalyticsReport(spec: DwAnalyticsReportSpec(…), period:
DwAnalyticsPeriod.localDays(…)))` — a metric (events, accounts, installs), filters, a breakdown (time or
a property; `DwAnalyticsBreakdownOrder.byLabel` for funnel steps). Dashboards change through
`dw.plugins.analytics.saveDashboard` / `deleteDashboard`, which refresh their list. Charts are kit widgets
(`ui_kit/3_special/charts/`). Sequences and cohorts are SQL over `dw_analytics_event` (`name`,
`occurred_at`, `install_id`, `session_number`, `account_id`, `properties`) — installs for activity,
accounts for people; a session ends after 30 minutes of silence.

**Tests.** Server: run the command, read `dw_analytics_event`; a report as an admin, `dw.forbidden` as a
member. App: `DwAnalytics(store: DwMemoryAnalyticsStore())` against a fake answering `DwTrackEvents`,
then `flush()`.
