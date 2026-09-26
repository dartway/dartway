## 0.5.1

- Raised the caret on `dartway_push_flutter` to `^0.6.0`, which added `DwPushPermission.unanswered`
  (dartway/dartway#338) — nothing in this package's own API changed.

## 0.5.0

- This package now targets `dartway_push_flutter` 0.5.0, on the rewritten DartWay framework. The previously published `0.1.1` was built on the old, Serverpod-based stack.

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The web service worker
  template registers its click handler before the Firebase SDK is loaded
  (the SDK's own handler stops propagation, #78) and opens the notification's
  `dw_link`; the server also sends `webpush.fcm_options.link`.
