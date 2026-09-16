# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`DwEnumListType<E>`**: a `List<E>` of an enum stored as a `jsonb` array of the values' names — the list form of `DwEnumType`. A name no value has fails the read (D-064).

- **BREAKING: pending migrations apply namespace by namespace** — in the order the runner is given
  them (the framework's, the modules', the project's), then by id — after `dependsOn`. They used to
  sort by id across namespaces, so a project migration older than a framework migration ran first,
  though module docs and the startup test's name already promised the other order. Only what is
  pending is reordered; applied migrations stay as recorded (D-060).

- **A pending migration edited after its checksum was sealed is refused before it is applied**
  (`DwUnsealedMigration`), where its source is on disk: `DwMigrationRunner(sources:)` maps a
  namespace to its directory, and `migrate apply` passes it. Applying it used to run the new text
  under the old checksum, and the `rehash` that followed made every later start refuse the
  migration as edited after it was applied (D-059).

- **`DwDatabaseMigration.supersededChecksums` (D-056):** checksums of earlier
  texts of a migration that the ledger accepts in place of `checksum` — for
  correcting a migration that could not apply on some databases while others
  applied the earlier text with the same outcome. `status` reports such a row
  `applied`; any other checksum is still `changed` and refuses.

- **Table definition members no row field wants (D-040):** `DwTableDef.name`,
  `columns` and `schema` are now `tableName`, `tableColumns` and
  `tableSchema`, and a row class declares `static const tableDef` (was
  `table`), so `name`, `columns`, `schema` and `table` are legal row fields.

- **`migrate create` writes drafts a project's analyzer accepts:** the draft and
  the registration import `dartway_core_server` when the project's
  `pubspec.yaml` declares it (else `dartway_orm`), and are formatted with
  `dart_style` for the project's language version before the checksum is
  sealed.
