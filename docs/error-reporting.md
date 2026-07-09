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
app) is picked up by `scanMountedFeatures()` at the moment of the error — the
alert names the features of the screen where it happened.

## Custom policy

Set `DwConfig.onErrorReport` to receive the full `DwErrorReport` (error,
stack, source, context snapshot) and route it anywhere — the out-of-the-box
alerting steps aside automatically. The legacy `globalErrorHandler`
(`(error, stackTrace)`) also disables it when overridden.

## Action labels and confirmations

`DwUiAction.create` now takes a `label` (names the action in reports;
notification texts are the fallback) and a `confirmation`:

```dart
DwUiAction.create(
  (_) => DwRepository.saveModel(user.copyWith(role: role)),
  label: 'changeUserRole',
  confirmation: DwUiConfirmation('Change the role of $name?'),
)
```

Declining the dialog skips the action, its notifications and follow-ups. The
dialog defaults to a themed `AlertDialog` (`DwConfirmDialog`); supply
`DwConfig.confirmDialogBuilder` for a custom UI.
