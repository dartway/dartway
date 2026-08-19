## 0.1.1

- **The service worker template's `notificationclick` handler now runs.** It sat
  after `firebase.messaging()`, and the listener the SDK installs in there stops
  propagation — so ours never fired, on any browser: a tap opened the app at its
  root with nothing in the console to say why. It is registered first now and
  stops the SDK's the same way. 0.1.0 described this behaviour; this is the
  release that has it.

## 0.1.0

First release: FCM behind the `DwPushClientProvider` contract.

- Tokens (with the APNs wait on iOS and the VAPID key on web), permissions, foreground
  presentation on iOS, taps from background and cold start.
- Web click handling: a service worker template whose `notificationclick` focuses the open tab and
  hands the path to the app instead of opening a second one.
- Stands aside with a clear message when no Firebase app was initialized, rather than guessing a
  project.
