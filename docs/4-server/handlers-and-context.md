# Handlers: what runs for a call, and what may it touch?

A handler answers one request or command class of the protocol. It is a function, built by one of
seven factories on `DwCallHandler` — one per request kind and one for commands — and registered in
`DwAppServer(handlers: …)`. The server refuses to start when a registered class has no handler or
two, so a missing handler is a deploy error rather than the first user's.

The factories bound the call class by kind: `single` takes a `DwSingleRequest`, `command` a
`DwActionCommand`. A handler of the wrong kind does not compile.

## What happens before the handler

`POST /dw/<WireName>` is checked cheapest first, and nothing touches the database until the call
is known to be well-formed:

1. **Compatibility** — `Dw-Protocol` and `Dw-App-Version` (`426` when the client cannot talk to
   this server);
2. **Shape** — method, wire name (`404` for an unknown one), content type, idempotency key
   (required for a command, forbidden for a request), headers, query and body — each a malformed
   call (`400`) when wrong, logged with an incident id and never alerted;
3. **The token** — unknown or revoked is `401` on any call, even one that needs no account: a
   client holding a dead token must learn it;
4. **Sign-in** required by the access rule (`401`), then **validation**, then the **access check**
   (`403`);
5. **The handler.**

Sign-in comes before validation, so an anonymous caller is told to sign in rather than which field
is wrong. Validation comes before the access check because it is pure and a check may query — a
check written against the call's fields should not run on invalid ones.

**Validation** is the call's own: a class implementing `DwSelfValidating` has its `validate()` run
on the server before the handler (the first refusal it returns is the answer), and a table request's
page and page size are checked. The client ran the same code before sending; running it again is
what makes it a rule instead of a courtesy of well-behaved clients. See
[refusals and statuses](../2-core/refusals-and-statuses.md).

**Access** is required on every factory, with no default, so a handler cannot be open by omission:
`DwAccessRule.anonymous`, `DwAccessRule.signedIn` or `DwAccessRule.check<C>((ctx, call) async => …)`.
See [access and roles](../2-core/access-and-roles.md).

## The seven factories

Every factory takes `access` and an optional `maxBodyBytes`, which overrides
`DwServerSettings.maxBodyBytes` for this call's body (a positive number; a larger limit for a call
that carries a lot, a smaller one for a command that has no business receiving much).

### `single` — absent is a refusal

```dart
DwCallHandler.single<Q extends DwSingleRequest<T>, T extends DwDataObject>({
  required DwAccessRule access,
  int? maxBodyBytes,
  required Future<T?> Function(DwCallContext ctx, Q request) handle,
})
```

Return `null` when the object does not exist, or the caller may not know that it does: the
framework refuses `dw.notFound` (`404`). No handler can forget to.

### `maybe` — absent is an answer

Same signature over `DwMaybeRequest<T>`; `null` is sent to the client as a value.

### `list` — the whole list

```dart
DwCallHandler.list<Q extends DwListRequest<T>, T extends DwDataObject>({
  required DwAccessRule access,
  int? maxBodyBytes,
  required Future<List<T>> Function(DwCallContext ctx, Q request) handle,
})
```

### `page` — an offset feed

```dart
DwCallHandler.page<Q extends DwPageRequest<T>, T extends DwDataObject>({
  required DwAccessRule access,
  int? maxBodyBytes,
  required Future<List<T>> Function(DwCallContext ctx, Q request, DwPageInput page) handle,
})
```

`DwPageInput` carries `offset` (rows already loaded), `pageSize` (the request class's page size,
or the size the call asked for clamped to its `maxPageSize`) and `fetchLimit` (`pageSize + 1`).
Read up to `fetchLimit` rows after `offset`, in a total order. The framework trims the extra row
and sets `hasMore` — which is how it knows another page exists without counting. Reading more than
`fetchLimit` is a handler bug and fails the call loudly instead of being trimmed: it means a
handler reads a table where it should read a page.

### `table` — numbered pages with a total

```dart
DwCallHandler.table<Q extends DwTableRequest<T>, T extends DwDataObject>({
  required DwAccessRule access,
  int? maxBodyBytes,
  required Future<List<T>> Function(DwCallContext ctx, Q request, DwTableInput table) rows,
  required Future<int> Function(DwCallContext ctx, Q request) count,
})
```

`DwTableInput` carries `page` (from 1), `pageSize` (clamped to `maxPageSize`), `offset` and
`fetchLimit`. `rows` reads up to `fetchLimit` rows after `offset`; `count` counts every row the
request matches. The framework calls `count` only when the rows cannot tell the total — a full page
(more may follow) or an empty page past the first. A short page is the last one, and its total is
`offset + rows`. The common small table costs one query, and the total never disagrees with the
rows: a count that comes back lower than the rows already seen is raised to them.

From `example/dartway_example_server/lib/src/handlers/admin_handlers.dart`:

```dart
DwCallHandler.table<ListUserProfiles, UserProfile>(
  access: ExampleAccess.admin,
  rows: (ctx, request, table) async => [
    for (final row in await ctx.db.userProfiles.find(
      where: _membersFilter(request),
      orderBy: (t) => [t.firstName.asc(), t.id.asc()],
      limit: table.fetchLimit,
      offset: table.offset,
    ))
      ClubObjects.profile(row),
  ],
  count: (ctx, request) =>
      ctx.db.userProfiles.count(where: _membersFilter(request)),
),
```

### `window` — an anchored window, newest first

```dart
DwCallHandler.window<Q extends DwWindowRequest<T, S, I>, T extends DwDataObject,
    S extends Object, I extends Object>({
  required DwAccessRule access,
  int? maxBodyBytes,
  required Future<List<T>> Function(DwCallContext ctx, Q request, DwWindowInput<S, I> window) handle,
})
```

The request class names a row's place in the sequence (`positionOf`): a sort value `S` (`int`,
`String` or `DateTime`) and an id `I` (`int` or `String`). Other types throw `ArgumentError` when
the handler is declared, because a cursor of them could not be encoded.

The handler reads **one direction** at a time. `DwWindowInput` carries:

- `direction` — `DwWindowDirection.older` (rows below `position`, newest first) or `newer` (rows
  above it, oldest first);
- `position` — the `(sortValue, id)` pair to start from; `null` only for the newest rows;
- `includesPosition` — whether the row at `position` itself is read (the anchor of a window opened
  around it);
- `fetchLimit`.

The framework composes the rest: around an anchor it reads newer rows for half the page, then the
anchor and older rows, and a third read only when older rows run short. It sets the cursors. A
cursor from the client that does not decode to `S` and `I` is a malformed call. The example's chat
(`ListChatMessages` in `example/dartway_example_server/lib/src/handlers/chat_handlers.dart`)
compares `(sentAt, id)` as a pair in both directions. See
[requests and updates](../2-core/requests-and-updates.md) and
[the window list view](../3-flutter/window-list-view.md).

### `command` — a change

```dart
DwCallHandler.command<C extends DwActionCommand<R>, R>({
  required DwAccessRule access,
  bool transactional = true,
  int? maxBodyBytes,
  required Future<R> Function(DwCallContext ctx, C command) handle,
})
```

**`transactional: true`** (the default) runs the idempotency lookup, the access check, the handler
and the outcome record in one database transaction. `ctx.db` is that transaction. A serialization
failure or a deadlock retries the whole transaction, up to three attempts, with the per-call memo
and the pending publications cleared. So a transactional handler must do nothing a retry would
repeat outside the database.

**`transactional: false`** is for handlers that call external services — a payment provider, a
storage request — which must not run inside a transaction that may be retried or held open for
seconds. `ctx.db` is then the pool; open `ctx.transaction` around the writes.

The outcome — the result, or a refusal — is stored under the idempotency key and replayed to a
retry of the same key; a failure is not stored, so it can be retried. See
[commands and idempotency](../2-core/commands-and-idempotency.md).

## `DwCallContext`

One context per call. Everything a handler may touch is on it.

| Member | What it is |
|---|---|
| `accountId` | the caller's account, or `null` |
| `requireAccountId` | the account; throws `DwNotAuthenticatedException`, answered `401` |
| `sessionKey` | the `DwSessionKeyInfo` that authenticated the call — the server's record, never the client's word ([keys](auth-identity.md#session-keys)) |
| `db` | the `DwDatabaseHandle`: the transaction inside a transactional command or `ctx.transaction`, the pool otherwise |
| `protocol` | the `DwWireProtocol` (for `DwDeletedObject.of<T>(id, ctx.protocol)`) |
| `transaction(body)` | runs `body` in a transaction, a savepoint when already inside one; publications, revocations and jobs made inside take effect only if it commits |
| `publish(channel, item)` | sends a data object or a `DwDeletedObject` to a channel after commit ([channels](../2-core/channels-and-realtime.md)) |
| `revoke(channel, accountId)` | closes an account's subscriptions to a channel after commit |
| `refuse(code, {params, field})` | throws the refusal; returns `Never` |
| `jobs` | the `DwJobQueue`; an enqueue joins the current transaction ([jobs](jobs.md)) |
| `accounts` | a `DwAccountService` bound to this call ([auth](auth-identity.md#dwaccountservice)) |
| `files` | the `DwFileService` ([uploads](uploads.md#ctxfiles)) |
| `log` | a `DwServerLogger` scoped to the call (`command BookSession`) |
| `memo(key, create)` | a per-call cache: `create` runs at most once per key per call |

### A request cannot publish

A request is a read. The client retries it and caches its answer, so a side effect in one would
happen again for every retry and never reach anyone reliably. `publish`, `revoke` and
`files.delete` throw `StateError` in a request. Publish from the command that made the change.

### `ctx.transaction`, not `ctx.db.transaction`

Both open a transaction, but only `ctx.transaction` ties the call's effects to it and makes `ctx.db`
the transaction inside the body. Inside `ctx.db.transaction((tx) …)`, `ctx.db` is still the outer
handle — a write through it escapes the transaction — and a publication made there is delivered
even when that transaction rolls back.

## A project's own notions of the caller

The framework knows an account. What the account is to the project — a profile, a role — is the
project's, added by extension and cached per call with `memo`. From the skeleton
(`template/dartway_starter_server/lib/src/call_context.dart`):

```dart
extension AppCallContext on DwCallContext {
  /// The caller's profile, read once per call.
  Future<UserProfileRow> get profile => memo(#profile, () async {
    final accountId = requireAccountId;
    final profile = await db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    // Created in the same transaction as the account: absence is a broken
    // invariant, not a state a caller can be in.
    return profile ?? (throw StateError('Account $accountId has no profile'));
  });

  Future<bool> get isAdmin async => (await profile).role == UserRole.admin;
}

/// Access rules of the app, in the words handlers read.
abstract final class AppAccess {
  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );
}
```

The access check and the handler then share one profile read. The memo is cleared when a
transactional command is retried, so a retry never sees a value read in the rolled-back attempt.

## Rows become data objects, in batch

A row never leaves the server; handlers map rows to the data objects clients see, explicitly. Do it
for a list at a time, with one query per relation — never one per row. The ORM has no joins by
design (D-011); `findByIds` is the join.

`example/dartway_example_server/lib/src/club_objects.dart` maps sessions with their services and
coaches:

```dart
static Future<List<ClubSession>> sessions(
  DwDatabaseHandle db,
  List<ClubSessionRow> rows,
) async {
  if (rows.isEmpty) return const [];
  final services = {
    for (final row in await db.clubServices.findByIds(
      rows.map((s) => s.serviceId).toSet(),
    ))
      row.id!: service(row),
  };
  final coaches = await _profiles(db, rows.map((s) => s.coachProfileId));
  return [
    for (final row in rows)
      ClubSession(
        id: row.id!,
        service: services[row.serviceId]!,
        coach: switch (coaches[row.coachProfileId]) {
          final coach? => person(coach),
          null => null,
        },
        startsAt: row.startsAt,
        capacity: row.capacity,
        bookedCount: row.bookedCount,
      ),
  ];
}
```

Its `bookings` also takes the related objects the caller already holds (`client:`, `session:`), so
a command that has just loaded the session does not load it again. The skeleton's
`template/dartway_starter_server/lib/src/objects.dart` does the same with framework data: the
identifiers of every profile in one `ctx.accounts.listIdentitiesOf` call, and avatar URLs in one
`ctx.files.publicUrls` call.

Mapping one row is the list of one: `(await ClubObjects.sessions(ctx.db, [row])).single`. Then a
handler that answers one object and a handler that answers a hundred build it the same way.

**Publishing is mapping too.** A changed row often goes to several channels, as several objects;
the skeleton keeps that in one function per change
(`template/dartway_starter_server/lib/src/publications.dart`, `publishProfile`), so every command
that changes a profile publishes the same set.

## Related

- [Database](database.md) — the queries handlers make.
- [Data objects and generation](../2-core/data-objects-and-generation.md) — the classes handlers answer.
- [Alerts](alerts.md) — what happens when a handler throws.
