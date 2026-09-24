## 0.5.0

- This package now targets the rewritten DartWay framework (`dartway_core_shared`/`dartway_core_server`/`dartway_core_flutter` 0.20.0). The previously published `0.4.0` was built on the old, Serverpod-based stack.

- Ported to DartWay 1.0: `DwRegisterPushToken` / `DwUnregisterPushToken`
  commands, `DwPushTransport`, `DwPushPlatform`, and `DwPushData` — the typed
  payload and link a notification carries, encoded once for both sides.
