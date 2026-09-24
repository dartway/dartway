## 0.5.0

- First publication. The shared contract of push notifications on the rewritten DartWay framework (`dartway_core_shared` 0.20.0) — this package never shipped before.

- Ported to DartWay 1.0: `DwRegisterPushToken` / `DwUnregisterPushToken`
  commands, `DwPushTransport`, `DwPushPlatform`, and `DwPushData` — the typed
  payload and link a notification carries, encoded once for both sides.
