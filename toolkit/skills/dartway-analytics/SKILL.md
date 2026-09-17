---
name: dartway-analytics
description: >-
  Analytics in a DartWay project: the server module `DwAnalyticsModule`
  (`dartway_analytics_server`) in `DwAppServer(modules:)`, the protocol composed with
  `dwAnalyticsProtocolEntries`, the project's event enum `with DwAnalyticsEvent` in the shared
  package, the app plugin `DwAnalytics` (`dartway_analytics_flutter`, `dw.plugins.analytics.track`)
  with `attribution`, events the server records with `ctx.analytics.track` in a command's
  transaction, sessions, retention, and reading the tables with SQL. Use when a feature must be
  measured — a funnel, activation, usage of a screen — or when numbers look wrong.
---

# DartWay — analytics (`dartway-analytics`)

**Events stay in the project's Postgres.** Nothing goes to a third party; the full description is
`docs/4-server/analytics.md` in the framework repository.

## Wiring

- `__SHARED_PKG__`: `enum <Project>Event with DwAnalyticsEvent { ... }` — one enum, names in
  lowerCamelCase that say what happened (`orderPlaced`, not `clickButton3`). `dw.` is the
  framework's.
- Both protocols: `DwWireProtocol(dwAnalyticsProtocolEntries, include: appProtocol)`.
- `__SERVER_PKG__`: `DwAnalyticsModule()` in `modules:`; its migrations apply at start.
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

SQL over `dw_analytics_event` (`name`, `source`, `occurred_at`, `install_id`, `session_number`,
`account_id`, `properties` jsonb) and `dw_analytics_install`. Count installs for activity (one per
device, before and after sign-in), accounts for people. Sessions end after 30 minutes of silence.

## Tests

- Server: call the command that records and read `dw_analytics_event` in the test database.
- App: `DwAnalytics(store: DwMemoryAnalyticsStore())` against `DwFakeServer` answering
  `DwTrackEvents`; `await analytics.flush()` sends what waits.
