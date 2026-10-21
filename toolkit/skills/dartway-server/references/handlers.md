## 4. Handlers — one per call

A feature's handler list goes into its `DwServerFeature(handlers: [...])`. The server does not start
when a registered call has no handler or two, or a rule is typed for another call class.

| Call | Factory | Answers |
|---|---|---|
| `DwSingleRequest<T>` | `DwCallHandler.single<Q, T>(access:, handle:)` | `T?`; `null` → `dw.notFound` |
| `DwMaybeRequest<T>` | `.maybe<Q, T>` | `T?` |
| `DwListRequest<T>` | `.list<Q, T>` | `List<T>`, read through `request.readWhole` |
| `DwPageRequest<T>` | `.page<Q, T>(handle: (ctx, request, page))` | up to `page.fetchLimit` after `page.offset` |
| `DwTableRequest<T>` | `.table<Q, T>(rows: (ctx, request, table), count: (ctx, request))` | rows up to `table.fetchLimit`; count of all |
| `DwWindowRequest<T, S, I>` | `.window<Q, T, S, I>(handle: (ctx, request, window))` | one direction per call: `older` — below `window.position` (at it with `includesPosition`), newest first; `newer` — above it, oldest first; compared as `(sortValue, id)` |
| `DwActionCommand<R>` | `.command<C, R>(access:, handle:, transactional:)` | `R` |

A page's `fetchLimit` is one row past the page; reading more fails the call. Every whole-list
handler uses the server helper:

```dart
final rows = await request.readWhole((limit) => ctx.db.teamMembers.find(
  where: (t) => t.teamId.equals(request.teamId),
  orderBy: (t) => [t.id.asc()],
  limit: limit,
));
```

Apply the nullable `limit` to the same query; null means no limit. The callback only reads and may
run twice. `readWhole` probes with `request.fetchLimit`, one past `maxItems` (default 200).
Overflow throws with the request name and observed count in tests (`DwTestServer`) and strict
development (`DW_STRICT_BOUNDS: true` in `deploy/config.yaml > local`). Production re-reads once
without a limit, serves everything and warns with the true count and size, once an hour. Never
return only a `fetchLimit` probe: that silently truncates production lists. A warning or failed
test means a growing list needs a page, table or window (`dartway-contract`); raise `maxItems` only
with a domain reason in the request's doc comment. Any response above 256 KB
(`DwServerSettings.largeResponseBytes`) is logged the same way.
Before your function runs the
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
- **Every top-level `ctx.transaction` body may run up to three times** — in a command, a route, a
  job or a startup step, the framework retries it on a deadlock or a serialization failure. Outbound
  calls stay outside it; no hand-rolled retry loop around it.
- A request handler is a read and writes nothing (`dartway-realtime` for what throws there).

## 5. Rows → data objects, in batch

One `_objects.dart` function per data object takes a list of rows, loads each relation once
(`findByIds`, `ctx.accounts.listIdentitiesOf`, `ctx.files.publicUrls`) and maps; a single object is a
batch of one. Every handler and publication goes through it, so every exit shows the object the same
way. Sample: the skeleton's `lib/src/profile/profile_objects.dart`.

## 6. The call context

`accountId`/`requireAccountId`, `sessionKey`, `db`, `now`, `callerUtcOffset`/`callerLocalTime`,
`transaction`, `publish`, `revoke`, `refuse`, `jobs`, `accounts`, `files`, `settings`, `http`, `process`, `log`,
`memo`.

- **Time is `ctx.now`** — the server's clock, which tests set and jobs run by. In a command, the
  caller's day is `ctx.callerLocalTime` (the app sends its offset with every call, so a command never
  carries an offset field): `year`…`weekday`, and `startOfDayUtc` for a query over "their today". A
  request takes the day as a field instead (`dartway-contract`, `references/models.md`); in a job there is no caller, and
  work at a person's local hour uses an offset the project stored from their calls.
- **Who the caller is** is the project's: `ProfileCallContext` in `profile/profile_access.dart` gives
  `ctx.profile` (cached with `memo`) and the role; extend it rather than reading the profile again.
- **`ctx.refuse(code, field:, params:)`** returns `Never` and is the answer to a caller's mistake.
  Anything thrown is a failure: an incident id to the caller, an alert to the operator. Never catch to
  keep going.
- `ctx.log` is for the operator: never codes, tokens or personal data.
