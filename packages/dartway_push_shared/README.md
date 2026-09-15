# dartway_push_shared

The push contract a DartWay server and its app share:

- `DwRegisterPushToken` / `DwUnregisterPushToken` and `dwPushProtocolEntries`, composed into the
  project's protocol: `DwWireProtocol(dwPushProtocolEntries, include: appProtocol)`;
- `DwPushTransport` (`fcm`, `rustore`) and `DwPushPlatform`;
- `DwPushCategory`, the mixin of the project's category enum;
- `DwPushData` — the typed payload and link a notification carries, written into a provider's data
  map by the server and read back by the app with the same class, so the keys exist once.

See `docs/4-server/push-delivery.md` and `docs/3-flutter/push-notifications.md` in the DartWay
repository.
