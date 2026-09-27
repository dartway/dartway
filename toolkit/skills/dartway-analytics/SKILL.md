---
name: dartway-analytics
description: >-
  Analytics in a DartWay project: the server module `DwAnalyticsModule`
  (`dartway_analytics_server`) in `DwAppServer(modules:)`, the protocol composed with
  `dwAnalyticsProtocolEntries`, the project's event enum `with DwAnalyticsEvent` in the shared
  package, the app plugin `DwAnalytics` (`dartway_analytics_flutter`, `dw.plugins.analytics.track`)
  with `attribution`, events the server records with `ctx.analytics.track` in a command's
  transaction, sessions, retention, reports (`DwGetAnalyticsReport`), the catalog, saved dashboards
  and who may read them (`readAccess`), the admin viewer in `lib/admin/analytics/`, and SQL. Use
  when a feature must be measured — a funnel, activation, usage of a screen — when the team needs a
  dashboard, or when numbers look wrong.
---

# DartWay — analytics (`dartway-analytics`)

**Events stay in the project's Postgres.** Nothing goes to a third party; the full description is
`docs/4-server/analytics.md` in the framework repository.

## Wiring

- `__SHARED_PKG__`: `enum <Project>Event with DwAnalyticsEvent { ... }` — one enum, names in
  lowerCamelCase that say what happened (`orderPlaced`, not `clickButton3`). `dw.` is the
  framework's.
- Both protocols: `DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol)`.
- `__SERVER_PKG__`: `DwAnalyticsModule(readAccess: <the project's rule>)` in `modules:` — the
  admin rule the skeleton declares, or a narrower one; its migrations apply at start. Without
  `readAccess` every report and dashboard read is refused `dw.forbidden`; `DwAccessRule.anonymous`
  refuses to start. `editAccess` (saving dashboards) defaults to `readAccess`.
- `__FLUTTER_PKG__`: `DwAnalytics(attribution: ...)` in `plugins:`.

## Tracking

- **In the app, at the moment it happened**: `dw.plugins.analytics.track(Event.x, {'key': value})`
  in the handler of the tap or where the state changed — not in `build`, which runs many times.
- **On the server, when only the server knows**: payment settled, order accepted, job done —
  `await ctx.analytics.track(Event.x, properties: {...})` in the command's transaction. A fact the
  server decides is recorded there, not by the app that asked for it.
- Properties are strings, numbers, booleans; at most 30; nothing nested. Ids, amounts, variants —
  never personal data (names, phones, e-mails, message text).
- `track` makes no call and never throws: events are batched, kept on the device and sent every
  30 s, at 50 waiting, and when the app goes to the background.

## Reading

**A number the team watches is a dashboard widget, not code.** The skeleton's admin panel has the
viewer (`lib/admin/analytics/`, source the project owns): a period on top, widgets of three types —
a number with its change, bars, a pie — built from the catalog of recorded names and keys. A new
event shows up there once the app records it; name events and properties so a non-developer can
pick them from a list (`stepNumber`, `sectionName` rather than `p1`).

- In code: `ref.watch(dw.request(DwGetAnalyticsReport(spec: ..., period: ...)))` — a
  `DwAnalyticsReportSpec` (event, `DwAnalyticsMetric` events / accounts / installs,
  `DwAnalyticsFilter`s, `DwAnalyticsBreakdown` none / by time / by a property's top values) over a
  `DwAnalyticsPeriod` (`localDays`, `previous`). Distinct counts are counted over the whole period.
- Dashboards change through `dw.plugins.analytics.saveDashboard` / `deleteDashboard`, which refresh
  `DwListAnalyticsDashboards`; `dw.command` with the dashboard commands leaves the list stale.
- Charts are the UI kit's (`AppBarChart`, `AppPieChart`, `AppStatValue`): a new chart type goes
  into `ui_kit/3_special/charts/`, never as raw styling in the feature.

What reports do not answer — a sequence within a session, cohorts — is SQL over
`dw_analytics_event` (`name`, `source`, `occurred_at`, `install_id`, `session_number`,
`account_id`, `properties` jsonb) and `dw_analytics_install`. Count installs for activity (one per
device, before and after sign-in), accounts for people. Sessions end after 30 minutes of silence.

## Tests

- Server: call the command that records and read `dw_analytics_event` in the test database; a
  report through a signed-in admin client, and `dw.forbidden` for a member.
- App: `DwAnalytics(store: DwMemoryAnalyticsStore())` against `DwFakeServer` answering
  `DwTrackEvents`; `await analytics.flush()` sends what waits. Widget tests of admin screens answer
  `DwListAnalyticsDashboards` (and the reports a dashboard shows) on the fake server.
