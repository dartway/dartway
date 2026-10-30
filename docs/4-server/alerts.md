# Alerts: what does the operator hear about, and what stays an answer?

**A refusal is an answer; a failure is an incident.** A booking refused because the session is full
is the server working — the user sees why, and nobody is woken up. A handler that throws a
`StateError` is the server broken — the user sees only that something went wrong, with an id, and
the operator hears about it with everything needed to find it.

Keeping the two apart is what keeps alerts worth reading. A channel that rings on every refusal is
a channel people mute, and then the real failure goes unheard.

## What is a failure

| Where | Reported as |
|---|---|
| a request or command handler throws anything but a refusal or `DwNotAuthenticatedException` | `500`, `{"status":"failed","incidentId":"…"}`, alert |
| a result that cannot be encoded to JSON | the same |
| a route throws anything but a body error, a refusal or `DwNotAuthenticatedException` | `500`, `{"incident":"…"}`, alert |
| a channel subscription check throws | the subscription fails with an incident id, alert |
| resolving the token of a live socket fails | the socket closes with the incident id, alert |
| a queued job's **last** attempt fails | the row is marked failed, alert; earlier attempts are warnings |
| a recurring job fails | alert, and it waits for its next slot |
| the job executor itself fails | alert |

Not failures, never alerted:

- **refusals** — `ctx.refuse`, validation, access checks, `dw.notFound`: answers, with their own
  statuses ([refusals and statuses](../2-core/refusals-and-statuses.md));
- **malformed calls** (`400`) and **unknown calls** (`404`) — a client bug or a client built against
  another protocol. They still get an incident id in the answer and a warning line in the log with
  the same id, so a report from a user can be matched — but no alert;
- a missing or revoked session (`401`).

A database exception escaping a handler is a failure like any other. A conflict the user can cause
— a unique value already taken — should be decided in the handler and refused, not left to escape
as a `DwUniqueViolation` ([database](database.md#errors)).

## `DwServerIncident`

| Field | |
|---|---|
| `id` | 12 characters, short enough to read aloud; what the client received as `incidentId` |
| `where` | where it happened, without payload: `command BookSession`, `job invoices.send (attempt 5 of 5)`, `route POST /echo` |
| `error`, `stackTrace` | the exception |
| `accountId` | the caller, when a call had one |
| `at` | UTC |
| `signature` | `where`, the error's type and the first stack frame outside the SDK: identical failures share it |

## Durable outbox and coalescing

Every incident is logged at error level (`incident <id> in <where>`), always. It is then written to
`dw_alert_outbox` using the database pool, not the failed call's transaction. A rollback therefore
cannot roll back its alert. If Postgres is temporarily unavailable, up to 1,000 incidents wait in a
bounded process buffer; shutdown tries to flush that buffer before closing the database.

The first incident of a signature in `DwServerSettings.alertWindow` (one hour) is eligible for
delivery immediately. Further incidents update the persisted row's `repeat_count`. At the end of
the window the outbox sends one follow-up — `repeated N times since …` — when `N` is non-zero. Thus
1,000 identical failures produce the original and one follow-up for 999 repeats, including across
restarts and across server instances.

Workers claim rows with a two-minute database lease. A failed delivery is retried with exponential
backoff capped at one hour. Rows older than seven days are discarded; the receiver must use the
`(id, kind)` pair as its deduplication key because a process can stop after the receiver accepts a
request but before the acknowledgement is recorded.

A database outage itself cannot be delivered through an outbox stored in that database. `/health`
checks the database and must be watched by an external probe.

A second ceiling holds across signatures per server instance: at most
`DwServerSettings.alertsPerMinute` (10) alerts a minute per instance. Many different failures at
once — a dependency down under every command — would otherwise exhaust the channel's own limit
(Telegram's is 20 a minute per group) and lose the rest, including the one that mattered, to its
refusals. Rows beyond the ceiling remain queued for a later minute.

A sink failure stays in the outbox and does not fail the call or create another incident.

## Sinks

`DwAppServer(alerts: …)` takes a `DwAlertSink`:

```dart
abstract interface class DwAlertSink {
  Future<void> send(DwServerIncident incident, {String? suppressedNote});
}
```

- **`DwLogAlertSink(logger)`** — the default: an `ALERT incident <id> in <where>` line at error
  level. Enough when logs are watched; nothing reaches a person otherwise.
- **`DwTelegramAlertSink(botToken:, chatId:, logger:, title: 'DartWay', apiBase:)`** — a message to
  a Telegram chat through a bot: the title, the incident id, `where`, the error text (cut at 1500
  characters) and the first stack frame. `proxyUrl` routes Telegram through an HTTP proxy.
- **`DwHttpAlertSink(url:, token:)`** — JSON over HTTP with `Authorization: Bearer <token>`. Every
  2xx response acknowledges delivery; every other response or transport failure is retried.

### HTTP payload contract (STD-E11)

The request body is one JSON object. The contract fields are:

| Field | JSON type | Meaning |
|---|---|---|
| `id` | string | Stable incident id. Retries and its repeat follow-up keep it unchanged. |
| `kind` | string | `incident` for the first delivery or `repeat` for its follow-up. The receiver's **deduplication key is `(id, kind)`**. |
| `where` | string | Framework location, without request payloads. |
| `error` | string | Exception text; for a follow-up, `repeated N times since …`. |
| `stackTrace` | string | Recorded Dart stack trace. |
| `accountId` | integer or null | Authenticated framework account, if any. |
| `at` | string | Original incident time, UTC ISO 8601. |
| `signature` | string | Location, error type and first useful frame. |
| `repeatCount` | integer | `0` for the first delivery; number of repeats for the follow-up. |
| `project` | string or null | Configured project name. |
| `environment` | string or null | Configured deployment environment. |
| `version` | string or null | Immutable deployment version. |

### Queue observation

An external probe can read both backlog facts in one query (delivered rows are excluded):

```sql
SELECT count(*) AS undelivered,
       EXTRACT(EPOCH FROM (now() - min(
         CASE WHEN initial_delivered_at IS NULL
              THEN created_at ELSE window_ends_at END
       )))::bigint AS oldest_seconds
FROM dw_alert_outbox
WHERE initial_delivered_at IS NULL
   OR (repeat_count > 0 AND repeat_delivered_at IS NULL
       AND window_ends_at <= now());
```

### Configuration

No project alert code is required. The template passes `DwServerEnvironment.alerts` to the server.
Set either `DW_ALERT_HTTP_URL` plus the secret `DW_ALERT_HTTP_TOKEN`, or
`DW_TELEGRAM_ALERTS_BOT_TOKEN` plus `DW_TELEGRAM_ALERTS_CHAT_ID`. A Russian-host deployment can
also set `DW_TELEGRAM_ALERTS_PROXY_URL`. Declare secret names under the destination's
`requires.secrets` in `deploy/config.yaml` and store their values with `dartway secret set`; never
commit the token.

A custom pager or error tracker can still implement `DwAlertSink`; it receives leased outbox
deliveries and must throw when the delivery was not accepted so that the row is retried.

## `DwServerLogger`

One interface for the framework and for handlers, so a project that ships logs somewhere replaces
one object and sees everything:

```dart
abstract interface class DwServerLogger {
  bool isEnabled(DwLogLevel level);
  void log(DwLogLevel level, String message, {Object? error, StackTrace? stackTrace});
  DwServerLogger scoped(String scope);
}
```

`debug`, `info`, `warning` and `error` are extension methods over `log` (`DwLoggerLevels`).
`DwLogLevel` has those four values. `isEnabled` reports the effective filter, including on
scoped loggers, so a caller can skip constructing a disabled line.

`DwConsoleLogger({minLevel: DwLogLevel.info, scope})` is the default: one line per entry with a UTC
timestamp, level and scope, to stdout below warning and to stderr from warning up, plus the stack
trace when there is one. Pass another logger as `DwAppServer(logger: …)`.

`ctx.log` is the server's logger scoped to the call — `command BookSession`, `job invoices.send #42`,
`route POST /echo` — so a handler's lines say where they come from without saying it.

**Never log codes, tokens or DTO contents.** The framework logs type names and ids only. A handler
that logs a secret has leaked it to whoever reads the logs.

## Incident ids on the wire

A failed call is answered `{"status":"failed","incidentId":"…"}` with `500` — no message, no stack,
no type: an exception's text was written for the operator and may carry a query, a path or a
secret. The client receives it as `DwCallFailed` (`DwFailedException` in a Flutter data layer), and
the app can show the id for the user to quote. Search the logs for it: the incident line and every
alert carry the same id. See [error reporting](../3-flutter/error-reporting.md).

## Related

- [Handlers and the call context](handlers-and-context.md) — where refusals come from.
- [Jobs](jobs.md) — attempts, backoff, and when a job alerts.
