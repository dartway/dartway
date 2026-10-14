## 0.7.0-dev.0

- Creates the configurable quiet Android notification channel when the plugin attaches (#595).

- Dependency carets follow DartWay 0.22 and its satellites on their next
  development lines; public dependency types follow those releases (#530).

## 0.6.0

- Targets `dartway_push_flutter` `^0.6.0` (DartWay 0.21), which added `DwPushPermission.unanswered`
  (dartway/dartway#338). The transport this package exports extends that package's
  `DwPushTransportClient`, so the caret moves this package a minor; nothing else in its own API
  changed.

## 0.5.0

- This package now targets `dartway_push_flutter` 0.5.0, on the rewritten DartWay framework. The previously published `0.1.1` was built on the old, Serverpod-based stack.

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The web service worker
  template registers its click handler before the Firebase SDK is loaded
  (the SDK's own handler stops propagation, #78) and opens the notification's
  `dw_link`; the server also sends `webpush.fcm_options.link`.
