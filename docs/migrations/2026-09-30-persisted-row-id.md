---
title: "A row's id is int; an insert takes the generated draft New<Entity>Row"
affects:
  dartway_orm: "0.21.0-dev.9"
  dartway_generator: "0.21.0-dev.9"
  dartway_core_server: "0.21.0-dev.9"
---

## Who is affected

Every project with a row class. `DwTableRow.id` is `int` now — a row is what the database stored,
so its id is never missing — and a row not stored yet is a different value: its draft,
`New<Entity>Row`, which `dartway generate` writes beside the row class. `insert`, `tryInsert`,
`insertAll` and `upsert` take drafts and answer stored rows; `update` takes a row as before.
An insert with an id of one's own is gone.

## What to change

Four steps, in this order; the first three are mechanical.

**1. Every row class** declares its id required and non-null:

    - const InvoiceRow({this.id, required this.amountCents, …});
    + const InvoiceRow({required this.id, required this.amountCents, …});

      @override
    - final int? id;
    + final int id;

then `dartway generate`. The generator refuses a row class still declaring `int?`.

**2. Every `!` on a row's id goes.** The analyzer reports each one as
`unnecessary_non_null_assertion`, and fixes them all:

    dart fix --apply --code=unnecessary_non_null_assertion

in the server package. A `!` on a data object's `int? id` (a "create or save" command) is not
reported and stays.

**3. Every construction of a row without an `id:` becomes its draft** — the analyzer reports it as
a missing required argument `id`:

    - await ctx.db.invoices.insert(InvoiceRow(amountCents: 100, …));
    + await ctx.db.invoices.insert(NewInvoiceRow(amountCents: 100, …));

The draft's constructor is the row's without `id`, with the same defaults. A list, a variable or a
helper that holds rows before `insertAll` is typed by the draft: `List<NewInvoiceRow>`,
`NewInvoiceRow draftOf(…)`.

**4. What the compiler still reports is a place that mixed the two**, and each one is a choice
rather than a rename:

- **"Create or save" by an optional id** — one row built with `id: command.id`, then `insert` or
  `update`:

      - final row = InvoiceRow(id: command.id, amountCents: command.amountCents);
      - final saved = command.id == null
      -     ? await ctx.db.invoices.insert(row)
      -     : await ctx.db.invoices.update(row);
      + final draft = NewInvoiceRow(amountCents: command.amountCents);
      + final saved = switch (command.id) {
      +   null => await ctx.db.invoices.insert(draft),
      +   final id => await ctx.db.invoices.update(draft.withId(id)),
      + };

  When the base is an existing row or a default (`(current ?? defaults).copyWith(…)`, then insert
  or update), `upsert(draft, conflictOn: …)` on the unique key usually says it in one statement.
- **A function that takes a row and is called before the insert** (a check, a notice built from the
  candidate) takes the draft when it runs only before, or the stored row when it can wait for the
  insert's answer — which is also the only one whose id can be published.
- **A test that builds a row in memory** to feed a mapper gives it an id: `InvoiceRow(id: 1, …)`.
- **An insert with an explicit id** (seeding fixed ids) inserts drafts and reads the ids back:
  a written id left the `bigserial` sequence behind the rows and failed the next insert.
- `row.id == null` checks are now always false: `unnecessary_null_comparison` and `dead_code`
  point at them; delete the branch.
- `row.copyWith(id: …)` is gone: a copy of a stored row is the same row. A new row with the same
  values is a draft, built from the fields it needs.

`template/` raises `unnecessary_non_null_assertion` to an error in the server and shared
`analysis_options.yaml`; to do the same:

    analyzer:
      errors:
        unnecessary_non_null_assertion: error

## How to check

`dartway generate --check` is clean, `dart analyze` in the server package reports nothing, and

    grep -rn '\.id!' lib test bin

lists only data objects' ids. No schema change: the tables are the same, so no migration is
written.
