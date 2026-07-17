# Example — the layer both sides share

You rarely depend on this package directly: the server
([`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server)) and the
Flutter app
([`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter)) both
pull it in. It exists so the two halves format an alert and name a config key *the same way*,
instead of drifting apart.

## One sink, both halves

Configure the sink once, and the server and the app report the same way:

```dart
final alerts = DwAlerts.init(
  telegramConfig: DwTelegramAlertsConfig(
    alertsToken: token,
    alertsChatId: chatId,
  ),
);

alerts.sendMessage('Deploy finished');
```

With no `telegramConfig`, alerts degrade to logging: a fresh project stays quiet and runnable
instead of crashing on a missing token.

## Reporting an error with its context

An error report is useless if the channel mangles it, and nearly as useless if it arrives without
the app state around it. `reportError` renders both: every value is escaped for Telegram's
MarkdownV2, and the stack is trimmed to its top frames — the part that says where it broke, without
the forty lines that say how the framework got there.

```dart
alerts.reportError(
  'Booking failed',
  exception: error,
  stackTrace: stackTrace,
  context: DwAlertContext(
    route: '/bookings',
    actionLabel: 'Book a spot',
    userLabel: 'user 42',
    appVersion: '1.0.3',
  ),
);
```

In a DartWay app you rarely write this by hand — `DwCore` on the Flutter side already reports
uncaught errors, failed `dw.action`s and failed server calls through this sink, filling
`DwAlertContext` from the live app.

## Configuration keys

`DwTelegramAlertsKeys` names the keys `DwTelegramAlertsConfig.fromEnv` reads out of the server's
`config/passwords.yaml`, so a typo is a compile error rather than a `null` discovered in
production.
