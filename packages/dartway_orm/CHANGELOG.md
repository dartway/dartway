# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`migrate create` writes drafts a project's analyzer accepts:** the draft and
  the registration import `dartway_core_server` when the project's
  `pubspec.yaml` declares it (else `dartway_orm`), and are formatted with
  `dart_style` for the project's language version before the checksum is
  sealed.
