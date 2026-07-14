# Changelog

## 0.1.0

First public release — the pure-Dart layer both halves of the DartWay core share, so that the server
and the Flutter app format an alert and name a config key the same way instead of drifting apart.

- `DwAlerts` — the alert sink, with Telegram delivery. Without a config it degrades to logging, so a
  fresh project stays runnable instead of crashing on a missing token.
- `DwAlertFormatter` + `DwAlertContext` — MarkdownV2-safe messages with structured app context and a
  stack trace trimmed to its top frames: the part that says where it broke, without the forty lines
  that say how the framework got there.
- Configuration keys and cross-stack utilities.

You do not usually depend on this package directly — the server and Flutter core packages both pull
it in.
