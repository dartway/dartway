# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **Table definition members no row field wants (D-040):** `DwTableDef.name`,
  `columns` and `schema` are now `tableName`, `tableColumns` and
  `tableSchema`, and a row class declares `static const tableDef` (was
  `table`), so `name`, `columns`, `schema` and `table` are legal row fields.

- **`migrate create` writes drafts a project's analyzer accepts:** the draft and
  the registration import `dartway_core_server` when the project's
  `pubspec.yaml` declares it (else `dartway_orm`), and are formatted with
  `dart_style` for the project's language version before the checksum is
  sealed.
