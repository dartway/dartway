---
name: dartway-migrations
description: >-
  Changing the database schema of a DartWay project (DartWay projects): a row class changed →
  `dartway generate` → `dart run bin/migrate.dart create <name>` against the local database (it
  replays every migration on a scratch database and diffs against the row classes) → review the
  draft and resolve every `decisionRequired(...)` (a drop that may be a rename, a NOT NULL column
  on a table with rows — `addColumn(..., backfill:)`, a NOT NULL change, a type change) → `rehash`
  after any hand edit, before the migration is applied anywhere → `status` / `apply` / `rollback`
  → `check` (and `dartway check`'s `migrationsDrift`). Never edit an applied migration, never
  import row classes into one, data work in SQL through `m.sql` / `m.query`. The server applies
  pending migrations as it starts and refuses to start when the ledger and the code disagree
  (missing, changed, dirty). Use when a row class, a column, an index or a foreign key changes,
  when a migration refuses, or when the server will not start over one.
---

# DartWay — migrations (`dartway-migrations`)

The schema has two descriptions, and this skill keeps them equal:

- **the row classes** in `__SERVER_PKG__/lib/src/` (`@DwSqlTable`, `@DwForeignKey`, `@DwUniqueColumn`,
  `DwTableIndex` …), from which `dartway generate` writes `lib/generated/dw_schema.dart` — the
  schema the code expects;
- **the migrations** in `__SERVER_PKG__/lib/src/migrations/` — Dart classes extending
  `DwDatabaseMigration`, registered in `migrations.dart`, which is what actually builds a database.

A server starts only when the migrations it carries have been applied, and after applying them it
checks that every table and column the generated schema declares exists. So a row class changed
without a migration is not a warning at review — it is a server that refuses to start in the next
environment.

Everything below runs **from `__SERVER_PKG__`**, against the Postgres `deploy/config.yaml > local`
names — `bin/migrate.dart` reads it through `DwLocalEnvironment`, so nothing has to be exported,
and an exported `DW_DATABASE_*` still wins when you need another database. The user must be able to
create databases on it (the development one from `docker compose` is). There is no `dartway migrate` command: the project's own `bin/migrate.dart`
wraps `DwMigrationCli`, because only the project knows its schema and its migration list.

```text
dart run bin/migrate.dart apply                          apply pending migrations
dart run bin/migrate.dart rollback [--batch N | --id X]  roll back the last batch, batch N, or one migration
dart run bin/migrate.dart status                         applied / pending / dirty / changed / missing
dart run bin/migrate.dart create <name>                  write a draft from the row classes' schema
dart run bin/migrate.dart check                          files sealed, schema parity, up/down/up
dart run bin/migrate.dart rehash [id ...]                re-seal checksums of edited, unapplied migrations
```

Exit codes: `0` ok, `1` a migration or the database failed, `2` refused (the ledger and the code
disagree, nothing changed), `3` `check` found a difference, `64` usage.

---

## The cycle

### 1. Change the row class, then generate

Edit the row class (or add one), then from the project root:

```bash
dartway generate
```

**Generate first, always.** `bin/migrate.dart` passes the *generated* schema to the CLI. Run
`create` before `generate` and the diff is taken against yesterday's schema: the draft comes out
empty ("no schema changes"), and you ship a data-only migration for a change that never happened.
`dartway generate --check` (and `dartway check`'s `generatedCodeStale`) is how to tell the tree is
current.

### 2. Write the draft

```bash
dart run bin/migrate.dart create add_invoice_due_date
```

The name is `snake_case` (`[a-z][a-z0-9_]*`). What it does:

1. creates a throwaway database next to the one `DW_DATABASE_*` names (`dw_scratch_…`), applies
   the framework's migrations and every migration of the project to it, and reads the schema back;
2. builds the schema the row classes declare in the same database, so both sides are compared in
   Postgres' own spelling of types and defaults;
3. writes `lib/src/migrations/m<YYYYMMDD_HHMMSS>_<name>.dart` with an `up` and a `down`, formatted
   for the project and sealed with its checksum, and rewrites `migrations.dart` to register every
   file in id order;
4. drops the scratch database and prints each change, `DECIDE` in front of the ones that need you.

The development database itself is not touched: `create` never applies anything.

When there are no schema changes, the draft is an empty `up` for data work — that is how a pure
data migration is started.

### 3. Review the draft: it is yours from now on

Read the whole file, `up` and `down`. The generator writes what the diff can prove. It cannot see
data, so every change whose right form depends on data is written as a call to
**`decisionRequired('…')`** — a function that does not exist. The draft does not compile until each
one is replaced, which is the point: an unresolved decision fails in the editor, in `dart analyze`
and in every build, and cannot be deployed by accident.

**While a decision is open, `bin/migrate.dart` itself does not compile** — it imports the
migration list. Resolve the draft before running any other `migrate` command, `dartway test` or
the server.

Each decision carries a comment with the options. The cases:

| `DECISION REQUIRED` | What the diff cannot know | What to write |
|---|---|---|
| `drop table x` | Whether the table was removed or renamed | Removed: `m.dropTable('x')`. Renamed: `m.sql('ALTER TABLE "old" RENAME TO "new"')`, and delete the `createTable` of the new name |
| `drop column t.c` | Whether the column was removed or renamed | Removed: `m.dropColumn`. Renamed: `m.renameColumn(t, 'old', 'new')` — the draft offers it — and **delete the matching `addColumn`** |
| `add NOT NULL column t.c` | What existing rows hold | `m.addColumn(t, column, backfill: '<SQL expression>')` — added nullable, filled for every row, then made `NOT NULL`, in one transaction. Or give the column a default in the row class and regenerate |
| `make t.c NOT NULL` | Whether existing rows hold nulls | `m.alterColumnNullability(t, 'c', nullable: false, backfill: '<SQL expression>')` |
| `change type of t.c` | Whether existing values convert | `m.alterColumnType(t, 'c', '<type>', using: '"c"::<type>')` — adjust `using` when no implicit cast exists |

**A rename is the decision that loses data when missed.** Rename a field in a row class and the
diff sees a dropped column and an added one; accepting both empties the column on every row, and
the migration looks perfectly ordinary afterwards. Whenever a drop and an add of the same table sit
in one draft, ask whether it is one rename.

**Decisions appear in `down` too.** `down` is written from the inverse changes, so the inverse of a
dropped `NOT NULL` column is an added one and asks the same question. Answer it, or make the
migration explicitly irreversible:

```dart
@override
Future<void> down(DwMigrationContext m) => m.irreversible();
```

`m.noop()` is the answer for a migration with nothing to undo. An irreversible migration stops the
up/down/up round trip in `check` at that point (a note, not a failure).

**The `backfill` is SQL, not Dart.** It is an expression computed per row (`'now()'`,
`'0'`, `'"created_at"'`, `'(SELECT … )'`), and it runs inside the migration's transaction.

### 4. Rules for the migration's body

- **Never import a row class, a data object or anything from `lib/` into a migration.** Row classes
  change; a migration must still run the same way in six months against a database that has
  never seen today's code. The draft already describes tables with schema literals
  (`DwTableSchema`, `DwColumnSchema`, `DwForeignKey`, `DwIndexSchema`) — keep it that way.
- **Data work is SQL**: `m.sql('UPDATE …', params: {...})`, `m.query('SELECT …')`. Not a repository,
  not `db.<plural>` — those are generated from today's row classes.
- **A migration is transactional by default**: everything in `up` commits or nothing does. Only for
  statements Postgres refuses inside a transaction (`CREATE INDEX CONCURRENTLY`,
  `ALTER TYPE … ADD VALUE`) override `bool get transactional => false`. Such a migration is
  recorded `dirty` before it starts; a crash halfway leaves it `dirty`, and every later run refuses
  until someone repairs the database by hand and fixes the ledger row. Do not reach for it to make
  a slow migration "faster".
- **Keep one concern per migration** and name it after the change (`add_invoice_due_date`, not
  `update`): the id is what `status`, the server log and a refusal will print.
- `dependsOn` is for ordering against another namespace (a module's migration); within the
  project, ids already order by time.

### 5. Seal it: `rehash` after every hand edit

The draft is sealed with a checksum of its source (whitespace ignored, so `dart format` changes
nothing). Resolving a decision is an edit, so the declared checksum is now wrong:

```bash
dart run bin/migrate.dart rehash                 # every edited migration
dart run bin/migrate.dart rehash 20260915_101500_add_invoice_due_date
```

**Rehash before the migration is applied anywhere — including your own development database.** The
ledger stores the checksum the migration declares at the moment it is applied. Apply with a stale
checksum, rehash afterwards, and the next start of that database refuses: the migration "was
edited after it was applied". `migrate apply` and a server started from its sources refuse an
unsealed pending migration first ("changed after its checksum was sealed … run `rehash`") — do what
it says; do not work around it by editing the ledger.

### 6. Apply, look, roll back while it is still local

```bash
dart run bin/migrate.dart status     # the new one is pending
dart run bin/migrate.dart apply      # or just start the server: it applies on start
dart run bin/migrate.dart status     # applied (batch N, time)
```

`apply` runs every pending migration as one batch: dependencies first, then by id across the
framework's (`dw`) and the project's (`app`) namespaces. A failing migration rolls back its own transaction; the ones before it in the batch stay
applied, and the process exits `1` naming it.

Found something wrong after applying it locally? **Roll back first, then edit:**

```bash
dart run bin/migrate.dart rollback --id 20260915_101500_add_invoice_due_date
# edit the file → rehash → apply again
```

The order matters because `rollback` checks the ledger against the code too: once the file is
edited, the ledger's checksum no longer matches and the rollback refuses. Edited already? Restore
the file from git, roll back, then redo the edit. `rollback` with no arguments undoes the last
batch; `--batch N` a given batch. A rollback of transactional migrations is one transaction — an
irreversible migration in the set leaves the database exactly as it was.

A local database is disposable; `docker compose down -v` recreates it from the migrations. It
deletes every row, so ask the human first.

### 7. Prove it: `check`

```bash
dart run bin/migrate.dart check
```

On scratch databases, never on yours, it verifies:

- **files** — every migration's source matches its sealed checksum; every file is registered in
  `migrations.dart` and every registration has a file;
- **parity** — applying all migrations produces exactly the schema the row classes declare; a
  difference is printed as the missing changes;
- **up/down/up** — each migration is rolled back newest first and applied again, and every step
  must reproduce the schema it started from.

`ok` lines and `note:` lines are informational (`not modelled by row classes` names what the migrations
create that a row class has no way to declare — a check constraint, a partial index, a multi-column
foreign key — so it is left out of the comparison on purpose). `FAIL` lines fail it with exit `3`.

`dartway check` runs the same command as its `migrationsDrift` check — an error — when
`DW_DATABASE_*` is set, and says "Not checked" rather than passing when it is not. So "`dartway
check` is green" proves the migrations only if the output did not say it skipped them.

`dartway-finish` runs `check` whenever the diff touches a row class or a migration.

---

## The two rules that are never bent

**Never edit an applied migration.** "Applied" means applied anywhere — a teammate's machine, a
staging server, production. The server refuses to start against a database whose ledger holds a
different checksum for the same id, and it is right to: the database was built by the old text,
and nobody knows what the new text would have done. A fix to an applied migration is a **new**
migration. (`supersededChecksums` is not a way around this: it exists for a migration that
*failed* on some databases and is corrected with the same outcome where it did apply — ask the
human before reaching for it.)

**Never delete or rename an applied migration's file or id.** The ledger then holds a migration
the code does not know (`missing`), and the server refuses for the same reason.

The only migration you may freely edit is one that exists nowhere but in your working copy — and
then: roll back locally, edit, `rehash`.

---

## When the server refuses to start

The server applies pending migrations as it starts (framework `dw`, modules, then the project's
`app`) and exits non-zero on any problem, listing all of them at once:

```text
DwMigrationRefused: refused to migrate:
  - app/20260915_101500_add_invoice_due_date was edited after it was applied (checksum … in the ledger, … in the code)
```

| The line | Meaning | What to do |
|---|---|---|
| `… was edited after it was applied` | `changed`: the file's declared checksum differs from the ledger's | Restore the applied text from git (`git log -p` on the file). A wanted change becomes a new migration. Locally only, and only if the migration exists nowhere else: roll back with the old text, then edit and rehash |
| `… is applied but no longer registered in the code` | `missing`: a file deleted, renamed, or dropped from `migrations.dart` | Restore it. On a branch switch: the database is ahead of this branch — switch back, or roll it back on the branch that has it |
| `… is dirty: a non-transactional migration started and did not finish` | A `transactional => false` migration crashed halfway | Repair the database by hand, then delete its ledger row (to re-run) or mark it applied; ask the human — this is a production-grade decision |
| `… is registered twice` / `dependency cycle` / `depends on …, which is not registered` | The registration is broken | Fix `migrations.dart` or `dependsOn` |
| `up of app/… failed: <postgres error>` | The migration ran and Postgres refused a statement; its transaction rolled back | Read the SQL error: a `NOT NULL` without a backfill on a table with rows, a unique index over duplicates, a type without a cast |
| `table "x" is declared in the schema and missing from the database: is its migration registered?` (a `DwStartupException`) | All migrations applied, yet the generated schema names a table or column no migration creates | You changed a row class and did not run `create`, or the file is not in `migrations.dart` |

`dart run bin/migrate.dart status` prints the same states per migration and exits `2` when any is
`dirty`, `changed` or `missing` — the quickest way to see the problem without starting the server.

Branch switching is where `missing` and `changed` come from locally: a database migrated on one
branch meets code from another. Name that to the human rather than "fixing" either side.

---

## What not to do

- **Do not run `create` before `dartway generate`**, and do not hand-edit
  `lib/generated/dw_schema.dart` to make a diff appear.
- **Do not accept a drop + add pair without asking whether it is a rename.**
- **Do not replace `decisionRequired` with whatever compiles.** An empty backfill string, a
  `dropColumn` "to get it green", commenting the call out — each one is a data decision taken
  silently. If the right value for existing rows is not derivable, it is a question for the human.
- **Do not `rehash` a migration that is already applied somewhere.** It turns a refusal you can
  explain into one nobody can.
- **Do not write migrations by hand from scratch** when the change is a schema change — the draft
  is the diff, and `check` compares against the same diff; a hand-written one drifts in type
  spellings and defaults.
- **Do not delete the development volume without asking.**

## Checklist

- [ ] Row class changed → `dartway generate` → `create <name>`.
- [ ] Every `decisionRequired` resolved, in `up` and in `down`; drop + add pairs checked for renames.
- [ ] No imports of row classes or `lib/` in the migration; data work in `m.sql` / `m.query`.
- [ ] `rehash` after the last edit, before the first apply.
- [ ] `status` → `apply` (or a server start) → `status` shows it applied.
- [ ] `check` green: files, parity, up/down/up.
- [ ] Nothing applied elsewhere was edited, renamed or deleted.
