# Changelog

## 0.1.0

First public release — the pure-Dart layer both halves of the DartWay core share, so that the server
and the Flutter app format an alert and name a config key the same way instead of drifting apart.

- `DwAlerts` — the alert sink, with Telegram delivery. Without a config it degrades to logging, so a
  fresh project stays runnable instead of crashing on a missing token.
- `DwAlertContext` — the app state around a failure (route, features, action, platform, user).
  Messages arrive MarkdownV2-safe, with the stack trimmed to its top frames: the part that says
  where it broke, without the forty lines that say how the framework got there.
- `DwTelegramAlertsConfig` (and `DwTelegramAlertsKeys`, the `passwords.yaml` names it reads).
- `DwCoreConst` — the wire contract: the API and column names the server and the client must spell
  identically, in one place instead of two.

You do not usually depend on this package directly — the server and Flutter core packages both pull
it in.
