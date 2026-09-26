## 0.6.0

- **BREAKING: `DwPushPermission` gained `unanswered` (#338).** `requestPermission()` and
  `permission()` awaited the background start's `_attached` future with no bound of their own: on
  iOS `attach` awaits an APNs registration a wrong bundle id, or no signal at all, never delivers,
  so a build like that left the app's push toggle waiting forever — busy, with the setting never
  saved. Both now give up after `DwPush(permissionDeadline:)` (10 s by default, separate from
  `reportUnansweredAfter` so lowering how soon a background call is *reported* cannot, as a side
  effect, also shorten how long these two wait) and answer `unanswered`: the real state is unknown
  — never "nobody has asked" (`notDetermined` keeps that meaning, and only that meaning, now) and
  never a guess at granted or denied. `permission()`'s own call to the transport is bounded the
  same way once attached, since nobody is waiting on a dialog there either;
  `requestPermission()`'s call to the platform stays unbounded — it may be showing the user a
  system dialog, and their own time answering it is not silence. The background start itself is
  unaffected: a late `attach` still completes and is still used, including registering the token
  when permission was already granted. **A project with an exhaustive `switch` over
  `DwPushPermission` needs a case for `unanswered`** — see `docs/migrations/`.

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
