## 0.5.0

- This package now targets the rewritten DartWay framework (`dartway_core_flutter` 0.20.0). The previously published `0.1.0` was built on the old, Serverpod-based stack.

- **Push is not on the path of the app opening** (#294). `DwPush.init` checks the protocol and
  returns; choosing the transport, `attach`, the permission, the token and `takeInitialOpen`
  continue in the background. An iOS build whose APNs registration never came (the simulator, a
  bundle id differing from `GoogleService-Info.plist`) stayed on its splash for good, because
  `getInitialMessage()` never answered and `dw.init()` awaited it. A call still unanswered after
  `DwPush(reportUnansweredAfter:)` (10 s) is reported by name and still waited for; the permission
  and the cold-start notification no longer wait on each other. `transport` and `token` may be
  `null` right after `dw.init()`; `requestPermission()` and `permission()` wait for the transport.

- Ported to DartWay 1.0. `DwPush` registers the device token through
  `DwRegisterPushToken` whenever the token or the signed-in account changes,
  reads the session from the core it is initialized with (never `dw`), and
  delivers opened notifications as `DwPushOpened` with the typed payload.
  Transports implement `DwPushTransportClient`.

## 0.1.0

First release of the app half of DartWay push, reached as `dw.plugins.push`.

- **Transport selection by declaration order.** The first provider that builds for the platform and
  answers for itself on the device wins, so `[DwRuStorePush(), DwFirebasePush()]` means RuStore on
  Android and FCM everywhere else — with no platform switch in the plugin.
- **Token lifecycle.** A token and a signed-in user arrive independently and in either order; the
  plugin sends the pair once, resends after a refresh or a change of user, catches up when either
  changed mid-flight, and survives being offline. Registration goes through the module's CRUD
  action, or through a callback of your own.
- **The recipient is not configured.** `init` takes `dw.signedInUserIdProvider`, which is the same
  identity the server derives the real recipient from — a registration carries a token and a
  provider, never an id. On the device the id is local bookkeeping only (is there anybody to
  register for, has this exact registration been made, did a sign-out invalidate it), so a second
  source redirects nothing; it only puts that bookkeeping out of step with what the server recorded,
  and the symptom is push going quiet after an account switch. `DwPushConfig.recipientIdProvider`
  survives as an override for the app that authenticates through an `AuthenticationKeyManager` of
  its own, and what it passes must mirror the identity its calls are authenticated as.
- **Taps that arrive exactly once.** A cold-start notification is held until the app can route it,
  then delivered after a frame the plugin asks for itself — a tap changes no widget, so nothing
  else would schedule one and the navigation would land on an unrelated gesture minutes later.
- **Permission on the app's terms** — on attach by default, or on demand at a moment the user
  understands.
- **`DwPushScope`** drives all of it from the widget tree, following the recipient through the
  Riverpod listenable the plugin resolved.
