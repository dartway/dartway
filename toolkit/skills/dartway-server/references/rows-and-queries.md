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
  @DwStateColumn(invoiceTransitions)
  final InvoiceStatus status;
  final DateTime? paidAt;
  final DateTime createdAt;

  static const tableDef = InvoiceTable();
}
```

- `id` is the stored key, `int`: `row.id` needs no `!` (`redundantBangAllowed` has the analyzer fail
  one). A row not stored yet is its generated draft `New<Entity>Row`; `insert`, `tryInsert`,
  `insertAll` take drafts and answer stored rows; `upsert` does too on tables without state columns.
- Columns: `int`, `double`, `String`, `bool`, `DateTime`, `DwCalendarDay`, `Duration`, `Uint8List`, an enum (its name),
  `List`/`Map<String, T>` of scalars or a `List` of an enum (`jsonb`), nullable ones. A DTO is not a
  column.
- `@DwForeignKey('table', onDelete: …)` (framework tables too: `dw_account`, `dw_stored_file`),
  `@DwUniqueColumn()`, `@DwColumnName('sql_name')`, `DwTableIndex([...], unique:)`,
  `@DwDefaultValue('sql')` for rows written without the column (existing rows when it is added) — a
  repository insert writes every column, so there the Dart default applies.
- "Create or save" by an optional id: read the row by id and owner with a lock, then
  `update(current.copyWith(...))`; `update(draft.withId(id))` only when the command carries every
  ordinary column without changing its state; on a table without state columns, a row keyed by a
  unique column is `upsert(draft, conflictOn: …)`.
- Append-only is a decision about the screen: answer which event applies an edit, how the person
  triggers it and what they see meanwhile, or do not choose it.

A changed row class: generate, then a migration when its SQL schema changes (`dartway-migrations`).

### Lifecycle state columns

The shared contract declares the enum and table together, for example:

```dart
enum InvoiceStatus { draft, sent, paid }

const invoiceTransitions = DwStateTransitions<InvoiceStatus>(
  initial: {InvoiceStatus.draft},
  moves: {
    InvoiceStatus.draft: {InvoiceStatus.sent},
    InvoiceStatus.sent: {InvoiceStatus.paid},
  },
);
```

A lifecycle status is a state column: declare a const `DwStateTransitions<StatusEnum>` beside the
non-null enum, then `@DwStateColumn(theTransitions)` on the row field and regenerate. `initial`
is the set of legal insert values; `moves` maps each source to its allowed destinations. Missing
sources are terminal, and self moves need an explicit entry.

Change it through `ctx.db.<rows>.transition(id, column: (t) => t.status, to: next)` or
`transitionWhere(where: ..., column: ..., to: next)`. One guarded SQL update returns the changed
row (null means missing/disallowed), or the changed rows for a bulk call. Compare their ids with
the requested ids to report rows that did not move. Translate this outcome to the feature's
refusal and publish only returned rows. A side effect follows a successful transition in the same
command transaction. Do not read then decide and write the status yourself.

`update` may change ordinary fields only and guards the supplied state. A missing id throws
`DwRowNotFound` on every table. An ordinary edit racing a transition throws the catchable
`DwStaleState`: translate it into the feature's conflict or let the server answer `dw.conflict`
(HTTP 409), without an incident. Re-read before deciding whether to retry; never replay blindly.
Generated stored-row `copyWith` throws `DwStateWriteException` for an intentional state change;
passing the same row's state unchanged is allowed, including inside `update`.
`updateWhere`/`updateWhereReturning` cannot assign state; insert/tryInsert/insertAll require initial
states; upsert/upsertAll on state tables are refused. `DwStateWriteException` means a programming
error. `stateWrittenDirectly` is an error for direct state writes through copyWith, ordinary writes
or raw SQL in server `lib/`; a migration's `m.backfill` is the explicit exception. The checker
reads source, so it cannot resolve arbitrary aliases or dynamic SQL; never use those to bypass it.

Tests at the owning feature's command boundary cover declared moves, refused moves, terminal
states and a real Postgres race where one competing transition wins. Tests can read the table's
`moves`; add a command-walking helper only if the feature has enough commands to make it useful.

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
final saved = await ctx.db.invoices.transition(
  row.id, column: (t) => t.status, to: InvoiceStatus.sent,
); // null: translate to the feature's refusal
```

Also `findById`, `findFirst`, `exists`, `count(distinct:)`, `maxBy`, `updateWhere`,
`updateWhereReturning` (the rows to publish), `delete`; conditions `equals`, `inList`, `gt`…,
`between`, `like`/`ilike` (escape `%`, `_`, `\` of typed text), `isEmptyList`, `contains`,
`containsAny`, combined with `&`, `|`, `not()`. `update` of a missing id throws `DwRowNotFound`; a failed state guard on an existing row throws
`DwStaleState`.

- **Every `find` in a request handler is bounded**: `request.readWhole((limit) => repo.find(limit: limit))`
  for a whole list, `limit: page.fetchLimit` for a page, or `unbounded: '<why the domain keeps it small>'` beside the read.
  One with neither is `unboundedRead`, a warning of `dartway check`; jobs,
  commands and migrations are not held to it.
- **Typed relations are derived from `@DwForeignKey`**, between row classes in this project's generation
  input. Import generated `dw_schema.dart`; `t.customer.displayName` works in `where` / `orderBy`,
  including chains. Reverse collections support `any`, `none`, `every` (true for no children), and
  `count(where: ...)` with numeric comparisons; they cannot be ordered directly.
- **Include related rows in the same statement**: `include: (t) => [t.customer, t.invoiceLines.take(20,
  orderBy: (l) => [l.id.asc()])]`. Nested to-one: `t.customer.include((c) => [c.organization])`;
  nested to-many uses `take(..., include: ...)`. An intentionally unbounded collection uses
  `.unbounded('<domain reason>')`. A bare to-many token is refused and warns with `unboundedRead`.
  Read with `row.one(InvoiceRow.tableDef.customer)` / `row.many(InvoiceRow.tableDef.invoiceLines)`;
  types follow the FK and an un-included relation throws. Include is available on `find`, `findFirst`,
  `findById`; it cannot be combined with a lock. It never changes the handler's access rule.
  FKs to tables without input row classes have no typed relations; framework tables use services.
- **An FK needs a leading index**: generation warns; add `DwTableIndex(['customerId'])`, regenerate
  and create a migration. A unique FK or a composite index starting with it already qualifies.
  Keep `findByIds` when ids are already known; avoid pre-reading unbounded ids to filter a relation.
- **An expected unique conflict is a value:** `tryInsert(draft, onConflict: DwOnConflict.doNothing((t)
  => [t.invoiceId]))` answers `null`, and the handler refuses.
- **Raw SQL** (`ctx.db.query(sql, params: {…})`, `ctx.db.execute`) only for what the repository cannot
  say — a window function, a CTE — over the project's tables, values always bound, never interpolated.
  Never over `dw_*` tables ([accounts](accounts.md)).

Ambiguous or colliding relation names warn and emit neither direction until `relation:` / `reverse:`
resolves them. Nullable to-one paths expose nullable column types, including grouped keys.
A collection `take(n)` without a nonempty order defaults to child primary-key order.
