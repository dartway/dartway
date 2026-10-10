---
name: dartway-migrations
description: >-
  Changing the database schema: row class → generate → `dart run bin/migrate.dart create <name>` →
  review the draft and resolve every decisionRequired (a drop that may be a rename, a NOT NULL
  column on rows, a type change) → rehash → apply / status / rollback → check. Never edit an applied
  migration, never import row classes into one, rows change only through m.backfill,
  dataChecksAfter is the human's. What the server says when it refuses to start over the ledger.
  Use when a row class, column, index or foreign key changes, or a migration refuses.
---

# DartWay — migrations (`dartway-migrations`)

The schema has two descriptions, kept equal: the **row classes** (from which `generate` writes
`lib/generated/dw_schema.dart`) and the **migrations** in `__SERVER_PKG__/lib/src/migrations/`,
registered in `migrations.dart`. The server applies pending migrations as it starts and then checks
every declared table and column exists, so a row class changed without a migration is a server that
will not start in the next environment.

`dart run bin/migrate.dart` runs from `__SERVER_PKG__` against the database `deploy/config.yaml > local`
names (an exported `DW_DATABASE_*` wins); the user must be able to create databases.

```text
apply                          apply pending migrations, as one batch
rollback [--batch N | --id X]  the last batch, batch N, or one migration
status                         applied / pending / dirty / changed / missing (exit 2 on the last three)
create <name>                  write a draft from the row classes' schema
check                          files sealed, schema parity, up/down/up
rehash [id ...]                re-seal edited, unapplied migrations
```

## Expand, then contract

A **release** here is a deploy to production; without release branches, it is the next production
deploy carrying the code change. The previous release's code must run on the new schema, both for
rollback to its image and while old and new code run side by side.

**A release's migrations only expand:** new tables, nullable columns or columns with a default,
indexes, and relaxing a constraint (`NOT NULL` → nullable). **Contracting goes out one release later**,
once no running code reads the old shape: a drop, a rename, a type change, `NOT NULL` on existing rows,
or a narrowed constraint.

A rename takes four steps over two releases:

1. Release N: add the new column or table.
2. Release N: write both (or backfill).
3. Release N: switch reads to the new one.
4. Release N+1: drop the old one.

A type change follows the same steps through a new column. A direct rename is only for a table or
column **no released code reads**, typically one added in the same unreleased branch.

## The cycle

A schema change always starts from `create`; a migration written by hand from scratch drifts from the
diff `check` compares against.

1. **Change the row class, then `dart run dartway_cli:dartway generate`** (from `__FLUTTER_PKG__`) —
   always first: `create` diffs against the generated schema, and before `generate` it sees no change.
2. **`dart run bin/migrate.dart create add_invoice_due_date`** — replays every migration on a scratch
   database, diffs it against the row classes, writes `m<timestamp>_<name>.dart` with `up` and `down`,
   sealed, and registers it. It applies nothing. With no schema change the draft is an empty `up` — how
   a data-only migration starts.
3. **Review the whole draft; it is yours now.** What depends on data is written as
   `decisionRequired('…')`, a function that does not exist — nothing compiles, `bin/migrate.dart`
   included, until each is replaced:

   | Decision | Write |
   |---|---|
   | drop table — removed or renamed? | `m.dropTable('x')` only in a release after the code stopped reading the old shape; in the same release, expand instead ([rule](#expand-then-contract)). `m.sql('ALTER TABLE "old" RENAME TO "new"')` and deleting the new table's `createTable` is only for a table no released code reads. |
   | drop column — removed or renamed? | `m.dropColumn` only in a release after the code stopped reading the old shape; in the same release, expand instead ([rule](#expand-then-contract)). `m.renameColumn(t, 'old', 'new')` and deleting the matching `addColumn` is only for a column no released code reads. |
   | add a NOT NULL column to rows | `m.addColumn(t, column, backfill: '<SQL expression>')` is an expand only if the previous code does not insert into that table; otherwise the column needs a default in the row class. |
   | make a column NOT NULL | `m.alterColumnNullability(t, 'c', nullable: false, backfill: '…')` only in a release after the code stopped reading the old shape; in the same release, expand instead ([rule](#expand-then-contract)). |
   | change a type | `m.alterColumnType(t, 'c', '<type>', using: '"c"::<type>')` only in a release after the code stopped reading the old shape; in the same release, expand instead through a new column ([rule](#expand-then-contract)). |

   When converting `timestamptz` values to a `DwCalendarDay`/PostgreSQL `date`, name the civil zone
   in the conversion expression: `("c" AT TIME ZONE 'America/Los_Angeles')::date`. Use it to backfill
   the new column, or as `using:` for a type change allowed by the [rule](#expand-then-contract).
   The zone decides the date for each stored instant; never cast an instant to date without recording
   that choice.

   **A drop and an add in one table are usually one rename** — accepting both empties the column on every
   row. A direct rename is only for a column no released code reads; otherwise follow the
   [expand/contract rule](#expand-then-contract). Decisions appear in `down` too; answer them or `down`
   is `m.irreversible()` (`m.noop()` when nothing to undo). `backfill` is a SQL expression per row,
   in the migration's transaction. Never
   replace a decision with whatever compiles: a value existing rows cannot derive is the human's.
4. **Rehash after every edit, before the migration is applied anywhere** (your own database included):
   `dart run bin/migrate.dart rehash`. Keep the `// dart format off` line; never reformat a migration.
5. **`status` → `apply` (or start the server) → `status`.** Wrong after applying locally? **Roll back
   first, then edit** (`rollback --id …`, edit, rehash, apply): once edited, the rollback refuses — edited
   already, `git checkout` the file, roll back, redo the edit, rehash.
6. **`dart run bin/migrate.dart check`** — on scratch databases: files sealed and registered, the
   migrations produce exactly the declared schema, and each rolls back and re-applies. `note:` lines
   (what a row class cannot declare) are informational, `FAIL` fails. `check`'s `migrationsDrift` runs
   the same when a database is named — `DW_DATABASE_*` or `deploy/config.yaml > local` — and says "Not
   checked" otherwise.

## The body of a migration

- **Never import a row class, a data object or anything from `lib/`**: it must run the same way against
  a database that never saw today's code. The draft's schema literals (`DwTableSchema`, `DwColumnSchema`)
  stay.
- **A migration changes the schema; it writes rows only to carry them across that change**, through
  `m.backfill('UPDATE …', params: {…})`, reading with `m.query` (`migrationChangesData` holds this).
  Content is a `DwSeedRows` step (`dartway-server`); `dw_*` tables are never written, a settings table is
  carried with `m.carrySettings(…)`.
- Transactional by default; `bool get transactional => false` only for what Postgres refuses inside one
  (`CREATE INDEX CONCURRENTLY`) — a crash leaves it `dirty`, repaired by hand.
- One concern per migration, named after the change; `dependsOn` only across namespaces.

## Never, without the human

- **Edit, rename or delete an applied migration** — applied anywhere: a teammate, staging, production.
  A fix is a new migration. (`supersededChecksums` is for a migration that failed on some databases.)
- **Move `deploy/config.yaml > migrations > dataChecksAfter`** — it exempts migrations from
  `migrationChangesData`.
- **Rehash a migration applied somewhere, or delete the development volume** (`docker compose down -v`).

## When the server refuses to start

It prints every problem at once (`DwMigrationRefused`):

| The line | What to do |
|---|---|
| `… was edited after it was applied` | restore the applied text from git; a wanted change is a new migration |
| `… is applied but no longer registered` | restore the file; after a branch switch the database is ahead — name it to the human |
| `… is dirty` | a non-transactional migration crashed: repair by hand with the human |
| `registered twice` / `dependency cycle` | fix `migrations.dart` or `dependsOn` |
| `up of app/… failed: <postgres error>` | read the SQL error: a NOT NULL without backfill, a unique index over duplicates, a missing cast |
| `table "x" is declared in the schema and missing` | a row class changed without `create`, or the file is not registered |
