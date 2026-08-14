# Push on the device

Receiving a notification is one SDK call. Everything around it is not, and that
is where the afternoons go: which transport this device can actually use, when to
ask for permission without being refused, keeping the server's copy of the token
in step with the platform's while people sign in and out, and making sure a tap
opens the right screen exactly once — whether the app was cold, backgrounded, or
already on screen.

DartWay puts that part in **`dartway_push_flutter`**, reached as
`dw.plugins.push`. It carries **no vendor SDK at all**; the transports are
separate packages, so an app downloads only what it ships:

| Package | Transport |
|---|---|
| `dartway_push_firebase` | FCM — Android, iOS, web |
| `dartway_push_rustore` | RuStore — Android |

The other half — the queue, the retries, the fan-out — is
[`dartway_push_server`](../4-server/push-delivery.md).

## Wiring

```dart
dw = DwCore<Client, UserProfile>(
  // ...
  plugins: [
    DwPush(
      config: DwPushConfig(
        providers: [DwRuStorePush(), DwFirebasePush(webVapidKey: kVapidKey)],
        onOpened: (opened) => appRouter.go(routeFor(opened.data)),
      ),
    ),
  ],
);
```

and then, around the app's root:

```dart
DwPushScope(push: dw.plugins.push, child: MaterialApp.router(...))
```

The scope exists because nothing about push can happen at bootstrap: a permission
prompt needs a screen to belong to, and a notification tap needs an app to reach.

## Declaration order is the policy

The first transport that both builds for this platform and answers for itself on
this device wins. The pair above therefore means RuStore on Android, FCM on iOS
and web — and on an Android phone without the RuStore app, FCM there too. There
is no platform switch in your code and none in the plugin; the list is the whole
rule. An app that only knows FCM declares one entry.

## It does not navigate

`onOpened` hands you the notification's data map and one guarantee: it fires
**once per tap, after a frame**, however the app was launched. Turning that map
into a screen is yours, because the keys and the routes are yours.

The guarantee is less obvious than it looks. A cold start delivers the tap before
there is anything to route it into, so the plugin holds it until the app says it
is ready. And a tap while the app is already on screen changes no widget — so
Flutter schedules no frame, a post-frame callback would simply wait, and the
navigation would land minutes later on an unrelated gesture. The plugin asks for
that frame itself.

## Permission, at a moment that makes sense

By default the plugin asks as soon as it attaches, which is honest for an app
whose whole point is notifications. For everything else:

```dart
DwPushConfig(requestPermissionOnAttach: false, /* ... */)
// later, after the first order / at the end of onboarding:
final permission = await dw.plugins.push.requestPermission();
```

A refusal is an answer, not an error: the transport stays attached, so a user who
changes their mind in the system settings becomes reachable without restarting
the app. `DwPushPermission.permanentlyDenied` is the only state where asking
again does nothing — send them to the settings screen instead.

## The token, and signing out

The token and the signed-in user arrive independently and in either order, so the
plugin sends the pair whenever both exist, once, and re-sends when either
changes. Registration goes through the push module's CRUD action; an app on
somebody else's backend passes `registerToken:` instead.

**Who the token belongs to is not something you configure.** The plugin takes
`dw.signedInUserIdProvider` at `init`, and that is not a convenience: the
registration carries a token and a provider, never an id, so the recipient the
server writes down is the one it derives from the authenticated call. The
session is that same identity — the two sides therefore agree by construction,
and there is no second source to keep in step.

On the client the id is local bookkeeping only: whether there is anybody to
register a token for, whether this exact registration has already been made, and
whether a sign-out invalidated it. Which is why an app that supplied its own is
not redirecting notifications — it is only desynchronizing that bookkeeping from
what the server recorded, and the symptom shows up as push going quiet after an
account switch.

`DwPushConfig.recipientIdProvider` remains for the one app whose DartWay session
is permanently empty because it authenticates through an
`AuthenticationKeyManager` of its own. What it passes must mirror the identity
its calls are authenticated as.

**Call `dw.plugins.push.revokeToken()` before signing out**, while the session is
still valid. Afterwards there is nobody to authenticate the call, and the device
keeps receiving the previous user's notifications until the server happens to
find out.

## What stays in the app

The native setup, because it is about your project, not about the framework:
`Firebase.initializeApp` and `DwFirebasePush.registerBackgroundHandler()` in
`main()`, `google-services.json` / `GoogleService-Info.plist`, the web service
worker (there is a template in `dartway_push_firebase`), and the RuStore
`project_id` and notification icon in the Android manifest. Each package's README
lists its own.

## See also

- [Plugins](plugins.md) — how `dw.plugins.<name>` works, and why the accessor
  lives in the plugin's package.
- [Push delivery](../4-server/push-delivery.md) — the server half.
