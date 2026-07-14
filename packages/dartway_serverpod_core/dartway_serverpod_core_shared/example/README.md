# Example — the layer both sides share

You rarely depend on this package directly: the server
([`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server)) and the
Flutter app
([`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter)) both
pull it in. It exists so the two halves format an alert and name a config key *the same way*,
instead of drifting apart.

## Alerts that survive Telegram's formatter

An error report is useless if the channel mangles it. `DwAlertFormatter` produces MarkdownV2-safe
text with the stack trace trimmed to its top frames — the part that says where it broke, without the
forty lines that say how the framework got there.

```dart
final message = DwAlertFormatter.formatErrorReport(
  errorMessage: 'Booking failed',
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

Both sides send through the same sink:

```dart
final alerts = DwAlerts.init(
  telegramConfig: DwTelegramAlertsConfig(
    alertsToken: token,
    alertsChatId: chatId,
  ),
);

alerts.sendMessage('Deploy finished');
alerts.sendError(message);
```

With no `telegramConfig`, alerts degrade to logging: a fresh project stays quiet and runnable
instead of crashing on a missing token.

## Configuration keys

`DwConfigurationKeys` names the keys the server reads out of `config/passwords.yaml`, so a typo is a
compile error rather than a `null` discovered in production.
