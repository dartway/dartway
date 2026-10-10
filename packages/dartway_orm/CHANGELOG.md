# Changelog

## 0.21.0-dev.17

- Treat unknown applied migrations after every registered id in their namespace as
  `DwMigrationState.ahead`, reported by `DwMigrationRun.ahead`; `apply` and CLI `status` accept
  them, while rollback refuses until the newer release's code rolls them back. Gaps, checksum
  edits and dirty migrations still refuse (#527).

- Write package imports in the migration index when its directory is under the owning package's
  `lib/`, so `migrate create` no longer reintroduces `relativeImport` errors (#445). Standalone
  directories and directories outside `lib/` keep relative imports.

- Add `DwColumnType.calendarDay` for nullable or required `DwCalendarDay` columns, PostgreSQL
  `date` binding/decoding, comparisons and date-array parameters. Existing timestamp columns and
  repository insert/default behavior are unchanged.

- Nothing changed here; the family moves in lockstep to deliver the migration note for the router
  that follows a provider (dartway/dartway#407).

## 0.21.0-dev.16

- Nothing changed here; the family moves in lockstep to deliver the migration note for the import,
  test layout and spacing checks of `dartway check` (dartway/dartway#391).

## 0.21.0-dev.15

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`
  (dartway/dartway#390).

## 0.21.0-dev.14

- Nothing changed here; the family moves in lockstep to deliver the migration note for the new
  state and command checks of `dartway check` (dartway/dartway#389).

## 0.21.0-dev.13

- **`DwTableRepository.upsertAll(drafts, conflictOn:)`** (dartway/dartway#388): every draft
  inserted, or written over the row with the same unique key unless that row already holds exactly
  these values, in one statement; answers how many rows were inserted or changed, so a second run with
  the same drafts writes nothing. Refuses two drafts with one key (compared by value) and a nullable
  conflict column. What `DwSeedRows` runs.
- **`DwMigrationContext.backfill(sql)`**: runs like `sql`, and is the one place `dartway check`
  accepts an `INSERT`, `UPDATE` or `DELETE` in a project migration (`migrationChangesData`) — for
  rows a schema change strands. Content is a seed step. Re-exports `DwTextFieldPatch`.

## 0.21.0-dev.12

- **BREAKING: a row's `id` is `int`, and a row not stored yet is its draft.** `DwTableRow.id` is
  non-null — every row comes out of the database, which assigned it — so a stored row's id is read
  without `!`. `insert`, `tryInsert`, `insertAll` and `upsert` take a `DwRowDraft<R>` (generated as
  `New<Entity>Row`) and answer the stored row; `DwTableDef` gains `toDraftRow`, and `toRow` no
  longer carries the id. An insert with an id of one's own is gone, with `insertAll`'s "every row
  has an id or none has" (it also left the `bigserial` sequence behind the rows). `update(row)`
  needs no id check: the type holds it (dartway/dartway#384).

## 0.21.0-dev.11

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#387).

## 0.21.0-dev.10

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#386).

## 0.21.0-dev.9

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#385).

## 0.21.0-dev.8

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#355, #356).

## 0.21.0-dev.7

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`, whose `dartway_router` bump changed URLs for `extraPathSegment` (#314).
- `DwDatabaseConfig` gains an optional `caFile` (`DW_DATABASE_CA_FILE` in
  `fromEnvironment`): when set, every connection — pooled and `listen()`'s own
  — verifies the server's certificate against that CA (`SslMode.verifyFull`)
  instead of only encrypting the channel (`SslMode.require`, unchanged when
  absent). `DW_DATABASE_CA_FILE` set together with `DW_DATABASE_SSL=false` is
  refused as a contradiction — a CA has nothing to verify without TLS — both
  by `fromEnvironment` and by the constructor itself (dartway/dartway#342).
  The server certificate needs a `subjectAltName` for the connecting host (no
  fallback to `CN`, unlike `libpq`) and `extendedKeyUsage: serverAuth`; every
  managed provider's own CA issues one.

## 0.21.0-dev.6

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.5

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

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

The rewrite (see docs/1.0/DECISIONS.md).

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
