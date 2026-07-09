# dartway_serverpod_core_shared

The pure-Dart shared layer of the [DartWay](https://dartway.dev) core — code
that must behave identically on the server and in the Flutter app:

- **Alerts** — `DwAlerts` (Telegram error reporting), `DwAlertContext` and
  `DwAlertFormatter`: MarkdownV2-safe alert messages with structured app
  context (route, features, action, platform, user) and a trimmed stack.
- **Configuration keys** and cross-stack utilities.

Used by
[`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server)
and
[`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter);
apps rarely depend on it directly — it arrives with either of those.

Part of the [DartWay monorepo](https://github.com/dartway/dartway).
