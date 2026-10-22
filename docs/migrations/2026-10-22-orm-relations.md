---
title: Generate typed ORM relations and index foreign keys
affects:
  dartway_generator: "0.24.0-dev.1"
  dartway_orm: "0.24.0-dev.1"
---

## Who is affected

Projects with generated row classes, especially two FKs from one row to the same input table,
relation names colliding with fields, or FKs without a leading index.

## What to change

Run `dartway generate`. For an ambiguous pair, name each FK's forward and reverse relation, e.g.
`@DwForeignKey('user_profile', relation: 'authorProfile', reverse: 'authoredMessages')` and
`@DwForeignKey('user_profile', relation: 'reviewerProfile', reverse: 'reviewedMessages')`.
If a row field is named `tablePath`, or a referenced row has `include` / `includeSpec`, rename
the Dart field: these names now describe generated relation metadata. Retain its SQL column name
with `@DwColumnName('original_name')`, so the field rename needs no schema change.
For an FK-index warning, add `DwTableIndex(['fieldId'])` to the row's table indexes, regenerate,
and run `dart run bin/migrate.dart create index_foreign_keys`; review and apply the migration.
A composite index leading with the FK, or a unique FK, needs no additional index.

FKs to framework, module or SQL-only tables without row classes remain valid and produce no typed
relations. Framework tables stay behind their services. Existing `findByIds`, raw SQL and reads
retain their meaning; adopting relation filters and includes is optional. When adopted, explicitly
bound each collection with `take(n)` or `unbounded(reason)` and keep includes separate from locks.

## How to check

`dartway generate --check`, `dartway check`, and the project's database tests pass. Generation
reports no ambiguous relation and no unindexed FK warnings after the indexes are declared.
