## 0.5.0

- This package now targets the rewritten DartWay framework (`dartway_core_shared`/`dartway_core_server`/`dartway_core_flutter` 0.20.0). The previously published `0.4.0` was built on the old, Serverpod-based stack.

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The web service worker
  template registers its click handler before the Firebase SDK is loaded
  (the SDK's own handler stops propagation, #78) and opens the notification's
  `dw_link`; the server also sends `webpush.fcm_options.link`.
