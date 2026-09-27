# How does a DartWay project record what people do in the app?

With the analytics module: `DwAnalyticsModule` on the server (`dartway_analytics_server`) and the
`DwAnalytics` plugin in the app (`dartway_analytics_flutter`). Events are stored in the project's
own Postgres — nothing goes to a third party — and read as reports, on dashboards the team builds
in the admin panel, or with SQL.

```dart
// shared: the project's events, by name
enum ShopEvent with DwAnalyticsEvent { catalogOpened, productViewed, orderPlaced }

// both sides: the protocol knows DwTrackEvents
final appProtocol = DwWireProtocol(dwAnalyticsProtocolEntries, include: shopProtocol);

// server: who reads reports and dashboards is the project's rule
DwAppServer(
  protocol: appProtocol,
  modules: [DwAnalyticsModule(readAccess: AppAccess.admin)],
  ...,
);

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

## Reports

`DwGetAnalyticsReport` counts one thing over a period and answers a `DwAnalyticsReport`: a `total`
and the `points` of a breakdown.

```dart
// "saw quiz step N": distinct accounts, by question number
final funnel = DwGetAnalyticsReport(
  spec: const DwAnalyticsReportSpec(
    eventName: 'quizStepSeen',
    metric: DwAnalyticsMetric.accounts,
    filters: [DwAnalyticsFilter(property: 'quiz', value: 'onboarding')],
    breakdown: DwAnalyticsBreakdown.byProperty('question_number', top: 10),
  ),
  period: DwAnalyticsPeriod.localDays(firstDay, lastDay),
);
ref.watch(dw.request(funnel));
```

- **What is counted** (`DwAnalyticsMetric`): `events`; `accounts` — distinct signed-in accounts,
  people; `installs` — distinct installs, devices. `eventName: null` counts every event: installs
  over any event is "active devices".
- **Filters** (`DwAnalyticsFilter`) are `property = value`, all of them together. A property is
  compared as the text of its JSON value, so `'3'` matches the number 3 and the string "3", and
  `'true'` the boolean.
- **Breakdown** (`DwAnalyticsBreakdown`): none; by time — `day`, `week` (from Monday) or `month`,
  every bucket of the period with the empty ones as zero, labelled `YYYY-MM-DD` by its first day;
  or by a property — the first `top` values (at most 30) in the breakdown's `order`, events
  without the property under a `null` label, and the rest together as `other`, counted by the
  same metric (one person across many hidden values is one in `other`).
  `DwAnalyticsBreakdownOrder.largestFirst` (the default) keeps the largest values;
  `byLabel` keeps them in their own order — numbers numerically and before text, the missing
  value last — which is how a funnel reads: `question_number` 1, 2, …, 10, not 1, 10, 2.
- **The period** (`DwAnalyticsPeriod`) runs from `from` (included) to `to` (excluded), bucketed in
  the calendar `utcOffsetMinutes` east of UTC — the viewer's, so a day is the viewer's day.
  `DwAnalyticsPeriod.localDays(first, last)` builds it from local dates and never past now, so
  "the last 7 days" read at 09:00 ends at 09:00 today. `.previous`, what a change is measured
  against, is the same period moved back by the whole days it spans: six days and a morning
  against the six days and morning a week earlier, not against seven whole days.
- A distinct count is counted over the whole period: a person active on three days is one in the
  total and one on each day, so the total is not the sum of the points.

One parametrised statement over `dw_analytics_event`, on the `(name, occurred_at)` index — or
`occurred_at` for every event. Event names and property keys are checked by the rules events are
stored by before anything runs (`dw.analyticsReportInvalid`); nothing from the call reaches the
statement's text.

`DwGetAnalyticsCatalog` answers the event names recorded in a period, how many of each, and every
property key each carried — what a report builder offers instead of free text.

## Dashboards

A dashboard (`DwAnalyticsDashboard`) is a title and its widgets in order, kept in
`dw_analytics_dashboard`; a widget (`DwAnalyticsWidgetSpec`) is a report spec, a title and a type —
`indicator` (the total, optionally with its change against the previous period), `bar` or `pie`.
A pie counts events broken down by a property — each event has one value, so the slices add up;
distinct people or devices overlap between values (someone who saw steps 1 and 2 is in both) and
are refused for a pie (`dw.analyticsDashboardInvalid`), while bars show them.
The period is not part of a dashboard: the viewer chooses it on top. Dashboards belong to the
project, not to whoever saved them. `DwListAnalyticsDashboards` lists them;
`dw.plugins.analytics.saveDashboard(id:, title:, widgets:)` creates or replaces one and
`deleteDashboard(id)` removes it — both read the list again for every screen watching it, since
the module has no channel to announce a change. At most 12 widgets.

The framework draws none of it: it ships no design. The viewer is source in the skeleton,
`lib/admin/analytics/` of the app — a period filter, the three widget types drawn by the UI kit's
`AppStatValue`, `AppBarChart` and `AppPieChart`, and a builder that adds, edits, moves and removes
widgets — the project's to change like any other screen. A project created before it copies the
folder, the kit's `ui_kit/3_special/charts/` and the strings from `template/` in the DartWay
repository.

## Who reads

The framework knows accounts, not roles, so the rule is the project's:

```dart
DwAnalyticsModule(
  readAccess: AppAccess.admin,      // reports, the catalog, the dashboard list
  editAccess: AppAccess.admin,      // saving and deleting dashboards; readAccess when omitted
)
```

Without `readAccess` every read is refused `dw.forbidden`, and a signed-out caller is asked to sign
in. `DwAccessRule.anonymous` for either rule stops the server at start: what the app records is not
for everyone. `DwTrackEvents` stays open to a signed-out app.

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

Indexed by `(name, occurred_at)`, `occurred_at`, `(account_id, occurred_at)`,
`(install_id, occurred_at)` and `received_at`.

| `dw_analytics_dashboard` | |
|---|---|
| `id`, `title` | |
| `widgets` (jsonb) | the widgets in order, each the JSON of a `DwAnalyticsWidgetSpec` |
| `created_at`, `updated_at` | |

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

Reports count one event at a time: a funnel is read step by step (a breakdown by the step's
property, or one widget per step), not as a sequence within a session — that is still SQL, as
above. No retention cohorts, no comparisons of two properties at once, no export to an outside
service, no screen views by route, no dashboard per person. Dashboards are not live: a change made
elsewhere shows on the next read. Each is a later step once a project needs it.

On a large table: a property filter or breakdown reads `properties` of every event of the period
— no index serves a JSON key, so a report is as fast as the period's `(name, occurred_at)` or
`occurred_at` range is small. The `occurred_at` index is built by the module's migration at
start, in its transaction and not `CONCURRENTLY`: on a project with millions of events already
stored, that start holds a write lock on `dw_analytics_event` while the index builds.
