# dartway_serverpod_core_flutter

The Flutter side of the [DartWay](https://dartway.dev) core: a typed realtime
data layer over the DartWay Serverpod module, plus sessions and
context-rich error alerting.

- **Data layer in one line** —
  `ref.watchModelList<NewsPost>()` gives a typed live list: realtime sync,
  pagination, filters and skeleton loading states out of the box.
  `watchModel` / `readModel` / `saveModel` / `deleteModel` cover the rest —
  no service wrappers, no manual sockets.
- **Sessions** — passwordless auth flow on the app's own user model,
  session survives restarts via the authentication key manager.
- **Out-of-the-box alerting** — errors are reported with app context
  (current route, mounted features, failed action or `endpoint.method`,
  platform, app version, user) instead of a minified web stack trace.
  Pass a configured `DwAlerts` into `DwCore` and it just works; custom
  policies plug in via `DwConfig.onErrorReport`.
- **Connection-aware error handling** — network blips become toasts, not
  alerts (`dwReportingOnFailedCall`, streaming error classifier).

## Quick start

```dart
final dw = DwCore<Client, UserProfile>(
  config: DwConfig(defaultModelGetter: DwRepository.getDefault, appVersion: '1.0.0'),
  client: Client(
    backendUrl,
    onFailedCall: dwReportingOnFailedCall(
      onConnectionError: (_, _) => dw.notify.error('Network error'),
    ),
  )..authKeyProvider = DwAuthenticationKeyManager(),
  dwAlerts: DwAlerts.init(telegramConfig: myAlertsConfig),
  getUserId: (userProfile) => userProfile?.id,
);
```

```dart
// A live list in a widget:
ref.watchModelList<NewsPost>().dwBuildListAsync(
  loadingItemsCount: 5,
  childBuilder: (posts) => ListView(...),
);
```

This package re-exports [`dartway_flutter`](https://pub.dev/packages/dartway_flutter)
(app shell, notifications, UI kit) — one import covers the standard app
surface. The backend counterpart is
[`dartway_serverpod_core_server`](https://pub.dev/packages/dartway_serverpod_core_server).

See the canonical example app in the
[DartWay monorepo](https://github.com/dartway/dartway) (`example/`).
