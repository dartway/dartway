# dartway_serverpod_core_shared

The pure-Dart shared layer of the [DartWay](https://dartway.dev) core — code
that must behave identically on the server and in the Flutter app:

- **Alerts** — `DwAlerts` reports a runtime error from either half through one
  sink (Telegram today), with `DwAlertContext` carrying the app state around
  the failure: route, features, action, platform, user. Messages arrive
  MarkdownV2-safe, with the stack trimmed to its top frames.
- **The wire contract** — `DwCoreConst`: the API and column names the server
  and the client must spell identically, in one place instead of two.

Used by
[`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server)
and
[`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter);
apps rarely depend on it directly — it arrives with either of those.

Part of the [DartWay monorepo](https://github.com/dartway/dartway).
