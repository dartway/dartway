# dartway_push_firebase

Firebase Cloud Messaging as a transport of `dartway_push_flutter` — Android, iOS and web.

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
DwFirebasePush.registerBackgroundHandler();
// ...
DwPush(transports: [DwFirebasePush(webVapidKey: webVapidKey)])
```

What the app still owns: `Firebase.initializeApp` and its `firebase_options.dart`,
`google-services.json` / `GoogleService-Info.plist`, and on the web a copy of
`web/firebase-messaging-sw.js` from this package with the Firebase config filled in.

**Copy the service worker as it stands.** Its click handler is registered before the Firebase SDK
is loaded and stops the SDK's own — which calls `stopImmediatePropagation()`, so a handler added
after it never runs (#78). With the app open it focuses the tab and hands over the link; with the
app closed it opens the link. The package's test runs the template in Node and clicks.

Notes: on iOS a token exists only after APNs registered the install (`token()` answers `null`
until then, and the refresh brings it); iOS shows foreground notifications because this transport
asks it to; on Android 13+ `requestPermission()` raises the runtime prompt.
