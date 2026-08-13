# dartway_push_flutter

The app half of DartWay push — `dw.plugins.push`.

Receiving a notification is a vendor SDK call. Everything around it is not: which transport this
device can actually use, when to ask for permission, keeping the server's copy of the token in step
with the platform's while the user signs in and out, and making sure a tap opens the right screen
exactly once whether the app was cold, backgrounded or already on screen. This package owns that
part, and it carries **no vendor SDK at all**.

The transports arrive separately, so an app downloads only the ones it ships:

| Package | Transport |
|---|---|
| [`dartway_push_firebase`](https://pub.dev/packages/dartway_push_firebase) | FCM — Android, iOS, web |
| [`dartway_push_rustore`](https://pub.dev/packages/dartway_push_rustore) | RuStore — Android |

## Wiring

```dart
dw = DwCore<Client, UserProfile>(
  // ...
  plugins: [
    DwPush(
      config: DwPushConfig(
        providers: [DwRuStorePush(), DwFirebasePush()],
        recipientIdProvider: dw.userProfileProvider.select((p) => p?.id),
        onOpened: (opened) => appRouter.go(routeFor(opened.data)),
      ),
    ),
  ],
);
```

Then wrap the app: `DwPushScope(push: dw.plugins.push, child: MaterialApp.router(...))`.

**Declaration order is the policy.** The first transport that both builds for this platform and
answers for itself on this device wins — so the pair above means RuStore on Android, FCM on iOS and
web, with no platform switch anywhere. An app that only knows FCM declares one.

## What it does not do

It does not navigate. It hands you `onOpened` with the notification's data map and the guarantee
that it fires once, after a frame, however the app was launched; turning that map into a screen is
the app's business, because the payload keys and the routes are the app's.

It does not decide when to ask for permission, either. `requestPermissionOnAttach: false` plus
`dw.plugins.push.requestPermission()` lets you ask after the moment that makes the ask make sense.

## Signing out

Call `dw.plugins.push.revokeToken()` **before** you sign out, while the session is still valid —
afterwards there is nobody to authenticate the call, and the device would keep receiving the
previous user's notifications.

## Part of DartWay

[DartWay](https://dartway.dev) is a fullstack Dart framework (Flutter + Serverpod). The server half
of push is [`dartway_push_server`](https://pub.dev/packages/dartway_push_server); both live in the
same [repository](https://github.com/dartway/dartway).
