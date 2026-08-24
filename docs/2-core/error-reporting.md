# Error reporting & alerts

A web stack trace is minified noise — `main.js` all the way down. DartWay
alerts are built around **app-state context** instead: every reported error
carries the current route, the product features mounted on the screen, the
failed action or server call, the platform, app version and user.

```
❌ Error
Failed call: faq.deleteQuestion

📌 Exception
PostgreSQLException: relation "faq" does not exist

🖥 web/android · v1.4.2 · user 42
📍 /admin/help
🧩 faq-admin, admin-shell
⚡ Call: faq.deleteQuestion

📜 StackTrace (top 8)
...
```

## Out of the box

With a standard `DwCore` setup there is nothing to install. Every error that
reaches the framework — an uncaught zone error, a failed `DwUiAction`, an
`AsyncValue` error branch, a failed server call — flows into one pipeline:

1. `dw.handleError` captures a context snapshot (`dw.errorContext`).
2. `DwCore.reportError` filters connection blips (they are UX, not alerts),
   dedupes the double report of a failed call, and sends the alert through
   `DwAlerts` — to Telegram when `DwTelegramAlertsConfig` is set, to the log
   otherwise.

Two one-time wirings in the app make the context rich:

```dart
// The framework has no access to your router — register the route source:
dw.errorContext.registerRouteSource(
  () => router.routerDelegate.currentConfiguration.uri.path,
);

// Failed server calls report endpoint.method and show a network toast:
Client(url, onFailedCall: dwReportingOnFailedCall(
  onConnectionError: (_, _) => dw.notify.error('Network error'),
));
```

Custom entries join every report: `dw.errorContext.set('tenant', 'acme')` or
`dw.errorContext.register('cart', () => cart.id)`.

Features come for free: any widget implementing `DwFeature` (see the example
app) is picked up by `DwFeature.scanMounted()` at the moment of the error — the
alert names the features of the screen where it happened.

## Sending them to Telegram

The sink is configured once, where `DwCore.init` is called on the server:

```dart
dwAlerts: DwAlerts.init(
  telegramConfig: DwTelegramAlertsConfig.fromEnv(env: passwords),
  httpClient: DwProxyHttpClient.fromEnv(env: passwords),
),
```

Both read `config/passwords.yaml`, and both return `null` when their keys are
absent — a project with no bot token logs its alerts instead of failing to
boot.

```yaml
production:
  dwTelegramAlertsToken: '123456:ABC-DEF...'
  dwTelegramAlertsChatId: '-1001234567890'
  dwTelegramAlertsMessageThreadId: '42'   # optional, a topic in the group
  dwTelegramAlertsProxyUrl: 'http://user:pass@10.0.0.5:3128'  # optional
```

`DwTelegramAlertsKeys` names all four in code, so a typo is a compile error
rather than a `null` discovered in production.

### When the server cannot reach Telegram

`dwTelegramAlertsProxyUrl` is for hosts whose outbound access to
`api.telegram.org` is blocked — which is the normal state of a Russian
production host, and of plenty of corporate networks. `DwProxyHttpClient.fromEnv`
turns the URL into the client every alert is then sent through; credentials are
optional, and a value that is not a proxy URL is logged and ignored rather than
taken down with the boot.

The failure it prevents is worth naming, because it does not look like a
network failure. A firewall that **drops** packets instead of refusing them
leaves the connection hanging rather than failing it, so every alert holds a
socket open until the platform gives up minutes later. A server reporting errors
in bursts — which is exactly when it is reporting errors — runs out of sockets,
and the symptom shows up somewhere else entirely. Alerts carry their own
deadline for that reason (10 seconds), proxy or no proxy.

## A refusal is not an error

A rule on the server saying no — `validateSave` returning its text, an action
throwing `DwActionRejection`, `allowSave` refusing — comes back as a
`DwApiResponse` marked `isRefusal`, and `dw.repo` raises it as a **`DwRefusal`**
rather than as an ordinary exception. Three things follow, none of which the app
has to arrange:

- **the user reads the rule's own words.** `dw.action` shows `refusal.message`
  instead of its generic `onErrorNotification` — "This message was already
  deleted" rather than "Could not delete";
- **the alert channel stays quiet.** The out-of-the-box policy steps over a
  refusal the way it steps over connection blips: a rule doing its job is not an
  incident, and twenty of them in two days is how one production channel stopped
  being read;
- **a custom policy still sees it**, and sorts it out by type instead of by
  matching the message:

  ```dart
  onErrorReport: (report) {
    if (report.error is DwRefusal) return; // the user has already been told
    mySentry.capture(report.error, report.stackTrace);
  },
  ```

An app can throw one itself for a rule of its own — `throw const DwRefusal('This
file is larger than 10 MB')` — and get the same treatment. Write the message for
a user: it reaches the screen unedited.

Everything else is unchanged, and deliberately so: a `DatabaseException`, an
exception the server's guard caught, or a call the server has no config for
still arrive as ordinary exceptions and are still reported.

## Custom policy

Set `DwConfig.onErrorReport` to receive the full `DwErrorReport` (error,
stack, source, context snapshot) and route it anywhere — the out-of-the-box
alerting steps aside automatically. The legacy `globalErrorHandler`
(`(error, stackTrace)`) also disables it when overridden.

## Action labels and confirmations

`dw.action(...)` — the only way to build a `DwUiAction`; its constructor is
private — takes a `label` (names the action in reports; notification texts are
the fallback) and a `confirmation`:

```dart
dw.action(
  (_) => dw.repo.saveModel(user.copyWith(role: role)),
  label: 'changeUserRole',
  confirmation: DwUiConfirmation('Change the role of $name?'),
)
```

Declining the dialog skips the action, its notifications and follow-ups. The
dialog defaults to a themed `AlertDialog` (`DwConfirmDialog`); supply
`DwConfig.confirmDialogBuilder` for a custom UI.
