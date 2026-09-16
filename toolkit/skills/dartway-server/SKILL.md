---
name: dartway-server
description: >-
  The server package (__SERVER_PKG__) of a DartWay project: row classes (`<Entity>Row extends
  DwTableRow`, @DwSqlTable, DwTableIndex, @DwForeignKey, @DwUniqueColumn, @DwColumnName,
  @DwDefaultValue) and the generated `db.<plural>` repositories; queries (find/findFirst/findById/
  findByIds/count/exists, insert/tryInsert with DwOnConflict, update/updateWhere/delete), no joins —
  related rows by findByIds per relation; row locks (DwRowLock.forUpdate) inside transactional
  commands; mapping rows to data objects in batch; one DwCallHandler per request and command
  (single/maybe/list/page/table/window/command) with its access rule; the DwCallContext (memo for
  the caller's profile and role, ctx.refuse, ctx.publish after commit, ctx.transaction, jobs,
  accounts, files); background jobs (DwJobDefinition, DwRecurringJob); DwHttpRoute for external doors
  only; auth hooks in DwAuthConfig (onAccountCreated creates the profile in the same transaction,
  onIdentifierChanged); DwAccountService instead of SQL on dw_* tables; the fixed lib/ layout.
  Use when writing or changing a handler, a row class, a query, a job, a route or sign-in hooks.
---

# DartWay — the server (`__SERVER_PKG__`)

The server is a `DwAppServer`: the protocol from `__SHARED_PKG__`, the schema and migrations, one
handler per request and command, channel rules, auth hooks, jobs, routes, file storage. There are no
endpoints to write and no generic create-read-update layer: every call the app can make is a DTO in the contract with a
handler here that says who may make it and what it does.

Related skills: `dartway-contract` (the DTOs handled here), `dartway-access` (access rules, roles,
keys), `dartway-realtime` (what to publish where), `dartway-migrations` (schema changes),
`dartway-uploads` (`ctx.files`, upload rules), `dartway-testing`.

## 1. Layout

```
__SERVER_PKG__/
  bin/server.dart          starts the server from the environment
  bin/migrate.dart         apply | rollback | status | create <name> | check | rehash
  bin/seed_dev.dart        development data
  lib/__SERVER_PKG__.dart  the library: builds the DwAppServer
  lib/generated/           written by `dartway generate` — never edited
  lib/src/                 everything else
  lib/src/migrations/      fixed: migration files and migrations.dart
  test/
```

The top level of `lib/` is closed: the package library, `generated/`, `src/`. Anything else there —
and a missing `lib/src/migrations/migrations.dart` — is `invalidTopLevelLayout`, an error of
`dartway check`. Inside `src/` arrange by the domain; the skeleton keeps row classes in `entities/`,
handlers in `handlers/` (a list per area), and one file each for the auth config, the context
extension, the channel rules, the upload rules, rows → data objects, and publications.

## 2. Row classes

A row is a table row as a Dart value. **It never leaves the server**: handlers map it to a data object.

```dart
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:__SHARED_PKG__/__SHARED_PKG__.dart';

part 'invoices.dw.dart';

/// An invoice. Its owner is a member profile; deleting the profile deletes
/// its invoices.
@DwSqlTable(
  'invoice',
  indexes: [
    DwTableIndex(['ownerProfileId', 'createdAt']),
  ],
)
final class InvoiceRow extends DwTableRow with _$InvoiceRow {
  const InvoiceRow({
    this.id,
    required this.ownerProfileId,
    required this.customerId,
    required this.amountCents,
    this.status = InvoiceStatus.draft,
    this.note,
    this.paidAt,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwForeignKey('member_profile', onDelete: DwOnDelete.cascade)
  final int ownerProfileId;

  @DwForeignKey('customer', onDelete: DwOnDelete.restrict)
  final int customerId;

  final int amountCents;
  final InvoiceStatus status;
  final String? note;
  final DateTime? paidAt;
  final DateTime createdAt;

  static const tableDef = InvoiceTable();
}
```

The generator holds you to:

- the name `<Entity>Row`; its table class is `<Entity>Table`, its repository `db.<entities>`;
- `@DwSqlTable('<snake_case>')`, and `static const tableDef = <Entity>Table();`;
- `@override final int? id;` with `this.id` — a `bigserial` key, `null` until inserted;
- column types: `int`, `double`, `String`, `bool`, `DateTime`, `Duration`, `Uint8List`, an enum
  (stored as its name in `text`), `List<T>`/`Map<String, T>` of scalars (`jsonb`), or nullable ones.
  A DTO is not a column: store its fields, or the id of another row.

Annotations: `@DwForeignKey('table', onDelete: DwOnDelete.cascade | setNull | restrict | noAction)`
on an `int`/`int?` field (framework tables too: `dw_account`, `dw_stored_file`); `@DwUniqueColumn()`;
`@DwColumnName('sql_name')` when snake_case of the field is wrong; `DwTableIndex([...fields],
unique:)` in the table annotation; `@DwDefaultValue('sql')` for a database-side default — it fills
rows written without the column (existing rows when the column is added); a repository insert
always writes every column.

**Nullable only when the value can really be absent** in the domain, never for a form's convenience.
Money and other histories are rows of their own (one row per change), not a field overwritten in
place. Rebuild a stored row with its generated `copyWith`, never by listing fields in the
constructor — a field added later silently takes its default in every row that path writes.

After changing a row class: `dartway generate`, then `dart run bin/migrate.dart create <name>` from
`__SERVER_PKG__`, review the draft it writes, apply — `dartway-migrations`.

## 3. Queries

`ctx.db` is a `DwDatabaseHandle`; inside a transactional command it is the transaction. The
repositories are generated extension getters (`lib/generated/dw_schema.dart`):

```dart
final me = await ctx.callerProfile;
final rows = await ctx.db.invoices.find(
  where: (t) =>
      t.ownerProfileId.equals(me.id!) & t.status.notEquals(InvoiceStatus.draft),
  orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
  limit: 50,
);
final one = await ctx.db.invoices.findById(invoiceId);
final first = await ctx.db.invoices.findFirst(where: (t) => t.note.isNull());
final some = await ctx.db.invoices.findByIds(ids);        // one statement; index the result by id
final open = await ctx.db.invoices.count(where: (t) => t.paidAt.isNull());
final any = await ctx.db.invoices.exists(where: (t) => t.note.ilike('%urgent%'));

final created = await ctx.db.invoices.insert(InvoiceRow(/* … */));   // returns it with its id
final saved = await ctx.db.invoices.update(row.copyWith(status: InvoiceStatus.sent));
await ctx.db.invoices.updateWhere(
  where: (t) => t.status.equals(InvoiceStatus.draft),
  set: (t) => [t.note.set(null)],
);
await ctx.db.invoices.delete(invoiceId);
```

Conditions: `equals`, `notEquals`, `isNull`, `isNotNull`, `inList`, `notInList`, `gt/gte/lt/lte`,
`between`, `like`, `ilike`, combined with `&`, `|`, `not()`. Values are always bound parameters. Escape
`%`, `_` and `\` in text a user typed before putting it into a `like` pattern. `update` of a missing
id throws `DwRowNotFound` — an update that changed nothing is a failure.

**There are no joins and no includes.** Related rows load with `findByIds`, one query per relation
for the whole batch — never one query per row (section 5).

**An expected unique conflict is not an exception:** `tryInsert` answers `null` when the row conflicts,
so the handler refuses cleanly instead of failing (here a payment row whose `invoiceId` is
`@DwUniqueColumn()`):

```dart
final paid = await ctx.db.invoicePayments.tryInsert(
  InvoicePaymentRow(invoiceId: invoice.id!, paidAt: DateTime.now()),
  onConflict: DwOnConflict.doNothing((t) => [t.invoiceId]),
);
if (paid == null) ctx.refuse(AppRefusal.invoiceAlreadyPaid);
```

**Raw SQL** (`ctx.db.query(sql, params: {...})` → `DwResultRow`, `ctx.db.execute`) is for what the
repository cannot say — an aggregate, a window function — over the project's own tables. Never over
the framework's `dw_*` tables: accounts, identities and keys go through `DwAccountService`
(section 9).

## 4. Handlers — one per call

A handler list per area, registered in `DwAppServer(handlers: [...])`. The server refuses to start
when a registered request or command has no handler, has two, or when an access check is written
for another call class.

| Call | Factory | Your function answers |
|---|---|---|
| `DwSingleRequest<T>` | `DwCallHandler.single<Q, T>(access:, handle:)` | `Future<T?>` — `null` is refused as `dw.notFound` |
| `DwMaybeRequest<T>` | `DwCallHandler.maybe<Q, T>(access:, handle:)` | `Future<T?>` — `null` is an answer |
| `DwListRequest<T>` | `DwCallHandler.list<Q, T>(access:, handle:)` | `Future<List<T>>` |
| `DwPageRequest<T>` | `DwCallHandler.page<Q, T>(access:, handle: (ctx, request, page))` | up to `page.fetchLimit` rows after `page.offset` |
| `DwTableRequest<T>` | `DwCallHandler.table<Q, T>(access:, rows: (ctx, request, table), count: (ctx, request))` | rows: up to `table.fetchLimit` after `table.offset`; count: every matching row |
| `DwWindowRequest<T, S, I>` | `DwCallHandler.window<Q, T, S, I>(access:, handle: (ctx, request, window))` | one direction at a time, at most `window.fetchLimit` |
| `DwActionCommand<R>` | `DwCallHandler.command<C, R>(access:, handle:, transactional:)` | `Future<R>` |

`fetchLimit` is one row past the page: the framework trims it and learns "has more" without counting,
and asks `count` only when the rows cannot tell the total. Reading more rows than `fetchLimit` fails
the call. A window handler reads `older` rows (below `window.position`, or at it when
`window.includesPosition`, newest first) or `newer` rows (above it, oldest first), comparing
`(sortValue, id)` as a pair — the framework composes a window around an anchor from both and builds
the cursors with the request's `positionOf`.

```dart
final invoiceHandlers = <DwCallHandler>[
  DwCallHandler.list<ListMyInvoices, CustomerInvoice>(
    // "My" invoices name no account: the caller's are the only ones read.
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final me = await ctx.callerProfile;
      return InvoiceObjects.invoices(
        ctx,
        await ctx.db.invoices.find(
          where: (t) => t.ownerProfileId.equals(me.id!),
          orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
        ),
      );
    },
  ),

  DwCallHandler.single<GetInvoice, CustomerInvoice>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final row = await ctx.db.invoices.findById(request.invoiceId);
      // Someone else's invoice does not exist for the caller.
      if (row == null || row.ownerProfileId != (await ctx.callerProfile).id) {
        return null;
      }
      return InvoiceObjects.invoice(ctx, row);
    },
  ),

  DwCallHandler.command<PayInvoice, CustomerInvoice>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final me = await ctx.callerProfile;
      final row = await ctx.db.invoices.findById(
        command.invoiceId,
        lock: DwRowLock.forUpdate,
      );
      if (row == null || row.ownerProfileId != me.id) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      if (row.status == InvoiceStatus.paid) {
        ctx.refuse(AppRefusal.invoiceAlreadyPaid);
      }
      final paid = await ctx.db.invoices.update(
        row.copyWith(
          status: InvoiceStatus.paid,
          paidAt: DwFieldPatch.set(DateTime.now()),
        ),
      );
      // Publishes the invoice to every channel that shows it and answers it
      // as clients see it — `dartway-realtime`.
      return publishInvoice(ctx, paid);
    },
  ),
];
```

What the framework has done before your function runs: decoded the body, checked sign-in, run
`validate()`, run the access check — in that order. Don't repeat them.

### Commands and transactions

A command is **transactional by default**: its access check, the handler and the idempotency record
run in one database transaction.

- **A refusal rolls back.** Refusing after writing is safe: the writes are undone, and the refusal
  is recorded so a retry of the same intent answers the same.
- **Lock what you read to change.** `findById(id, lock: DwRowLock.forUpdate)` (also `find`/`findFirst`)
  makes a concurrent command on the same row wait, so "check, then write" cannot interleave. A lock
  outside a transaction throws — it would end with the statement. Lock the row every competing
  command goes through (the parent whose counter moves, the invoice being paid).
- **The transaction may be retried** on a serialization conflict: the handler runs again from the
  start with a fresh `memo` and no publications. Nothing inside a transactional handler may have
  effects outside the database — no HTTP calls, no e-mails. For a handler that calls an external
  service, `transactional: false`, and open `ctx.transaction((tx) async { … })` around the writes;
  or enqueue a job (section 7), which joins the transaction.
- **Publications are delivered after commit** (`ctx.publish`) — never from a rolled-back attempt.

A request handler is a read: `ctx.publish`, `ctx.revoke` and writes with side effects have no place
there (publishing from a request throws).

## 5. Rows → data objects, in batch

Mapping lives in one place per domain area, as batch functions: a single object is a batch of one.
Load each relation once for all rows — `findByIds`, `ctx.accounts.listIdentitiesOf`,
`ctx.files.publicUrls` — then assemble.

```dart
abstract final class InvoiceObjects {
  static Future<List<CustomerInvoice>> invoices(
    DwCallContext ctx,
    List<InvoiceRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final customers = {
      for (final customer in await ctx.db.customers.findByIds(
        rows.map((row) => row.customerId),
      ))
        customer.id!: customer,
    };
    return [
      for (final row in rows)
        CustomerInvoice(
          id: row.id!,
          customerName: customers[row.customerId]!.name,
          amountCents: row.amountCents,
          status: row.status,
          createdAt: row.createdAt,
          note: row.note,
        ),
    ];
  }

  static Future<CustomerInvoice> invoice(DwCallContext ctx, InvoiceRow row) async =>
      (await invoices(ctx, [row])).single;
}
```

Everything that returns or publishes a given data object goes through the same function, so every
exit of the server shows the object the same way.

## 6. The call context

`DwCallContext` is one per call: `accountId` / `requireAccountId`, `sessionKey`, `db`, `protocol`,
`transaction`, `publish`, `revoke`, `refuse`, `jobs`, `accounts`, `files`, `log`, `memo`.

**The project's notions of "the caller" are an extension, cached per call with `memo`** — the
framework knows an account, the profile and the role are the project's:

```dart
extension CallerContext on DwCallContext {
  /// The caller's profile, read once per call.
  Future<MemberProfileRow> get callerProfile => memo(#callerProfile, () async {
    final accountId = requireAccountId;
    final profile = await db.memberProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    // Created with the account, in its transaction: absence is a broken
    // invariant, not a state a caller can be in.
    return profile ?? (throw StateError('Account $accountId has no profile'));
  });

  Future<bool> get isManager async =>
      (await callerProfile).role == MemberRole.manager;
}
```

The skeleton ships one such extension with the admin role; extend it rather than reading the profile
again in every handler. Access rules built on it — `dartway-access`.

- `ctx.refuse(code, field:, params:)` returns `Never`: a guard reads `if (row == null) ctx.refuse(…);`
  and `row` is non-null after it. A refusal is an answer for the user and never alerts.
- Anything else thrown is a failure: the caller gets an incident id, the operator gets the exception
  and an alert. Do not catch and swallow to "keep going".
- `ctx.log` for the operator; never log codes, tokens or personal data.

## 7. Jobs

Work that runs later or on a timer is a job, declared in `DwAppServer(jobs: [...])`:

```dart
final appJobs = <DwJobDefinition>[
  DwJobDefinition(
    'invoice.remind',
    handle: (ctx, payload) async {
      final invoice = await ctx.db.invoices.findById(payload['invoiceId']! as int);
      if (invoice == null || invoice.status == InvoiceStatus.paid) return;
      // … send the reminder, publish what changed
    },
  ),
  DwRecurringJob(
    'invoice.mark_overdue',
    every: const Duration(hours: 1),
    handle: (ctx) async { /* … */ },
  ),
];
```

Enqueue from a command: `await ctx.jobs.enqueue('invoice.remind', {'invoiceId': id}, runAt: …, key: …)`.
The enqueue joins the command's transaction (no row if it rolls back); a `key` deduplicates pending
jobs. A queued job is transactional by default (the job row disappears exactly when its work commits);
`transactional: false` for jobs that call external services, which may then run twice after a crash.
A job has no caller (`accountId` is `null`): it reads what it needs from its payload, and it may
publish. Names starting with `dw.` are the framework's.

## 8. Routes — external doors only

The app never calls a route: it calls DTOs. A `DwHttpRoute` exists for callers that cannot speak the
contract — a payment webhook, a file download link, a health probe of a partner:

```dart
DwHttpRoute.post('/webhooks/payments', (ctx, request) async {
  final body = await request.json();
  // verify the sender's signature, then write, publish, enqueue
  return DwHttpResponse.empty();
});
```

Registered in `DwAppServer(routes: [...])`, matched by exact path; `/dw/…` and `/health` are the
framework's. `auth:` is `DwRouteAuth.none` by default (the sender proves itself otherwise);
`optional`/`required` read `Authorization: Bearer` like a call. A refusal thrown in a route is
answered as JSON with its status; anything else as `500` with an incident id.

## 9. Sign-in hooks and accounts

The framework owns accounts, identifiers and session keys; the project owns what an account means to
it. `DwAuthConfig` in `lib/src/`:

- `normalize` — the one form of an identifier, the same function the app applies (it lives in
  `__SHARED_PKG__`);
- `deliverCode` — sends the code (SMS, e-mail); runs inside the transaction recording the ticket;
- `fixedCode` — a fixed code for store reviewers and test accounts;
- **`onAccountCreated(ctx, accountId, kind, identifier, origin)` creates the project's profile row in
  the same transaction** as the account, so a signed-in account without a profile cannot exist.
  `origin` is `DwSignInOrigin(registration)` — what the app sent with the code, the place to check
  consents — or `DwToolOrigin()` for `DwAccountService.ensure` (a seed, an admin bootstrap), which
  accepted nothing on anyone's behalf. **Refusing here refuses the sign-in** and creates nothing;
  the code stays usable;
- `onIdentifierChanged(ctx, change)` runs in the transaction of every identifier change the framework
  makes to an existing account (a confirmed attach or replace, `moveIdentities`, `removeIdentities`)
  — the place to mirror an identifier into a project row, or to republish the profile that shows it.
  The framework publishes nothing about identifiers itself.

For everything else about accounts use **`DwAccountService`**, never SQL on `dw_account`,
`dw_identity` or `dw_auth_key`:

| Where the code runs | Service |
|---|---|
| a handler, job or route | `ctx.accounts` — joins the call's transaction |
| next to a started server (a startup bootstrap) | `server.accounts` |
| a script with no server (a seed) | `DwAccountService(db, auth)` |

It offers `ensure`, `find`, `listIdentities`, `listIdentitiesOf` (batch), `accountsMatching` (an admin
search box), `moveIdentities`, `removeIdentities`, `issueKey`, `listKeys`, `revokeKey`, `revokeKeys`
— keys and revocation in `dartway-access`.

## 10. Checks

```bash
dartway generate --check      # generated code matches the sources
dart run bin/migrate.dart check   # from __SERVER_PKG__, with DW_DATABASE_* set: migrations replay into the declared schema
dartway test                  # server tests against a throwaway Postgres (and storage)
dartway check                 # layout, generated code, migrations drift (with DW_DATABASE_*), and the Flutter checks
```

A server test starts the real server on a throwaway database and calls it with real clients
(`DwTestServer`, `DwTestDatabase` from `package:dartway_core_server/testing.dart`); the skeleton's
`test/support/` harness signs members in. Every handler gets a test of what it does and a refused
call per access rule — `dartway-testing`, `dartway-access`.

## Checklist

- [ ] Every new request and command has exactly one handler with an explicit access rule.
- [ ] "Someone else's" rows answer `notFound` (single: return `null`).
- [ ] Commands lock the row competing commands go through; no external IO inside a transactional
      handler.
- [ ] Rows map to data objects through one batch function per area; relations by `findByIds`,
      never a query per row.
- [ ] Expected conflicts use `tryInsert` + `DwOnConflict`, not a caught exception.
- [ ] Every object a command changed is published to every channel that shows it (`dartway-realtime`).
- [ ] No SQL on `dw_*` tables; accounts through `DwAccountService`.
- [ ] A new profile is created in `onAccountCreated`, in the account's transaction.
- [ ] Row class changed → `dartway generate`, migration drafted and reviewed.
- [ ] `dartway test` and `dartway check` pass.
