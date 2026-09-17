## 0.3.0-dev.1

- **RuStore SDK from its new repository** (#263): `nexus-external.rustore.ru/repository/maven-rustore-exposed`. The retired `artifactory-external.vkpartner.ru` (off from 01.10.2026), which `flutter_rustore_push` 7.2.0 still adds to every project, is removed from all projects' repositories once they are evaluated. Verified on a Flutter 3.44 app: the SDK resolves from the new host, and no project keeps the old one.

- Ported to DartWay 1.0 as a `DwPushTransportClient`. The native service,
  tap handling and renderer are unchanged; the renderer reads the shared
  `DwPushData` keys (`dw_title`, `dw_body`, `dw_image`).
