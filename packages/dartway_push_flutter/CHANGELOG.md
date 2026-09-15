## 0.3.0-dev.1

- Ported to DartWay 1.0. `DwPush` registers the device token through
  `DwRegisterPushToken` whenever the token or the signed-in account changes,
  reads the session from the core it is initialized with (never `dw`), and
  delivers opened notifications as `DwPushOpened` with the typed payload.
  Transports implement `DwPushTransportClient`.
