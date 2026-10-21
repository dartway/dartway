## 2. Row classes

A row never leaves the server. Nullable only where the domain allows absence; money and other
histories are rows of their own, one per change.

```dart
part 'invoices_rows.dw.dart';

/// An invoice; deleting the owner's profile deletes it.
@DwSqlTable('invoice', indexes: [DwTableIndex(['ownerProfileId', 'createdAt'])])
final class InvoiceRow extends DwTableRow with _$InvoiceRow {
  const InvoiceRow({
    required this.id,
    required this.ownerProfileId,
    required this.amountCents,
    this.status = InvoiceStatus.draft,
    this.paidAt,
    required this.createdAt,
  });

  @override
  final int id;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int ownerProfileId;

  final int amountCents;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final DateTime createdAt;

  static const tableDef = InvoiceTable();
}
```

- `id` is the stored key, `int`: `row.id` needs no `!` (`redundantBangAllowed` has the analyzer fail
  one). A row not stored yet is its generated draft `New<Entity>Row`; `insert`, `tryInsert`,
  `insertAll`, `upsert` take drafts and answer stored rows.
- Columns: `int`, `double`, `String`, `bool`, `DateTime`, `DwCalendarDay`, `Duration`, `Uint8List`, an enum (its name),
  `List`/`Map<String, T>` of scalars or a `List` of an enum (`jsonb`), nullable ones. A DTO is not a
  column.
- `@DwForeignKey('table', onDelete: …)` (framework tables too: `dw_account`, `dw_stored_file`),
  `@DwUniqueColumn()`, `@DwColumnName('sql_name')`, `DwTableIndex([...], unique:)`,
  `@DwDefaultValue('sql')` for rows written without the column (existing rows when it is added) — a
  repository insert writes every column, so there the Dart default applies.
- "Create or save" by an optional id: read the row by id and owner with a lock, then
  `update(current.copyWith(...))`; `update(draft.withId(id))` only when the command carries every
  column; a row keyed by a unique column is `upsert(draft, conflictOn: …)`.
- Append-only is a decision about the screen: answer which event applies an edit, how the person
  triggers it and what they see meanwhile, or do not choose it.

A changed row class: generate, then a migration (`dartway-migrations`).

## 3. Queries

`ctx.db` (inside a transactional command, the transaction) has a generated repository per table:

```dart
final me = await ctx.profile;
final rows = await ctx.db.invoices.find(
  where: (t) => t.ownerProfileId.equals(me.id) & t.status.notEquals(InvoiceStatus.draft),
  orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
  limit: 50,
);
final byIds = await ctx.db.invoices.findByIds(ids);           // one statement
final open = await ctx.db.invoices.count(where: (t) => t.paidAt.isNull());
final byStatus = await ctx.db.invoices.countBy((t) => t.status);
final owed = await ctx.db.invoices.sumBy((t) => t.ownerProfileId, (t) => t.amountCents);
final latest = await ctx.db.invoices.findFirstPer((t) => t.ownerProfileId, orderBy: (t) => [t.createdAt.desc()]);
final saved = await ctx.db.invoices.update(row.copyWith(status: InvoiceStatus.sent));
```

Also `findById`, `findFirst`, `exists`, `count(distinct:)`, `maxBy`, `updateWhere`,
`updateWhereReturning` (the rows to publish), `delete`; conditions `equals`, `inList`, `gt`…,
`between`, `like`/`ilike` (escape `%`, `_`, `\` of typed text), `isEmptyList`, `contains`,
`containsAny`, combined with `&`, `|`, `not()`. `update` of a missing id throws `DwRowNotFound`.

- **No joins.** Related rows load with `findByIds`, one query per relation for the whole batch — never
  one per row.
- **An expected unique conflict is a value:** `tryInsert(draft, onConflict: DwOnConflict.doNothing((t)
  => [t.invoiceId]))` answers `null`, and the handler refuses.
- **Raw SQL** (`ctx.db.query(sql, params: {…})`, `ctx.db.execute`) only for what the repository cannot
  say — a window function, a CTE — over the project's tables, values always bound, never interpolated.
  Never over `dw_*` tables ([accounts](accounts.md)).
