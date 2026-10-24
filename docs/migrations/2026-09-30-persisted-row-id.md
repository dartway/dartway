---
title: "A row's id is int; an insert takes the generated draft New<Entity>Row"
affects:
  dartway_orm: "0.21.0-dev.12"
  dartway_generator: "0.21.0-dev.12"
  dartway_core_server: "0.21.0-dev.12"
---

## Who is affected

Every project with a row class. `DwTableRow.id` is `int` now — a row is what the database stored,
so its id is never missing — and a row not stored yet is a different value: its draft,
`New<Entity>Row`, which `dartway generate` writes beside the row class. `insert`, `tryInsert`,
`insertAll` and `upsert` take drafts and answer stored rows; `update` takes a row as before.
An insert with an id of one's own is gone. `dartway check` (`dartway_cli` 0.13.0) fails a server or
shared package whose `analysis_options.yaml` does not raise `unnecessary_non_null_assertion` to an
error (`redundantBangAllowed`).

## What to change

Five steps, in this order; the first four are mechanical.

**1. Every row class** declares its id required and non-null — `required`, not with a default:

    - const InvoiceRow({this.id, required this.amountCents, …});
    + const InvoiceRow({required this.id, required this.amountCents, …});

      @override
    - final int? id;
    + final int id;

then `dartway generate`. The generator refuses a row class whose id is `int?`, or `int` with a
default (`this.id = 0` is the sentinel a row no longer needs), and one whose constructor default it
cannot repeat in the draft. What it writes changes too:

- the row's `copyWith` no longer takes `id` — a copy of a stored row is the same row;
- beside it, the draft `New<Entity>Row`: the row's constructor without `id` and with the same
  defaults, a `copyWith`, `withId(id)`, and `==`, `hashCode` and `toString` by its columns — two
  drafts with the same columns are equal, as two rows are.

**2. The server and the shared package's `analysis_options.yaml`** raise the analyzer's diagnostic
for a `!` that means nothing — `dartway check` fails until they do:

    analyzer:
      errors:
        unnecessary_non_null_assertion: error

**3. Every `!` on a row's id goes.** The analyzer now reports each one, and fixes them all:

    dart fix --apply --code=unnecessary_non_null_assertion

in the server package. A `!` on a data object's `int? id` (a "create or save" command) is not
reported and stays.

**4. Every construction of a row without an `id:` becomes its draft** — the analyzer reports it as
a missing required argument `id`:

    - await ctx.db.invoices.insert(InvoiceRow(amountCents: 100, …));
    + await ctx.db.invoices.insert(NewInvoiceRow(amountCents: 100, …));

A list, a variable or a helper that holds rows before `insertAll` is typed by the draft:
`List<NewInvoiceRow>`, `NewInvoiceRow draftOf(…)`.

**5. What the compiler still reports is a place that mixed the two**, and each one is a choice
rather than a rename:

- **"Create or save" by an optional id** — one row built with `id: command.id`, then `insert` or
  `update`. `update(draft.withId(id))` only when the command carries **every** column of the row
  (an admin form over a table with no owner, no creation time, nothing another command sets):

      - final row = ClubServiceRow(id: command.id, title: command.title, …);
      - final saved = command.id == null
      -     ? await ctx.db.clubServices.insert(row)
      -     : await ctx.db.clubServices.update(row);
      + final draft = NewClubServiceRow(title: command.title, …);
      + final saved = switch (command.id) {
      +   null => await ctx.db.clubServices.insert(draft),
      +   final id => await ctx.db.clubServices.update(draft.withId(id)),
      + };

  Otherwise — the usual case — read the stored row by its id and its owner, and change what the
  command owns; `withId` on a draft built only from the command would overwrite the rest with the
  draft's defaults:

      final current = await ctx.db.invoices.findFirst(
        where: (t) => t.id.equals(id) & t.ownerProfileId.equals(me.id),
        lock: DwRowLock.forUpdate,
      );
      if (current == null) ctx.refuse(DwCoreRefusal.notFound);
      await ctx.db.invoices.update(current.copyWith(note: DwFieldPatch.set(command.note)));

  A row keyed by a unique column can use `upsert(draft, conflictOn: (t) => [t.profileId])`
  only when the draft carries every value to write: upsert replaces every non-key column.
  If the command changes only some columns, read the current row and preserve the rest, as above
  or with the shared-edit pattern below.
- **A function that takes a row and is called only before the insert** (a notice, a check, a
  helper building the candidate) takes the draft.
- **A function called both before and after the insert** — an extension computing from the
  columns, a policy reading stored settings or their defaults (`row ?? const New…Row(…)`) — needs
  one value shape for both. Use the draft for shared reads and edits, and project a stored row's
  columns into it once. [The example below](#sharing-code-before-and-after-insert) keeps one edit
  function and one derived-value extension, including when the edit reads stored state.
- **A test that builds a row in memory** to feed a mapper or a policy gives it an id:
  `InvoiceRow(id: 1, …)`.
- **An insert with an explicit id** (seeding fixed ids) inserts drafts and reads the ids back:
  a written id left the `bigserial` sequence behind the rows and failed the next insert.
- `row.id == null` checks are now always false: `unnecessary_null_comparison` and `dead_code`
  point at them; delete the branch.
- `row.copyWith(id: …)` is gone. A new row with the same values is a draft, built from the fields
  it needs.

## Sharing code before and after insert

The row and its draft have no common field interface. A project can use the draft as its value
snapshot: write one `toDraft()` extension on the stored row that copies **every column**, then put
shared edits and derived values on the draft. `toDraft()` here is project code, not generated API;
keep its field list with the row declaration when adding columns. The command's `applyTo` method
can take `NewInvoiceRow` and delegate to a helper like `applyInvoiceEdit` below. The field changes
are written once; no `applyToDraft` counterpart is needed.

In this example, the amount can change until the owner confirms it; the note remains editable.
In `invoice_rows.dart` (the row declaration and helpers are shown together here):

```dart
import 'package:dartway_core_server/dartway_core_server.dart';

part 'invoice_rows.dw.dart';

@DwSqlTable('invoice')
final class InvoiceRow extends DwTableRow with _$InvoiceRow {
  const InvoiceRow({
    required this.id,
    required this.ownerProfileId,
    this.amountCents = 0,
    this.ownerConfirmedAt,
    this.note,
  });

  @override
  final int id;
  final int ownerProfileId;
  final int amountCents;
  final DateTime? ownerConfirmedAt;
  final String? note;

  static const tableDef = InvoiceTable();
}

extension InvoiceDraftSnapshot on InvoiceRow {
  NewInvoiceRow toDraft() => NewInvoiceRow(
    ownerProfileId: ownerProfileId,
    amountCents: amountCents,
    ownerConfirmedAt: ownerConfirmedAt,
    note: note,
  );
}

NewInvoiceRow applyInvoiceEdit(
  NewInvoiceRow row, {
  required int amountCents,
  DwFieldPatch<String> note = const DwFieldPatch.keep(),
}) => row.copyWith(
  amountCents: row.ownerConfirmedAt == null ? amountCents : row.amountCents,
  note: note,
);

extension InvoiceDerivedValues on NewInvoiceRow {
  bool get needsOwnerConfirmation => amountCents > 0 && ownerConfirmedAt == null;
}
```

On creation, pass the defaults to the edit once, then insert the result:

```dart
final draft = applyInvoiceEdit(
  NewInvoiceRow(ownerProfileId: me.id),
  amountCents: command.amountCents,
  note: DwFieldPatch.set(command.note),
);
final saved = await ctx.db.invoices.insert(draft);
```

On an update, read the row by id and owner under the transaction's lock as in step 5. A requested
id that was not found is a refusal, not a reason to insert. Pass **that row's snapshot**, rather
than fresh defaults, to the same edit, and retain its id:

```dart
final edited = applyInvoiceEdit(
  current.toDraft(),
  amountCents: command.amountCents,
  note: DwFieldPatch.set(command.note),
);
final saved = await ctx.db.invoices.update(edited.withId(current.id));
```

The edit can read `ownerConfirmedAt` in either path; the snapshot preserves it and the owner even
though the command carries neither. A nullable field still uses `DwFieldPatch.keep()` to preserve
it and `DwFieldPatch.clear()` to clear it. Keep the read, edit and update in the same transaction
so a concurrent writer cannot change a column between the snapshot and the write.

Derived values use the same extension before insertion (`draft.needsOwnerConfirmation`) and after
it (`saved.toDraft().needsOwnerConfirmation`). If a derived value needs an id, it belongs on the
stored row instead. Upsert is suitable only for a complete replacement of non-key columns; it does
not merge a partial command with the stored values.

## How to check

`dartway generate --check` is clean, `dartway check` reports no `redundantBangAllowed`,
`dart analyze` in the server package reports nothing, and

    grep -rn '\.id!' lib test bin

lists only data objects' ids. No schema change: the tables are the same, so no migration is
written.
