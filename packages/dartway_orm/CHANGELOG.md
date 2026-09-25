# Changelog

## 0.21.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.2

- **Aggregates, per-group firsts, upsert and list conditions on the repository**, from the raw SQL three projects wrote around their absence: `count(distinct:)`, `countBy`, `sum`/`sumBy`, `max`/`maxBy`, `min`/`minBy` (typed by the columns, grouped by any column, enum keys decoded), `findFirstPer(group, orderBy:)` (`DISTINCT ON`), `updateWhereReturning`, `upsert(row, conflictOn:)` (`ON CONFLICT … DO UPDATE`), and on a `jsonb` list column `isEmptyList`, `isNotEmptyList`, `contains`, `containsAny`. Raw SQL for these spelled enum values as literals that broke silently on a rename.
- Nothing changed here; the family moves in lockstep with `dartway_core_server` (#310, D-087).

## 0.21.0-dev.1

- Nothing changed here; the family moves in lockstep with `dartway_client`, fixed for #309.

## 0.20.0

- First publication of the rewrite to pub.dev.

## 0.20.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_shared` (#296).

## 0.20.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`.

## 0.20.0-dev.2

- **A migration is written with `// dart format off` as its first line** (#291). The checksum ignores whitespace, not the trailing commas `dart format` adds and removes as it wraps, so `dart format lib` broke the seal of every migration it reached and the server refused to start. `create` formats the draft, then marks it, then seals it; the formatter skips a marked file, `--set-exit-if-changed` included. Migrations created earlier are not touched — adding the line is an edit too. `check` on a changed file now says what to do when the migration is applied somewhere: restore it, not `rehash` it.

- **`DwMigrationCli(environment: …)`** — where `DW_DATABASE_*` is read from when no `database` is given; the process environment by default. A project whose entry points take their development coordinates from a file passes the environment that file produced, so `migrate` runs against the same database the server does without exporting anything (D-078).

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`DwEnumType` and `DwEnumListType` refuse to write `unknown` with `DwUnknownEnumWrite`** instead of a bare `StateError` (D-071). Catch the new type; on a call the framework now turns it into `dw.updateRequired` rather than an incident.
- **Open enum columns** (D-071): `DwEnumType` and `DwEnumListType` of a `DwOpenEnum` read an unknown name as `unknown` and refuse to write `unknown`; strict enums still fail the read.

- **`column.setIfNull(v)` in `updateWhere`**: `SET column = COALESCE(column, v)` on a nullable column, so "first unread" and a counter move in one statement.

- **`column.increment(n)` in `updateWhere`**: `SET column = column + n` on a non-null `int` or `double` column, computed by the database so concurrent increments all count. Unread counters needed raw SQL before.

- **SSL required of a server without it fails at once and lets the process exit.** The pool asks the server once, on a socket it closes, whether it speaks SSL before the first connection; a server that does not is refused with `DW_DATABASE_SSL=false` named. The driver alone threw and left its socket open, so a migration CLI printed the error and never exited.

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
