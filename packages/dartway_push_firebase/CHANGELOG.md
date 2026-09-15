## 0.3.0-dev.1

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The web service worker
  template registers its click handler before the Firebase SDK is loaded
  (the SDK's own handler stops propagation, #78) and opens the notification's
  `dw_link`; the server also sends `webpush.fcm_options.link`.
