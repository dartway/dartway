# Push on the device: what does the app do, and what does it leave to the framework?

**The app decides three things: which transports it ships, when to ask for permission, and where
an opened notification leads.** Everything between — keeping the server's registration in step
with the token and the signed-in account, holding the notification that started the app until
something can route it, decoding the payload into the project's own class — is
`dartway_push_flutter`, reached as `dw.plugins.push`. It carries no vendor SDK; the transports are
separate packages, so an app downloads only what it ships:

| Package | Transport |
|---|---|
| `dartway_push_firebase` | FCM — Android, iOS, web |
| `dartway_push_rustore` | RuStore — Android devices with RuStore |

The server half — queue, eligibility, retries — is [Push delivery](../4-server/push-delivery.md).

## Wiring

```dart
dw = DwFlutterCore(
  config: DwFlutterConfig(...),
  protocol: appProtocol, // DwWireProtocol(dwPushProtocolEntries, include: appGeneratedProtocol)
  baseUrl: baseUrl,
  plugins: [
    DwSharedPreferences(),
    DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: webVapidKey)]),
  ],
);
```

`main` initializes Firebase before `dw.init()` and registers FCM's background handler:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
DwFirebasePush.registerBackgroundHandler();
```

The plugin takes **the first transport that supports the platform and is available on the
device** — the list above means RuStore on Android phones that have it, FCM everywhere else. A
Firebase transport without an initialized Firebase app is not available, so a build without a
Firebase project simply has no push.

**Push is not on the path of the app opening.** `dw.init()` waits only for the plugin's own checks;
choosing the transport, listening, the permission, the token and the notification that started the
app continue in the background. Those are vendor SDK calls that may never answer — on iOS,
firebase_messaging waits for an APNs registration that the simulator never delivers, and neither
does a device whose bundle id differs from `GoogleService-Info.plist` — and one of them awaited at
start kept an app on its splash screen. A call still unanswered after
`DwPush(reportUnansweredAfter:)` (ten seconds) is reported by name, `push: takeInitialOpen did not
answer in 10000 ms`, and — within the background start itself — still waited for. Right after
`dw.init()`, `push.transport` and `push.token` may therefore still be `null`; `requestPermission()`
and `permission()` wait for the transport too, but only up to that same
`reportUnansweredAfter` — asked on the user's behalf, they cannot leave a toggle waiting forever
for an APNs registration that never arrives, so past that deadline they answer
`DwPushPermission.notDetermined` rather than hang. A plugin whose start fails does not block the
app (`blocksStartup` is false): the failure is reported, and `dw.plugins.maybeOf<DwPush>()` answers
`null`.

The plugin reads everything it needs from the core it is initialized with — the client, its
protocol, its session — and never the app's `dw`, which does not exist yet while the `plugins:`
list is built (#54).

## Registration follows the session

The token and the signed-in account arrive independently and in either order. Whenever both are
known and that pair has not been registered, the plugin sends `DwRegisterPushToken` — once per
pair: a start signed in, a sign-in, an account switch and a refreshed token cost one call each,
and repeats cost none. Nothing is configured about whose device it is: the server takes the caller.

**A sign-out needs no call.** The server binds the registration to the session key the call was
made with and stops sending when that key is revoked — by this sign-out, by a sign-out on another
device, by an admin. The next sign-in registers the device under its new key. There is no
"unregister before signing out" step to forget, and no window in which the previous account's
notifications reach a phone somebody else now holds.

A registration the server refuses or that fails is reported through the app's error reporting and
tried again with the next token, sign-in or start.

## Permission, when the user understands why

The plugin asks for nothing on its own. Where the app decides:

```dart
final permission = await dw.plugins.push.requestPermission(); // registers the token on yes
```

A refusal is an answer, not an error. `DwPushPermission.permanentlyDenied` means only the system
settings can change it. `dw.plugins.push.permission()` reads the state without asking.

A user who turns notifications off inside the app calls `dw.plugins.push.pause()`: the device's
registration is removed and nothing is registered until `resume()`. The choice is the app's to
keep; `DwPush(isEnabled: ...)` reads it at start, so an app started with notifications off
registers nothing.

## Opened notifications

```dart
dw.plugins.push.opened.listen((opened) {
  if (opened.payloadAs<NewsAlert>() != null) {
    router.goNamed(AppNavigationZone.news.name);
  } else if (opened.link case final link?) {
    router.go(link);
  }
});
```

A `DwPushOpened` carries the server's typed payload (`payload`, `payloadAs<T>()`), its `link` and
its `source`: `coldStart`, `background` or `webClick`. The payload is decoded by the app's protocol
with the same `DwPushData` the server encoded it with. A payload this build cannot read — a class
of a newer server — is reported, and the link still opens.

**The notification that started the app is held** until the first listener subscribes, so a
listener attached when the router exists still receives it. The example's `PushOpenedListener`
wraps the app under `MaterialApp.builder`; the router's guards send a signed-out user to sign in.

`dw.plugins.push.received` reports notifications that arrived while the app was on screen, never
acting on them.

## On the web: the click

Copy `web/firebase-messaging-sw.js` from `dartway_push_firebase` into the app's `web/` and fill in
the Firebase config — nothing else. The order inside it is the whole point (#78): the Firebase SDK
registers a `notificationclick` listener that calls `stopImmediatePropagation()`, so a listener
added after the SDK never runs, on any browser, with no error. The template registers its listener
before the SDK is even loaded and stops the SDK's instead. With a tab of the app open, it focuses
that tab and posts the link, which arrives as `DwPushOpenSource.webClick`; with none, it opens the
link on the app's origin, and the router starts there.

The server also sends the link as `webpush.fcm_options.link`, so the browser opens the right page
even where no worker handles the click. The package's test executes the template in Node with the
SDK's behaviour stubbed and clicks a notification: a template with the order swapped fails it.

## On Android with RuStore

`dartway_push_rustore` replaces the RuStore SDK's messaging service with its own: it writes each
message's data down when it arrives (a tap may come back to a process that no longer exists), hands
taps back without a `MainActivity` override, raises the Android 13 permission prompt, and draws a
data-only message — the server sends a picture that way, because RuStore ignores an image in its
notification block. The app's manifest names the RuStore project id and the notification icon and
colour; the package's README lists the entries. RuStore push runs only on a physical device with
RuStore installed and signed in.

## Testing

`package:dartway_push_flutter/testing.dart` has `DwFakePushTransport`, a transport the test drives:
it issues a token, grants permission, and opens or delivers notifications when told. With the
in-memory `DwFakeServer` answering `DwRegisterPushToken`, a widget test checks what the app sends
and where an opened notification leads:

```dart
final transport = DwFakePushTransport(issuedToken: 'device-token');
final app = await ExampleTestApp.start(tester, FakeClub(), pushTransports: [transport]);
expect(app.server.callsOf<DwRegisterPushToken>(), hasLength(1));

transport.open(const DwPushData(payload: NewsAlert(id: 1)));
await app.settle(tester);
expect(find.byType(NewsPage), findsOneWidget);
```

The example's `test/app/push_test.dart` holds these, and a cold start that lands on the news.

## See also

- [Plugins](plugins.md) — how `dw.plugins.<name>` works.
- [Push delivery](../4-server/push-delivery.md) — the server half.
