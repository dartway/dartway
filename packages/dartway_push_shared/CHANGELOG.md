## 0.7.0-dev.0

- Dependency carets follow DartWay 0.22 and its satellites on their next
  development lines; public dependency types follow those releases (#530).

## 0.6.0

- Targets DartWay 0.21 (`dartway_core_*` `^0.21.0`).

## 0.5.0

- First publication. The shared contract of push notifications on the rewritten DartWay framework (`dartway_core_shared` 0.20.0) — this package never shipped before.

- Ported to DartWay 1.0: `DwRegisterPushToken` / `DwUnregisterPushToken`
  commands, `DwPushTransport`, `DwPushPlatform`, and `DwPushData` — the typed
  payload and link a notification carries, encoded once for both sides.
