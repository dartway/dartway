# dartway_push_flutter

Push notifications for a DartWay app, reached as `dw.plugins.push`. No vendor SDK: add
`dartway_push_firebase` and/or `dartway_push_rustore`.

```dart
plugins: [DwSharedPreferences(), DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)])],
```

- registers the device token with the server whenever the token or the signed-in account changes,
  once per pair; a sign-out needs no call (the server binds the device to the session key);
- `requestPermission()`, `permission()`, `pause()` / `resume()`;
- `opened` — notifications the user opened, with the typed payload (`payloadAs<T>()`) and link; the
  one that started the app waits for the first listener; `received` — those that arrived on screen.

`package:dartway_push_flutter/testing.dart` has `DwFakePushTransport` for widget tests.

Documentation: `docs/3-flutter/push-notifications.md`.
