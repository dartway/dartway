## 0.5.0

- This package now targets `dartway_push_flutter` 0.5.0, on the rewritten DartWay framework. The previously published `0.1.0` was built on the old, Serverpod-based stack.

- **RuStore SDK from its new repository** (#263): `nexus-external.rustore.ru/repository/maven-rustore-exposed`. The retired `artifactory-external.vkpartner.ru` (off from 01.10.2026), which `flutter_rustore_push` 7.2.0 still adds to every project, is removed from all projects' repositories once they are evaluated. Verified on a Flutter 3.44 app: the SDK resolves from the new host, and no project keeps the old one.

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The native service,
  tap handling and renderer are unchanged; the renderer reads the shared
  `DwPushData` keys (`dw_title`, `dw_body`, `dw_image`).

## 0.1.0

First release: RuStore behind the `DwPushClientProvider` contract, with the Android side an app
used to have to write itself.

- A messaging service that persists each message's payload on arrival and renders data-only
  messages — including the picture ones, which RuStore shows as nothing at all otherwise.
- Notification taps through `ActivityAware`/`onNewIntent`: no `MainActivity` override, and no list
  of payload keys duplicated in Kotlin.
- The Android 13 notification permission, requested natively rather than through an extra package.
- Appearance (icon, colour, channel) read from the app's manifest meta-data.
