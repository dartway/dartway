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
| `where` | where it happened, without payload: `command BookSession`, `job invoice.send (attempt 5 of 5)`, `route POST /echo` |
| `error`, `stackTrace` | the exception |
| `accountId` | the caller, when a call had one |
| `at` | UTC |
| `signature` | `where`, the error's type and the first stack frame outside the SDK: identical failures share it |

## The ceiling per signature

Every incident is logged at error level (`incident <id> in <where>`), always. The alert sink gets at
most `DwServerSettings.alertsPerSignature` incidents of one signature (5) per `alertWindow` (one
hour). The last alert before the ceiling carries a note — "further alerts like this are muted until
…" — so the silence that follows is announced, not mysterious.

A failure repeating a thousand times is one problem; a channel flooded with it hides the next one.
The ceiling is in the process's memory, and it resets with a restart.

A second ceiling holds across signatures: at most `DwServerSettings.alertsPerMinute` (10) alerts a
minute. Many different failures at once — a dependency down under every command — would otherwise
exhaust the channel's own limit (Telegram's is 20 a minute per group) and lose the rest, including
the one that mattered, to its refusals. An incident past it is only logged, and the next alert that
goes out says how many were held back.

A sink that fails to deliver is logged as a warning and does not fail the call, nor create another
incident: an alert channel that is down must not turn into an incident loop.

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
  characters) and the first stack frame. Never a payload. A delivery failure is logged with its
  status or error type only, since the request URL holds the bot token.

```dart
final logger = const DwConsoleLogger();
final alerts = DwTelegramAlertSink(
  botToken: Platform.environment['ALERTS_BOT_TOKEN']!,
  chatId: Platform.environment['ALERTS_CHAT_ID']!,
  logger: logger,
  title: 'Invoices',
);
// DwAppServer(…, logger: logger, alerts: alerts)
```

A sink of the project's — a pager, an error tracker — implements `send`. It receives the incident
after it is logged, and only within the ceiling.

## `DwServerLogger`

One interface for the framework and for handlers, so a project that ships logs somewhere replaces
one object and sees everything:

```dart
abstract interface class DwServerLogger {
  void log(DwLogLevel level, String message, {Object? error, StackTrace? stackTrace});
  DwServerLogger scoped(String scope);
}
```

`debug`, `info`, `warning` and `error` are extension methods over `log` (`DwLoggerLevels`).
`DwLogLevel` has those four values.

`DwConsoleLogger({minLevel: DwLogLevel.info, scope})` is the default: one line per entry with a UTC
timestamp, level and scope, to stdout below warning and to stderr from warning up, plus the stack
trace when there is one. Pass another logger as `DwAppServer(logger: …)`.

`ctx.log` is the server's logger scoped to the call — `command BookSession`, `job invoice.send #42`,
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
