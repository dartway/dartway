---
name: dartway-server
description: >-
  The server package (__SERVER_PKG__): the feature folder and its closed file set, row classes and
  the generated repositories, queries without joins (findByIds per relation, tryInsert, upsert,
  aggregates), one DwCallHandler per call, transactions and row locks, rows mapped to data objects
  in batch, the call context (ctx.now, ctx.refuse, memo), jobs, DwHttpRoute doors, sign-in hooks and
  account deletion, DwAccountService, startup steps and DwSeedRows, typed settings, the environment
  and ctx.http. Use when writing or changing a handler, a row class, a query, a job, a route, a seed,
  a setting or sign-in hooks.
---

# DartWay — the server (`__SERVER_PKG__`)

A `DwAppServer`: the contract's calls, each answered by one handler that says who may make it and what
it does; no endpoints, no generic CRUD. Access rules — `dartway-access`; what to publish — 
`dartway-realtime`; schema changes — `dartway-migrations`; files — `dartway-uploads`.

## 1. Layout

```
bin/server.dart · bin/migrate.dart · bin/seed_dev.dart
lib/__SERVER_PKG__.dart     builds the DwAppServer: lists the features, the sign-in hooks, the upload rules
lib/generated/              written by generate
lib/src/core/               channels.dart (AppChannels) · environment.dart (AppEnvironment) · files.dart (AppFiles) · push.dart
lib/src/migrations/
lib/src/profile/            who the caller is (profile_access.dart), how others write a profile (profile_changes.dart)
lib/src/account/            the sign-in hooks and the first administrator; imported by nothing
lib/src/<feature>/          <feature>_feature.dart (its DwServerFeature) · _rows · _handlers · _objects
                            · _publications · _jobs · _access · _routes · _changes · logic/
```

The checks hold the shape (the law table in `CLAUDE.md`); the parts they cannot see:

- **A kind that outgrows its file splits by subject**, `<feature>_<part>_<kind>.dart`
  (`chat_messages_handlers.dart`); `logic/` is flat, free names, for what is none of the kinds.
- **Another feature's surface** is its `_rows` (read and join, never write), `_access` (its rules),
  `_objects` (its rows shown its way), `_publications`, `_changes` (its rows written its way — the
  only way another feature writes them). A number several features move (an admin counter) is one
  function in the owner's `_publications`, called by every command that moves it.
- **The profile imports no other feature** — every feature asks who the caller is. A cycle is broken by
  moving the shared rule to the `_access`, or the row class, to the feature that owns the concept — or
  what both need into a third feature both import.
- `core/` holds only what every feature needs and no feature's rule: an upload rule or a push audience
  lives in its feature's `_access.dart`, handed in by the library.

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
  Never over `dw_*` tables (§8).

## 4. Handlers — one per call

A feature's handler list goes into its `DwServerFeature(handlers: [...])`. The server does not start
when a registered call has no handler or two, or a rule is typed for another call class.

| Call | Factory | Answers |
|---|---|---|
| `DwSingleRequest<T>` | `DwCallHandler.single<Q, T>(access:, handle:)` | `T?`; `null` → `dw.notFound` |
| `DwMaybeRequest<T>` | `.maybe<Q, T>` | `T?` |
| `DwListRequest<T>` | `.list<Q, T>` | `List<T>` |
| `DwPageRequest<T>` | `.page<Q, T>(handle: (ctx, request, page))` | up to `page.fetchLimit` after `page.offset` |
| `DwTableRequest<T>` | `.table<Q, T>(rows: (ctx, request, table), count: (ctx, request))` | rows up to `table.fetchLimit`; count of all |
| `DwWindowRequest<T, S, I>` | `.window<Q, T, S, I>(handle: (ctx, request, window))` | one direction per call: `older` — below `window.position` (at it with `includesPosition`), newest first; `newer` — above it, oldest first; compared as `(sortValue, id)` |
| `DwActionCommand<R>` | `.command<C, R>(access:, handle:, transactional:)` | `R` |

`fetchLimit` is one row past the page; reading more fails the call. Before your function runs the
framework decoded the body, checked sign-in, ran `validate()` and the access rule — do not repeat them.
Every handler carries its `///` description (`dartway-documentation`).

The skeleton's `__SERVER_PKG__/lib/src/profile/profile_handlers.dart` and
`lib/src/admin/admin_handlers.dart` are the pattern: a list of handlers, rules from `_access`,
mapping through `_objects`, publishing through `_publications`.

### Commands and transactions

- A command is transactional by default: its access check, the handler and the idempotency record
  commit together, and **a refusal rolls back**.
- **Lock what a decision reads**: `findById(id, lock: DwRowLock.forUpdate)` (also `find`,
  `findFirst`) on the row every competing command goes through. A lock outside a transaction throws.
- **The transaction may be retried** from the start; nothing inside may reach outside the database.
  A handler that calls a service is `transactional: false` — its comment says why — with
  `ctx.transaction((tx) async {…})` around its writes, or enqueues a job, which joins the transaction.
- A request handler is a read and writes nothing (`dartway-realtime` for what throws there).

## 5. Rows → data objects, in batch

One `_objects.dart` function per data object takes a list of rows, loads each relation once
(`findByIds`, `ctx.accounts.listIdentitiesOf`, `ctx.files.publicUrls`) and maps; a single object is a
batch of one. Every handler and publication goes through it, so every exit shows the object the same
way. Sample: the skeleton's `lib/src/profile/profile_objects.dart`.

## 6. The call context

`accountId`/`requireAccountId`, `sessionKey`, `db`, `now`, `callerUtcOffset`/`callerLocalTime`,
`transaction`, `publish`, `revoke`, `refuse`, `jobs`, `accounts`, `files`, `settings`, `http`, `log`,
`memo`.

- **Time is `ctx.now`** — the server's clock, which tests set and jobs run by. In a command, the
  caller's day is `ctx.callerLocalTime` (the app sends its offset with every call, so a command never
  carries an offset field): `year`…`weekday`, and `startOfDayUtc` for a query over "their today". A
  request takes the day as a field instead (`dartway-contract` §2); in a job there is no caller, and
  work at a person's local hour uses an offset the project stored from their calls.
- **Who the caller is** is the project's: `ProfileCallContext` in `profile/profile_access.dart` gives
  `ctx.profile` (cached with `memo`) and the role; extend it rather than reading the profile again.
- **`ctx.refuse(code, field:, params:)`** returns `Never` and is the answer to a caller's mistake.
  Anything thrown is a failure: an incident id to the caller, an alert to the operator. Never catch to
  keep going.
- `ctx.log` is for the operator: never codes, tokens or personal data.

## 7. Jobs, routes

**A job belongs to a feature**: kinds and definitions in `<feature>_jobs.dart`, declared by
`DwServerFeature(jobs: invoicesJobs)`. Names: the kinds class `InvoicesJobs`, the list `invoicesJobs`,
a job `'invoices.mark_overdue'` (`dw.` names are the framework's).

```dart
abstract final class InvoicesJobs {
  static const remind = DwJobKind<({int invoiceId})>(
    'invoices.remind',
    encode: _encode,
    decode: _decode,
  );
  static Map<String, Object?> _encode(({int invoiceId}) p) => {'invoiceId': p.invoiceId};
  static ({int invoiceId}) _decode(Map<String, Object?> json) => (invoiceId: json['invoiceId']! as int);
}

final invoicesJobs = <DwJobDefinition>[
  DwQueuedJob(InvoicesJobs.remind, handle: (ctx, p) async {
    final invoice = await ctx.db.invoices.findById(p.invoiceId); // decided when it runs
    if (invoice == null || invoice.status == InvoiceStatus.paid) return;
    // …
  }),
  DwRecurringJob('invoices.mark_overdue', every: const Duration(hours: 1), handle: (ctx) async {/* … */}),
];
```

The payload is spelled as a map once, in the kind's codec — never `payload['x']! as int` in a handler.
A command enqueues by the kind — `ctx.jobs.enqueue(InvoicesJobs.remind, (invoiceId: id), runAt: …,
key: …)` — which joins its transaction (`key` deduplicates pending jobs). A queued job is transactional by default; with
`transactional: false` (it calls a service) it may run twice after a crash. A job has no caller, reads
its state when it runs, may publish, and is due by the server's clock. Worked example, in the framework repository's example (on GitHub, not in this project):
[`bookings_jobs.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/bookings/bookings_jobs.dart).

**A `DwHttpRoute` is for callers that cannot speak the contract** — a webhook, a download link. In
`<feature>_routes.dart`, registered in `DwServerFeature(routes: [...])`, exact paths (`/dw/…` and
`/health` are the framework's). `auth:` defaults to `DwRouteAuth.none` — the route verifies its sender
itself (a signature); `optional`/`required` read an `Authorization: Bearer` key like a call. A door acting for a signed-in
person runs the call in process — `server.callAs(call, token:, idempotencyKey:)` — never over its own
port. A route that rejects silently names the step that turned the request away with an enum value
(`foreignOrigin`, `versionMismatch`, `unknownType`), never a boolean, and carries no payload or secret.

## 8. Sign-in hooks and accounts

The framework owns accounts, identifiers and keys; `DwAuthConfig` (the skeleton's
`lib/src/account/logic/auth.dart`) is the project's part:

- `normalize` — the identifier's one form, the shared function the app applies too;
- `generateCode` (`null` = random digits) and `deliverCode` — always called, after the ticket commits,
  on a fresh pooled `ctx.db`, not the ticket's transaction: a throw or a refusal there does not undo the
  ticket. Deciding not to send (a fixed test code) is its own choice;
- **`onAccountCreated` creates the profile row in the account's transaction**; refusing there refuses
  the sign-in. `origin` is `DwSignInOrigin` (check consents there) or `DwToolOrigin` (`ensure`);
- **`accountDeletion`** is required: `byMember` answers `DwDeleteMyAccount` (app stores require it),
  `byOperator` leaves it to `ctx.accounts.deleteAccount` — switch member deletion off that way, never by
  refusing in `onAccountDeleting`, which would refuse the operator too;
- **`onAccountDeleting` deletes or anonymises the project's rows** — every row referencing `dw_account`
  without a cascade — per kind, by one question: is this about that person alone (delete it), or does
  someone else hold on to it (keep the row, blank the profile — a tombstone: its account column nullable
  with `DwOnDelete.setNull`, every personal field cleared, `deletedAt` stamped, `isDeleted` on the data
  objects)? Never a `hidden` flag with the personal data still in it; the app says which route before
  asking to confirm. The server refuses to start while a project table cascades from `dw_account` with
  no hook. Worked example, in the framework repository's example (on GitHub, not in this project):
  [`account/logic/auth.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/account/logic/auth.dart);
- `onExternalAccountCreated` — the profile for a Google/Apple sign-in, required to allow one; the
  verified claims are in `registration` under `DwProviderClaim` keys, which the app cannot write;
- `linkByVerifiedEmail` — off by default, and off is the safer default; `onIdentifierChanged` — mirror
  or republish an identifier, in the changing transaction.

Google and Apple sign-in is `DwSignInProvidersModule([DwGoogleSignIn(clientIds: [android, ios, web]),
DwAppleSignIn(clientIds: [bundleId], signingKey: …)])` in `modules:` — one client id per platform — with
`dwAuthProvidersProtocolEntries` in both protocols; the project never verifies a token itself. Apple's
`signingKey` (the `.p8`, from the secret store) lets a deletion revoke the Apple token (App Store
5.1.1(v)); Apple tells the name only at the first authorization, so the app sends it then. The app half
is `dartway_auth_google` / `dartway_auth_apple`; `dw.providerUnreachable` may be retried,
`dw.providerCredentialRejected` may not. Details:
[`auth-identity.md`](https://github.com/dartway/dartway/blob/master/docs/4-server/auth-identity.md).

**Everything else about accounts is `DwAccountService`** — `ctx.accounts` in a handler, job, route or
startup step (joins its transaction), `server.accounts` beside a started server,
`DwAccountService(db, auth)` in a script — never SQL on `dw_*` tables: `ensure`, `find`,
`listIdentities(Of)`, `accountsMatching`, `moveIdentities`, `removeIdentities`, keys (`dartway-access`).

## 9. Startup, seeds, settings

`DwAppServer(startup: [...])` and `DwServerFeature(startup: [...])` run after the migrations, before the
port opens — the server's steps first, then each feature's — one transaction per step; a throw stops
the start. `bin/server.dart` does nothing after
`server.start()` but log.

| What | Where |
|---|---|
| rows carried across a schema change | `m.backfill` in that migration (`dartway-migrations`) |
| rows the code declares — a catalogue, a questionnaire | `DwSeedRows` on the feature they belong to |
| one value per app with a default for every field | a settings object |
| anything else true before the first call | a `DwStartupStep`; the first admin is `DwFirstAdministrator` (the skeleton's `account_feature.dart`) |
| development data | `bin/seed_dev.dart`, never in production |

`DwSeedRows('exercise catalogue', table: ExerciseRow.tableDef, key: (t) => [t.slug], rows: …)` inserts a
missing row, overwrites a changed one by its key, and leaves undeclared rows alone — so a seed owns its
rows (rows operators edit are made in the admin panel, with defaults in code), the key is a unique
`NOT NULL` natural key, the rows are constants, a row is retired by a column (`isPublished: false`), and
a seed pointing at another's comes after it. A long catalogue lives in a
`<feature>_<part>_rows.dart` of `const` drafts only, which the length check passes over.

**Settings** are a data object of the contract (`dartway-contract`) read and written through
`ctx.settings` — `read<T>()` (the defaults until saved), `update<T>((current) => …)` (locked between
read and write), `save(value)`; no table of the project's. Sample: the skeleton's
`lib/src/settings/settings_handlers.dart`. Only what differs from the defaults is stored: a default
changed in code changes every stored value equal to the old one, and renaming the class resets it. A preference per member stays a column of the member's row.

**A value that belongs to this deployment has no default** — a sender address, a provider key, a
webhook URL: a guessed one points the system at somebody else. Read it with `read.required(…)` so an
unset one stops the start, and list it under `requires.secrets` in `deploy/config.yaml`. (The admin
identifier is optional — unset, the server starts and warns; bucket names have defaults derived from
the project.)

## 10. The environment and other services

`lib/src/core/environment.dart` reads every variable once, at start: `AppEnvironment` holds
`DwServerEnvironment` and one typed sub-config per concern, read by `DwEnvironmentReader` —
`read.required`, `optional`, `integer`, `flag`, `list`, `report` — which throws every problem at once
and never repeats a text value (a number or flag read with `secret: true` neither).
Its doc comment in the skeleton is the sample. `bin/server.dart` reads
`AppEnvironment.read(DwLocalEnvironment.overlay(Platform.environment))` and hands the sub-configs to
the server factory; `bin/` parses nothing itself — no `env['NAME']`.

**Another service's HTTP API is `ctx.http`**: `get`/`post`/`put`/`patch`/`delete`/`send`, `json:` or
`body:`; any status is a `DwOutboundResponse`, no answer throws `DwOutboundException`; bounded by
`DwServerSettings.outboundTimeout` and `outboundMaxResponseBytes`; logged without path, query, headers
or body; `followRedirects: false` when a header carries a credential. Not inside a transaction (§4).
A service class takes `ctx.http` per call — tests fake it (`dartway-testing`), nothing is threaded
through the server factory for them.

Sign-in delivery preferences: pass a project-defined `deliveryHint` on `DwRequestCode` only when
requesting an explicit delivery choice. Allow accepted strings in `DwAuthConfig.allowedDeliveryHints`
and read `ctx.deliveryHint` inside `generateCode` or `deliverCode`; null means the project default.
Unknown hints refuse `dw.invalid` on `deliveryHint`. Every accepted choice requests a new ticket and
shares the same identifier cooldown, request window and idempotency rules. Never implement a separate
anonymous dispatcher or write framework ticket tables to route delivery.
