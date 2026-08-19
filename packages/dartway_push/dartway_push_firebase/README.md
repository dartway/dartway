# dartway_push_firebase

Firebase Cloud Messaging as a transport for [`dartway_push_flutter`](https://pub.dev/packages/dartway_push_flutter) —
Android, iOS and web.

```dart
DwPush(
  config: DwPushConfig(
    providers: [DwFirebasePush(webVapidKey: kWebVapidKey)],
    // ...
  ),
)
```

Everything else — when to ask for permission, when the token goes to the server, what happens
between a tap and a screen — belongs to the core plugin. This package answers five questions about
FCM and nothing more.

## What the app still owns

- **`Firebase.initializeApp`** in `main()`, with your own `firebase_options.dart`. This transport
  refuses to guess your project: with no Firebase app initialized it stands aside and says so.
- **`DwFirebasePush.registerBackgroundHandler()`** right after that, before `runApp`. FCM wants the
  handler registered before the app starts.
- **`android/app/google-services.json`** and **`ios/Runner/GoogleService-Info.plist`**, plus the
  Google Services Gradle plugin. Standard FlutterFire setup.
- **Web:** copy `web/firebase-messaging-sw.template.js` from this package to your app's
  `web/firebase-messaging-sw.js` and fill in the config. Without it a closed tab shows nothing.
  **Copy it as it stands** — the handler is registered before `firebase.messaging()` and calls
  `stopImmediatePropagation()` on purpose: the SDK installs its own `notificationclick` listener
  in that call and stops propagation itself, so a handler placed after it never runs. Without the
  template a tap still reaches the right screen, through `webpush.fcm_options.link`, but in a new
  tab instead of the one already open. Pass `webVapidKey` — the browser issues no token without
  one.

## Notes that cost an afternoon each

- On **iOS** an FCM token exists only after APNs has registered the install. Before that
  `requestToken()` answers null, which is a "not yet": the core plugin picks the token up when the
  platform refreshes it.
- In the **foreground**, iOS shows nothing unless asked; this transport asks. Android draws its own.
- On **Android 13+** the notification permission is a runtime prompt, and `requestPermission()`
  raises it.

## Part of DartWay

[DartWay](https://dartway.dev) is a fullstack Dart framework (Flutter + Serverpod). The framework
lives in one [repository](https://github.com/dartway/dartway).
