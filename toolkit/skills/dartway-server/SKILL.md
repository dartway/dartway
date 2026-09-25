---
name: dartway-server
description: >-
  The server package (__SERVER_PKG__) of a DartWay project: row classes (`<Entity>Row extends
  DwTableRow`, @DwSqlTable, DwTableIndex, @DwForeignKey, @DwUniqueColumn, @DwColumnName,
  @DwDefaultValue) and the generated `db.<plural>` repositories; queries (find/findFirst/findById/
  findByIds/count/exists, countBy/sumBy/maxBy/findFirstPer, insert/tryInsert with DwOnConflict/upsert,
  update/updateWhere/updateWhereReturning/delete, jsonb list conditions), no joins —
  related rows by findByIds per relation; row locks (DwRowLock.forUpdate) inside transactional
  commands; mapping rows to data objects in batch; one DwCallHandler per request and command
  (single/maybe/list/page/table/window/command) with its access rule; the DwCallContext (memo for
  the caller's profile and role, ctx.refuse, ctx.publish after commit, ctx.transaction, jobs,
  accounts, files); background jobs (DwJobKind, DwQueuedJob, DwRecurringJob); DwHttpRoute for external doors
  only; auth hooks in DwAuthConfig (onAccountCreated creates the profile in the same transaction,
  onIdentifierChanged); DwAccountService instead of SQL on dw_* tables; the fixed lib/ layout.
  Use when writing or changing a handler, a row class, a query, a job, a route or sign-in hooks.
---

# DartWay — the server (`__SERVER_PKG__`)

The server is a `DwAppServer`: the protocol from `__SHARED_PKG__`, the schema and migrations, one
handler per request and command, channel rules, jobs and routes grouped by feature, auth hooks, file storage. There are no
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
  bin/seed_dev.dart        development data: starts this server on port 0 and
                           works in a real context, so the project's own auth
                           creates the accounts
  lib/__SERVER_PKG__.dart  the library: builds the DwAppServer
  lib/generated/           written by `dart run dartway_cli:dartway generate` — never edited
  lib/src/core/            fixed: auth hooks, the caller and access rules, channel
                           addresses, upload rules, startup steps
  lib/src/migrations/      fixed: migration files and migrations.dart
  lib/src/<feature>/       one folder per area of the app:
    <feature>_feature.dart     its DwServerFeature — handlers, channel rules, jobs, routes
    <feature>_rows.dart        its row classes
    <feature>_handlers.dart    one handler per request and command
    <feature>_objects.dart     rows → data objects, in batch
    <feature>_publications.dart  what a change publishes, and to whom
    …                          anything else the area needs, subfolders when it grows
  test/
```

The top level of `lib/` is closed: the package library, `generated/`, `src/`. **So is `src/`: folders
only — `core/`, `migrations/` and one per feature**, each declaring its `DwServerFeature` in
`<feature>_feature.dart`, and the server lists the features: `DwAppServer(features: [...])`. A file at
the top of `src/`, a layer folder (`handlers/`, `rows/`, `entities/`, `domain/`, `objects/`,
`services/`) or a feature folder without its declaration is `invalidTopLevelLayout`, an error of
`dart run dartway_cli:dartway check`. A feature split across layers ends up in four places, with a
`chat/` beside a `domain/chat/` and two rules for who is in a chat: the whole area lives in its
folder, and what two features share lives in the one that owns it (the profile's objects in
`profile/`) or in `core/`.

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
  (stored as its name in `text`), `List<T>`/`Map<String, T>` of scalars (`jsonb`), `List<E>` of an enum (`jsonb` of names — not a `List<String>` with a typed getter), or nullable ones.
  A DTO is not a column: store its fields, or the id of another row.

Annotations: `@DwForeignKey('table', onDelete: DwOnDelete.cascade | setNull | restrict | noAction)`
on an `int`/`int?` field (framework tables too: `dw_account`, `dw_stored_file`); `@DwUniqueColumn()`;
`@DwColumnName('sql_name')` when snake_case of the field is wrong; `DwTableIndex([...fields],
unique:)` in the table annotation; `@DwDefaultValue('sql')` for a database-side default — it fills
rows written without the column (existing rows when the column is added); a repository insert
always writes every column.

**Nullable only when the value can really be absent** in the domain, never for a form's convenience.
Money and other histories are rows of their own (one row per change), not a field overwritten in
place.

**Append-only is a decision about the screen, not about storage.** A table that never updates its rows
means an edit takes effect only at some event. Before choosing it, answer **what event** applies an
edit, **how the person triggers it**, and **what they see in between** — without all three the form
accepts input and nothing visible happens, which is worse than a disabled form. Usually the "fixed
state" revisions were wanted for already exists as an entity (a cycle, an order, a document version),
and copying a few fields into it is cheaper than a history nobody reads.

Rebuild a stored row with its generated `copyWith`, never by listing fields in the
constructor — a field added later silently takes its default in every row that path writes.

After changing a row class: `dart run dartway_cli:dartway generate`, then `dart run bin/migrate.dart create <name>` from
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
final payers = await ctx.db.invoices.count(distinct: (t) => t.ownerProfileId); // people, not rows
final byStatus = await ctx.db.invoices.countBy((t) => t.status);    // Map<InvoiceStatus, int>
final owed = await ctx.db.invoices.sumBy((t) => t.ownerProfileId, (t) => t.amount);
final latest = await ctx.db.invoices.findFirstPer(                  // Map<int, InvoiceRow>
  (t) => t.ownerProfileId,
  orderBy: (t) => [t.createdAt.desc()],
);

final created = await ctx.db.invoices.insert(InvoiceRow(/* … */));   // returns it with its id
final saved = await ctx.db.invoices.update(row.copyWith(status: InvoiceStatus.sent));
await ctx.db.invoices.updateWhere(
  where: (t) => t.status.equals(InvoiceStatus.draft),
  set: (t) => [t.note.set(null)],
);
await ctx.db.invoices.delete(invoiceId);
```

Conditions: `equals`, `notEquals`, `isNull`, `isNotNull`, `inList`, `notInList`, `gt/gte/lt/lte`,
`between`, `like`, `ilike`, on a list column `isEmptyList`, `isNotEmptyList`, `contains`,
`containsAny`, combined with `&`, `|`, `not()`. An aggregate or a condition on a list over one table
is the repository's — raw SQL for it spells enum values as literals that break silently on a
rename. `upsert(row, conflictOn: (t) => [t.key])` is "insert or overwrite" in one statement, and
`updateWhereReturning` answers the updated rows to publish. Values are always bound parameters. Escape
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

A handler list per feature, registered in its `DwServerFeature(handlers: [...])`. The server refuses to start
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
    // Someone else's invoice does not exist for the caller: `dw.notFound`.
    access: DwAccessRule.resource<GetInvoice, InvoiceRow>(
      load: (ctx, request) => ctx.db.invoices.findById(request.invoiceId),
      allows: (ctx, request, row) async =>
          row.ownerProfileId == (await ctx.callerProfile).id,
    ),
    handle: (ctx, request) =>
        InvoiceObjects.invoice(ctx, ctx.accessed<InvoiceRow>()),
  ),

  DwCallHandler.command<PayInvoice, CustomerInvoice>(
    access: DwAccessRule.resource<PayInvoice, InvoiceRow>(
      // Locked: the rule runs inside the command's transaction.
      load: (ctx, command) =>
          ctx.db.invoices.findById(command.invoiceId, lock: DwRowLock.forUpdate),
      allows: (ctx, command, row) async =>
          row.ownerProfileId == (await ctx.callerProfile).id,
    ),
    handle: (ctx, command) async {
      final row = ctx.accessed<InvoiceRow>();
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

Work that runs later or on a timer is a job, declared in its feature's `DwServerFeature(jobs: [...])`:

```dart
/// What a job is — name and payload codec — imported by whatever enqueues it.
abstract final class InvoiceJobs {
  static const remind = DwJobKind<({int invoiceId})>(
    'invoice.remind',
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(({int invoiceId}) p) => {'invoiceId': p.invoiceId};
  static ({int invoiceId}) _decode(Map<String, Object?> json) =>
      (invoiceId: json['invoiceId']! as int);
}

final appJobs = <DwJobDefinition>[
  DwQueuedJob(
    InvoiceJobs.remind,
    handle: (ctx, p) async {
      final invoice = await ctx.db.invoices.findById(p.invoiceId);
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

Enqueue from a command by the kind, never by a string:
`await ctx.jobs.enqueue(InvoiceJobs.remind, (invoiceId: id), runAt: …, key: …)`. The payload is
spelled as a map once, in the kind's codec — never `payload['x']! as int` in a handler.
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

Registered in a feature's `DwServerFeature(routes: [...])`, matched by exact path; `/dw/…` and `/health` are the
framework's. `auth:` is `DwRouteAuth.none` by default (the sender proves itself otherwise);
`optional`/`required` read `Authorization: Bearer` like a call. A refusal thrown in a route is
answered as JSON with its status; anything else as `500` with an incident id.

A door that acts **for a signed-in person** (an MCP endpoint holding their key) does not reimplement
calls and never posts to its own port: `server.callAs(call, token: …, idempotencyKey: …)` runs the
contract call in process — access, validation, idempotency, transaction, publications — and answers
`DwCallResult<R>`.

**A silent rejection at a boundary like this one leaves a trace naming its own step.** A webhook
signature that does not verify, a payload shaped for another version, a sender this route does not
recognise — reject it, but as a value from an enum naming *which* check turned it away, not a
boolean or a sentence listing every possibility: `notAMessageEvent`, `foreignOrigin`,
`versionMismatch`, `unknownType`, each carrying what it means (`unknownType` reads as "the other
side is newer", not as a fault) rather than restating its own name. No secrets and no payloads in
it — a trace that carries the body is a log nobody can be shown. `dartway_studio_bridge`'s
`StudioMessageDropReason` is the shape to copy, tested member by member: a drop reason is written
when something goes wrong and read months later, the worst combination for a value nobody exercises.
This is a default, not a law — `dart run dartway_cli:dartway check` cannot see it, and a route with
a better answer for its own boundary may use one — but a rejection indistinguishable from every
other reason nothing arrived is a cost worth naming when you review one.

## 9. Sign-in hooks and accounts

The framework owns accounts, identifiers and session keys; the project owns what an account means to
it. `DwAuthConfig` in `lib/src/`:

- `normalize` — the one form of an identifier, the same function the app applies (it lives in
  `__SHARED_PKG__`);
- `generateCode` — the code this request gets; `null` (the default) draws random digits. A project
  returns one of its own for a fixed code — store reviewers, test accounts, a default code out of
  its own settings;
- `deliverCode` — sends the code (SMS, e-mail); called **always**, after the ticket's own
  transaction has committed (`ctx.db` here is a fresh pooled connection, not that transaction),
  whatever the code is — deciding not to send (a fixed code, most often) is this hook's own choice,
  independent of `generateCode` (issue #310). A throw or a refusal here no longer undoes the
  ticket — it is already written and counted against the limit;
- **`onAccountCreated(ctx, accountId, kind, identifier, origin)` creates the project's profile row in
  the same transaction** as the account, so a signed-in account without a profile cannot exist.
  `origin` is `DwSignInOrigin(registration)` — what the app sent with the code, the place to check
  consents — or `DwToolOrigin()` for `DwAccountService.ensure` (a seed, an admin bootstrap), which
  accepted nothing on anyone's behalf. **Refusing here refuses the sign-in** and creates nothing;
  the code stays usable;
- **`accountDeletion` says who may delete an account**, and it is required: `byMember` answers
  `DwDeleteMyAccount` (required by app stores for an app people sign up in), `byOperator` refuses it
  and leaves deletion to server code (`ctx.accounts.deleteAccount`). Never refuse the command from
  `onAccountDeleting` to switch it off — that refuses the operator too;
- **`onAccountDeleting(ctx, accountId)` deletes or anonymises the project's rows** when the account is
  deleted (`DwDeleteMyAccount`, `ctx.accounts.deleteAccount`). A row that references `dw_account` without a
  cascade must go here. The framework removes its own part — files, keys, identities — after the
  hook. Decide per kind of row, by one question: **is this about that person alone, or does someone
  else hold on to it?**
  - *Theirs alone* — their drafts, their settings, their files, the spots they booked: delete it (a
    held spot is released, so the next member can take it).
  - *Somebody else's too* — a message in a shared chat, a post, a review, an order being fulfilled:
    keep the row and empty the **profile** instead. The profile column referencing the account is
    nullable with `ON DELETE SET NULL`, the hook stamps `deletedAt` and clears every personal field
    (name, phone, photo, a test code), the data objects carry `isDeleted`, and the screens say
    "member who left". That is a **tombstone**: what others wrote keeps an author, and the author
    carries nothing of the person. Worked out in full in `example/` — hook, migration, flag,
    acceptance test.

  **The server checks this at startup and refuses to start when nobody has.** It follows every
  `ON DELETE CASCADE` from `dw_account` — transitively — and a project table among them with no
  `onAccountDeleting` stops the server with the table names. That is not pedantry: a project whose
  `user_profile` cascaded off the account and whose `survey_answer` cascaded off the profile lost
  both on the first deletion after its pin moved, and found out from a review.

  Never the third route: a `hidden` flag with the name and the phone still in the row. It is the
  cheapest to write and it is not a deletion — neither the member nor the law was offered it. And
  whichever route the project takes, **the app says which one before it asks to confirm**;
- **`onExternalAccountCreated(ctx, accountId, provider, subject, registration)` creates the profile
  for a sign-in with Google or Apple** — the same job `onAccountCreated` does for a code, and
  **required** to sign in externally at all. The verified claims are in `registration` under
  `DwProviderClaim` keys (`dw.email`, `dw.name`, …), which the app cannot write. Apple tells the
  name only at the very first authorization, so an app that wants it sends it with that sign-in;
- `onIdentifierChanged(ctx, change)` runs in the transaction of every identifier change the framework
  makes to an existing account (a confirmed attach or replace, `moveIdentities`, `removeIdentities`)
  — the place to mirror an identifier into a project row, or to republish the profile that shows it.
  The framework publishes nothing about identifiers itself.

**Sign in with Google and Apple** is `dartway_auth_providers_server`, a module — the project never
verifies a token itself. Its DTOs are a separate package (`dartway_auth_providers_shared`) and go
into the protocol both sides build:

```dart
protocol: DwWireProtocol(dwAuthProvidersProtocolEntries, include: appProtocol),
modules: [
  DwSignInProvidersModule([
    DwGoogleSignIn(clientIds: [android, ios, web]),   // a list: each platform has its own
    DwAppleSignIn(clientIds: [bundleId]),
  ]),
],
```

The providers are independent (declare what you offer; the rest is a door this server does not
have). For Apple, add `signingKey: DwAppleSigningKey(...)` from the `.p8` in the secret store: the
app sends `authorizationCode` with the sign-in, the server exchanges it for a refresh token, and
deleting the account hands that token back to Apple through a job — required by App Store 5.1.1(v),
and never in the way of a person leaving. The app's half is a package per provider —
`dartway_auth_google` (`dw.signInWithGoogle()`), `dartway_auth_apple` (`dw.signInWithApple()`) —
which make the nonce, carry Apple's code, and hand what the provider said to an `introduce`
callback so the project names its own registration fields. `dw.providerCredentialRejected` means the token did not hold up, `dw.providerUnreachable`
that the provider could not be asked for its keys — the app may retry the second, not the first.
Details in `docs/4-server/auth-identity.md`.

For everything else about accounts use **`DwAccountService`**, never SQL on `dw_account`,
`dw_identity` or `dw_auth_key`:

| Where the code runs | Service |
|---|---|
| a handler, job or route | `ctx.accounts` — joins the call's transaction |
| a startup step (`DwAppServer(startup: …)`) | `ctx.accounts` — joins the step's transaction |
| next to a started server | `server.accounts` |
| a script with no server at all | `DwAccountService(db, auth)` |

It offers `ensure`, `find`, `listIdentities`, `listIdentitiesOf` (batch), `accountsMatching` (an admin
search box), `moveIdentities`, `removeIdentities`, `issueKey`, `listKeys`, `revokeKey`, `revokeKeys`
— keys and revocation in `dartway-access`.

## 9a. Startup steps — what must be true before the first call

`DwAppServer(startup: [...])` runs after the migrations and before the port opens, in a background
context and one transaction (`ctx.db`, `ctx.accounts`, `ctx.publish`, `ctx.jobs`). A step that
throws stops the start — in a deployment, with the previous server still serving.

```dart
startup: [DwFirstAdministrator(grant: AppBootstrap.grantAdmin)],
```

`DwFirstAdministrator` brings the account named by `DW_ADMIN_IDENTIFIER` into existence and hands
it to `grant`, which is where the project gives its own admin role — the framework knows accounts,
not roles.

**Where data goes, and it is decided by who owns the row afterwards:**

| Lifecycle | Where |
|---|---|
| once per database, in every environment | a migration (write it in SQL, never through row classes) |
| at every start, in every environment, idempotent | a startup step |
| whenever a developer wants it, never in production | `bin/seed_dev.dart` |

Rows the operators own once they exist (the first settings) are a migration. Rows that must keep
agreeing with the code (notification templates, a lookup a `switch` reads) are a **startup step**:
an applied migration cannot be edited, and a `down` for data deletes what somebody has since
corrected.

**A setting whose value belongs to this deployment has no default.** `DW_ADMIN_IDENTIFIER` above,
a sender address, a provider key, a webhook URL, a bucket name — each is a credential of this
environment, not a preference with a sensible starting point. A default turns an unfilled key into
quiet work with somebody else's identity: mail sent from an address the project does not own, a
webhook posted to a stranger's endpoint. Read it and fail loud, at the point of use or on boot —
`Platform.environment['APP_SENDER_ADDRESS'] ?? (throw StateError('APP_SENDER_ADDRESS is not
set'))` — never a plausible-looking fallback. A value the server cannot start without also belongs
under `requires.secrets` in `deploy/config.yaml`, so a deployment missing it refuses to begin
rather than failing on first use. This does not cover a preference with a genuine neutral value —
a page size, a timeout — only a value that would point the system at somebody else if guessed wrong.

## 10. Checks

```bash
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway generate --check)  # generated code matches the sources
(cd __SERVER_PKG__ && dart run bin/migrate.dart check)       # against the local database: migrations replay into the declared schema
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway test)    # server tests against a throwaway Postgres (and storage)
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway check)   # layout, generated code, migrations drift (with DW_DATABASE_*), and the Flutter checks
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
- [ ] Row class changed → `dart run dartway_cli:dartway generate`, migration drafted and reviewed.
- [ ] `dart run dartway_cli:dartway test` and `dart run dartway_cli:dartway check` pass.
