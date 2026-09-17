# How does a DartWay project record what people do in the app?

With the analytics module: `DwAnalyticsModule` on the server (`dartway_analytics_server`) and the
`DwAnalytics` plugin in the app (`dartway_analytics_flutter`). Events are stored in the project's
own Postgres — nothing goes to a third party — and read with SQL.

```dart
// shared: the project's events, by name
enum ShopEvent with DwAnalyticsEvent { catalogOpened, productViewed, orderPlaced }

// both sides: the protocol knows DwTrackEvents
final appProtocol = DwWireProtocol(dwAnalyticsProtocolEntries, include: shopProtocol);

// server
DwAppServer(protocol: appProtocol, modules: [DwAnalyticsModule()], ...);

// app
dw = DwFlutterCore(protocol: appProtocol, plugins: [DwAnalytics(attribution: readUtm)], ...);
dw.plugins.analytics.track(ShopEvent.productViewed, {'productId': product.id});

// server, in a command's transaction
await ctx.analytics.track(ShopEvent.orderPlaced, properties: {'total': order.total});
```

## What an event is

A name from the project's enum `with DwAnalyticsEvent`, the moment it happened, and properties:
strings (up to 1000 characters), finite numbers, booleans, `null` — at most 30, keys of letters,
digits and `_`. Nothing nested: a property is a column of a report. The server does not know the
enum; a new event needs a new app build, not a server deploy.

The framework records four by itself (`DwAppEvent`, names under `dw.`): `dw.appOpened` (a cold
start, with the properties `attribution` returns — UTM parameters, a store referrer),
`dw.appResumed`, `dw.appBackgrounded`, `dw.accountChanged` (`signedIn: true/false`). Turn them off
with `DwAnalytics(lifecycleEvents: false)`.

## How the app sends

`track` makes no call. The event gets the install's next sequence number and waits on the device
(shared preferences, `DwAnalyticsStore`). Waiting events go out in one `DwTrackEvents` — every
`flushInterval` (30 s), when `batchSize` (50) wait, and when the app goes to the background — up
to 100 per call. A failed send keeps them for the next one; a restart finds them; beyond
`maxQueued` (1000) the oldest go. A batch the server refuses is dropped and reported through the
app's error pipeline. Properties the store does not take are reported and the event is dropped:
tracking never breaks the screen that tracks.

The **install id** is created on first start and kept. Every event carries it, so what a person
did before signing in and after is one history.

## How the server stores

`DwTrackEvents` is open to signed-out apps. In one transaction and three statements whatever the
batch size: the install row is upserted (and locked), the events are inserted with
`ON CONFLICT DO NOTHING` on `(install_id, sequence)` — a batch sent twice is stored once, so the
command stores no idempotency outcome (`recordsSuccess: false`) — and the install's running
session is written back.

- `account_id` is the account the call was signed in as — never a field of the batch. A deleted
  account leaves its events anonymous (`ON DELETE SET NULL`).
- `session_number` counts the install's sessions: a pause longer than `sessionGap` (30 min) between
  two events starts the next one, across batches.
- `occurred_at` is the device's clock, `received_at` the server's.
- Events `ctx.analytics.track` records have `source = 'server'`, no install and no session, and
  are written in the caller's transaction: a rolled-back command records nothing.

`dw.analytics.cleanup` removes events older than `retention` (180 days) and installs not seen for
as long, in batches of 10 000.

## Tables

| `dw_analytics_install` | |
|---|---|
| `install_id` | the app's id, primary key |
| `platform`, `app_version` | as of the last batch |
| `account_id` | the last account seen |
| `first_seen_at`, `last_seen_at`, `last_event_at`, `session_number` | |

| `dw_analytics_event` | |
|---|---|
| `name`, `source` (`app`/`server`), `properties` (jsonb) | |
| `occurred_at`, `received_at` | |
| `install_id`, `sequence`, `session_number` | app events only |
| `account_id`, `platform`, `app_version` | |

Indexed by `(name, occurred_at)`, `(account_id, occurred_at)`, `(install_id, occurred_at)` and
`received_at`.

```sql
-- daily active installs
SELECT occurred_at::date AS day, count(DISTINCT install_id)
FROM dw_analytics_event WHERE source = 'app' GROUP BY 1 ORDER BY 1;

-- a funnel: opened the catalog, then ordered, within a session
SELECT count(DISTINCT c.install_id) AS opened, count(DISTINCT o.install_id) AS ordered
FROM dw_analytics_event c
LEFT JOIN dw_analytics_event o ON o.install_id = c.install_id
  AND o.session_number = c.session_number AND o.name = 'orderPlaced' AND o.occurred_at >= c.occurred_at
WHERE c.name = 'catalogOpened';
```

## What it does not do yet

No reports or screens: the tables and SQL are the interface. No export to an outside service. No
screen views by route. Each is a later step once a project needs it.
