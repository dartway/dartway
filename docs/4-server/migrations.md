# Migrations: how does a schema change reach every database?

A migration is Dart code in the server package that moves the schema — and data, when it must —
one step. The project's migrations live in `lib/src/migrations/`, one file each, registered in
`lib/src/migrations/migrations.dart`. The server applies them when it starts; `bin/migrate.dart`
applies, rolls back, inspects and drafts them.

Migrations are code rather than a diff computed at deploy time because only a person knows whether
a dropped column was really renamed, or what a new `NOT NULL` column should hold in existing rows.
The tools write the draft and refuse to guess those answers.

## `DwDatabaseMigration`

A migration adding an `invoice` table, as `create` would draft it:

```dart
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20261001120000Invoices extends DwDatabaseMigration {
  const M20261001120000Invoices();

  @override
  String get id => '20261001_120000_invoices';

  @override
  String get checksum => '…'; // sealed by `create`, refreshed by `rehash`

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.createTable(
      DwTableSchema(
        'invoice',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'account_id',
            'bigint',
            references: DwForeignKey('dw_account', onDelete: DwOnDelete.cascade),
          ),
          DwColumnSchema('amount', 'bigint'),
          DwColumnSchema('paid_at', 'timestamp with time zone', nullable: true),
        ],
        indexes: [
          DwIndexSchema('invoice_account_id_idx', ['account_id']),
        ],
      ),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropTable('invoice');
  }
}
```

Real ones: `example/dartway_example_server/lib/src/migrations/` (the chat migration there was
reviewed by hand — a column renamed rather than dropped and re-added).

| Member | Meaning |
|---|---|
| `id` | `YYYYMMDD_HHMMSS_name`, unique in its namespace; the file is `m<id>.dart` |
| `checksum` | a hash of the file's source, written by `create` and refreshed by `rehash`. The ledger stores it; an applied migration whose checksum changed refuses the next run. It is a declared literal because a compiled server has no sources to hash. Whitespace does not count, so `dart format` does not change it |
| `supersededChecksums` | checksums of earlier texts the ledger accepts in place of `checksum`. Empty by default, and for one case only: a migration that **could not apply** on some databases is corrected, and the earlier text, wherever it did apply, left exactly what the correction leaves — those databases keep their row, the rest run the correction. A change to what an applied migration does is a new migration |
| `dependsOn` | `DwMigrationRef(namespace, id)`s that must be applied first; may name another namespace. Empty by default |
| `transactional` | `true` by default. `false` only for statements Postgres refuses inside a transaction (`CREATE INDEX CONCURRENTLY`); such a migration is recorded `dirty` before it starts, so a crash halfway blocks the next run until someone looks |
| `up(m)` | the change |
| `down(m)` | irreversible unless overridden (`m.irreversible()`); `m.noop()` is the explicit answer for a migration with nothing to undo |

**A migration never imports row classes.** They change, and a migration must still run in six
months against the schema of its own day. It describes tables with schema literals —
`DwTableSchema`, `DwColumnSchema`, `DwIndexSchema`, `DwForeignKey` — and works on data with SQL.

`DwMigrationContext` offers `createTable`, `dropTable`, `addColumn(table, column, {backfill})`,
`dropColumn`, `renameColumn`, `alterColumnNullability(table, column, {nullable, backfill})`,
`alterColumnDefault`, `alterColumnType(table, column, sqlType, {using})`, `addForeignKey`,
`dropForeignKey`, `addUnique`, `dropUnique`, `createIndex`, `dropIndex`, and `sql` / `query` for
everything else. A `backfill` is an SQL expression computed for each existing row: the column is
added nullable, filled and then made `NOT NULL`, in the migration's transaction.

## The ledger and the rules

Applied migrations are rows of `dw_migrations`: namespace, id, checksum, batch, order of
application, state (`applied` or `dirty`) and time. The runner takes a session advisory lock first,
so two processes starting at once apply each migration once; the second waits and finds it done.

Before applying anything, the runner compares the ledger with the code and **refuses** —
`DwMigrationRefused`, nothing applied, every problem listed — when:

- a migration is applied but no longer registered (**missing**);
- an applied migration's checksum differs from the code's and is not one of its
  `supersededChecksums` (**changed**: its source was edited);
- a migration is **dirty** (a non-transactional one started and never finished);
- a `dependsOn` names an unregistered migration, the dependencies form a cycle, or one id is
  registered twice.

Otherwise the pending migrations run as one **batch**, ordered by `dependsOn` first, then by
namespace — the framework's `dw`, then the modules' in the order they are given, then the
project's — then by id. Each transactional migration runs in its own transaction together with its
ledger row. A migration that throws stops the run with `DwMigrationFailed`; the ones before it stay
applied. Every refusal and failure exits non-zero, in the CLI and in the server.

So a project migration follows every framework and module migration, whatever their ids: a
project created from an older template has an initial migration older than framework migrations
it relies on, and it still runs after them. Within the project, declare `dependsOn` when a
migration must follow one with a later id.

## Namespaces

- `dw` — the framework's own tables: accounts, identities, session keys, code tickets, command
  outcomes, jobs, stored files. Listed as `DwAppServer.frameworkMigrations`. Append-only: a change
  is a new migration. One migration was corrected in place, because it could not apply where
  `dw_stored_file` held rows: `20260914_180000_dw_stored_file_bucket` stops on files uploaded
  before a file recorded its bucket and names the two statements that record it
  (`ALTER TABLE dw_stored_file ADD COLUMN bucket text; UPDATE dw_stored_file SET bucket = '…'`,
  the bucket `DW_STORAGE_BUCKET` named then); a database that applied its first text is accepted
  by `supersededChecksums`.
- `app` — the project's.

Project tables may reference framework tables — a profile references `dw_account`, an attachment
`dw_stored_file` — but a project never writes migrations for, or queries, the `dw_*` tables
([auth and identity](auth-identity.md#no-sql-on-framework-tables)).

## `bin/migrate.dart`

The skeleton's (`template/dartway_starter_server/bin/migrate.dart`):

```dart
Future<void> main(List<String> args) async {
  exitCode = await DwMigrationCli(
    schema: dartwayStarterSchema,
    migrations: appMigrations,
    directory: 'lib/src/migrations',
    modules: {'dw': DwAppServer.frameworkMigrations},
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
  ).run(args);
}
```

`schema` is the generated `DwDatabaseSchema` of the row classes, `modules` the migrations of other
namespaces run before the project's replay (their tables are not part of `schema`), and `namespace`
defaults to `app`. There is no `dartway migrate`: the command line is the project's own program, so
it compiles against the project's row classes and migrations.

`dart run bin/migrate.dart <command>` against the database in `DW_DATABASE_*`:

| Command | What it does | Exit |
|---|---|---|
| `apply` | applies pending migrations as one batch | `0`; `2` refused; `1` failed |
| `rollback` | rolls back the last batch | as `apply` |
| `rollback --batch N` | rolls back batch N | |
| `rollback --id X` | rolls back one migration; `X` is an id of the project or `namespace/id` | |
| `status` | lists every migration: applied, pending, dirty, changed, missing | `2` when any is dirty, changed or missing |
| `create <name>` | writes a draft for the difference between the migrations and the row classes; `name` is snake_case | `0` |
| `check` | verifies files, schema parity and up/down/up | `3` when it finds a difference |
| `rehash [id …]` | re-seals the checksums of edited migrations (all, or the ids given) | `0` |

Wrong arguments exit `64`. A rollback refuses when an applied migration outside the rollback depends
on one inside it. When every migration rolled back is transactional, the whole rollback is one
transaction: an irreversible migration in the middle leaves the database as it was.

## Drafts: `create <name>`

1. Creates a throwaway database next to the one in `DW_DATABASE_*` (the user needs the right to
   create databases) and replays every migration into it.
2. Creates the schema the row classes declare in a separate Postgres schema of the same database
   and reads both back, so types and defaults compare as Postgres spells them rather than as they
   were typed.
3. Diffs them and writes `lib/src/migrations/m<id>.dart` — formatted, sealed with its checksum,
   with `up` and the inverse `down` — and rewrites `migrations.dart` to register every file in id
   order.
4. Drops the throwaway database.

Run `dartway generate` first: `create` reads the generated schema, not the row class sources.

No schema difference writes an empty migration, for data work. A change the diff cannot decide is
written as a call to `decisionRequired('…')`, with a comment naming the options:

- dropping a table or a column (it may have been renamed — the options include `renameColumn`);
- adding a `NOT NULL` column without a default (existing rows need a value: a `backfill`);
- changing a column's type (values must convert: a `using` expression);
- making a column `NOT NULL` (existing nulls need a `backfill`).

`decisionRequired` is a function that does not exist, so **the draft does not compile until every
decision is made.** A runtime throw would surface only when the migration runs; a compile error
surfaces in the editor, in `dart analyze` and in every build, and cannot be deployed by accident.

Once written, the draft is an ordinary migration and the author's. Editing it before it is applied
anywhere is expected; then run `rehash <id>`, or `check` reports the file as changed since sealing.
Editing it after it is applied somewhere is what the checksum refuses.

A pending migration edited and not yet rehashed is also refused where it would be applied, as long
as its source is on disk: `migrate apply`, and a server run from its sources with
`DwAppServer(migrationsDirectory: 'lib/src/migrations')`. Applying it would run the new text and
record the old checksum, and the `rehash` after that would make every later start refuse the
migration as edited after it was applied. A compiled server has no sources beside it and does not
check.

## `check`

`check` is what CI runs, and what `dartway check` runs as `migrationsDrift`:

1. **Files** — every migration's declared checksum matches its source; every file is registered in
   `migrations.dart`, and every registered migration has a file.
2. **Parity** — the migrations, replayed into a throwaway database, produce exactly the schema the
   row classes declare. Differences are listed as the changes still missing. What migrations
   created that row classes cannot declare — a partial index, a check constraint — is left out of
   the comparison and printed as a note, so nothing proposes dropping it.
3. **Up/down/up** — every project migration is rolled back newest first, then applied again one
   by one; each step up must reproduce the schema its rollback started from. It stops, with a
   note, at an irreversible migration.

It needs `DW_DATABASE_*` pointing at a Postgres where throwaway databases can be created — the
development one will do.

`dartway check` runs `dart run bin/migrate.dart check` in the server package when
`DW_DATABASE_HOST` is set. Findings are `migrationsDrift` errors: a schema the migrations do not
produce is a server that refuses to start in the next environment. Without a database it prints
that the check did not run — never that the migrations are fine. See
[the conventions checker](../5-tooling/conventions-checker.md).

## What the server does on start

`DwAppServer.start()` runs the same runner over `{'dw': frameworkMigrations, 'app': migrations}`
after opening the database. A refusal or a failure throws, and the process exits non-zero: a server
never serves a schema that disagrees with its ledger. Then, when `schema` is given, it checks that
every declared table and column exists ([app server](app-server.md#what-start-does-in-order)).

So a deploy needs no separate migration step. `bin/migrate.dart` is for development (`create`,
`check`, `rollback`) and for inspecting a database (`status`).

## Related

- [Database](database.md) — row classes and what `dartway generate` writes.
- [Migration notes](../migrations/README.md) — the edits a project owes when the framework changes; not database migrations.
