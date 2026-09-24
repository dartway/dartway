## 0.5.0

- This package now targets the rewritten DartWay framework (`dartway_core_shared`/`dartway_core_server`/`dartway_core_flutter` 0.20.0). The previously published `0.4.0` was built on the old, Serverpod-based stack.

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
