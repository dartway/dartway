## 0.1.0

First release: FCM behind the `DwPushClientProvider` contract.

- Tokens (with the APNs wait on iOS and the VAPID key on web), permissions, foreground
  presentation on iOS, taps from background and cold start.
- Web click handling: a service worker template whose `notificationclick` focuses the open tab and
  hands the path to the app instead of opening a second one.
- Stands aside with a clear message when no Firebase app was initialized, rather than guessing a
  project.
