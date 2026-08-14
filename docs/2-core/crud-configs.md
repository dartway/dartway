# Why configure CRUD instead of writing endpoints?

A conventional backend answers that question once per model, by hand: an endpoint per operation,
each one re-deciding who may call it, what counts as valid, and what to send back. The rules end up
scattered across handlers, and the only way to learn how a model behaves is to read every method
that touches it.

DartWay inverts this. The transport is written once, in the framework: `DwCrudEndpoint` serves
`getOne`, `getAll`, `getCount`, `saveModel`, `delete` and a realtime subscription — for **every**
model, with no per-model code. What you write instead is a declaration of the model's rules:
a `DwCrudConfig<T>`.

One file per model, and that file *is* the model's server behaviour. Reviewing permissions means
reading nine small files, not grepping an endpoint layer; and the client needs no new API surface —
`dw.repo.modelList<Note>()` works the moment the config exists.

## `DwCrudConfig<T>` — four slots

```dart
class DwCrudConfig<T extends TableRow> {
  const DwCrudConfig({
    required this.table,          // ClubService.t — the generated table descriptor
    this.getModelConfigs,         // List<DwGetModelConfig<T>>? — reading one row
    this.getListConfig,           // DwGetModelListConfig<T>?  — reading many
    this.saveConfig,              // DwSaveConfig<T>?          — insert + update
    this.deleteConfig,            // DwDeleteConfig<T>?        — delete
  });
}
```

Everything is optional except the table. A model that is only ever read gets a read config and
nothing else; a model that is never deleted gets no `deleteConfig`. Absence is the deny.

A complete config from `example/` — the club price list, readable by any signed-in visitor, writable
by the admin:

```dart
final clubServiceCrudConfig = DwCrudConfig<ClubService>(
  table: ClubService.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
  ),
  saveConfig: DwSaveConfig<ClubService>(
    allowSave: (session, saveContext) async => session.isClubAdmin,
    validateSave: (session, saveContext) async {
      final service = saveContext.currentModel;
      if (service.title.trim().isEmpty) return 'Title is required';
      if (service.durationMinutes <= 0) return 'Duration must be positive';
      if (service.price < 0) return 'Price cannot be negative';
      return null;
    },
  ),
  deleteConfig: DwDeleteConfig<ClubService>(
    allowDelete: (session, model) => session.isClubAdmin,
  ),
);
```

`session.isClubAdmin` is not framework API — it is an extension the app writes over its own
`UserProfile.role`. See [access-and-roles.md](access-and-roles.md).

## Registration, and what happens without it

A config exists for the server only once it is in `DwCore.init`:

```dart
dw = DwCore.init<UserProfile>(
  userProfileTable: UserProfile.t,
  crudConfigurations: [
    userProfileCrudConfig,
    clubServiceCrudConfig,
    // ...
  ],
  // ...
);
```

The core indexes them by class name. Every endpoint method starts with the same lookup, and when it
comes back empty the call is answered with `DwApiResponse.notConfigured` — `isOk: false`, and the
error text `Action not configured on server (getAll for ClubService)`.

That failure is the framework's security model, not an inconvenience: **an unregistered model is not
reachable at all**. Access is something you grant, never something you forget to revoke. The typical
first encounter is a new model whose screen shows the "not configured" message — the config was
written and the registration line was not.

## Saving: one lifecycle for insert and update

`DwSaveConfig<T>` has no separate create and update paths. `saveContext.isInsert` tells the hooks
which one is happening, and `saveContext.initialModel` holds the row as it was (`null` on insert).

The order, exactly as `DwSaveConfig.save` runs it:

| # | Hook | Returns | Where |
|---|---|---|---|
| 1 | `allowSave` | `Future<bool>` — **required** | before the transaction |
| 2 | `validateSave` | `Future<String?>` | before the transaction |
| 3 | `beforeSaveTransaction` | `Future<String?>` | **inside** the transaction |
| 4 | *insert / update* | — | inside the transaction |
| 5 | `afterSaveTransaction` | `Future<String?>` | inside the transaction |
| 6 | `afterSaveTransform` | `Future<void>` | after commit |
| 7 | `afterSaveSideEffects` | `Future<void>` | after commit, not awaited |

All seven share one signature — `(Session session, DwSaveContext<T> saveContext)`. There is no
`(initial, updated)` pair anywhere; both models live in the context, along with `currentUserId`,
`transaction`, `extras` for passing data between steps, and `beforeUpdates` / `afterUpdates` for
extra models the client should refresh.

**Rejecting.** `allowSave` returning anything but `true` produces `DwApiResponse.forbidden()` — the
fixed text `Not enough permissions`. The three `String?` hooks reject by returning the message,
which reaches the user verbatim; returning `null` lets the save proceed. Rejection from inside the
transaction rolls it back, including from `afterSaveTransaction` — a rule discovered after the write
still undoes it.

**Why three rejection points and not one.** Steps 1–2 run *before* the transaction opens, against
the database as it was a moment ago. A rule that guards a shared count — seats left, stock on hand,
"only one active booking" — can be raced there: two concurrent saves both read four of five taken
and both pass. Such a rule belongs in `beforeSaveTransaction`, which runs inside the transaction and
can take a row lock. `validateSave` checks the model; `beforeSaveTransaction` checks the world
around it.

The booking config in `example/` is built on exactly that split — capacity and duplicate checks are
deliberately *not* in `validateSave`:

```dart
beforeSaveTransaction: (session, saveContext) async {
  if (!saveContext.isInsert) return null;
  final booking = saveContext.currentModel;

  final clubSession = await ClubSession.db.findById(
    session,
    booking.clubSessionId,
    transaction: saveContext.transaction,
    lockMode: LockMode.forUpdate,   // SELECT ... FOR UPDATE, in the same call
  );
  if (clubSession == null) return 'Session not found';

  final takenSpots = await SessionBooking.db.count(
    session,
    where: (t) => t.clubSessionId.equals(booking.clubSessionId) &
        t.status.equals(BookingStatus.booked),
    transaction: saveContext.transaction,
  );
  if (takenSpots >= clubSession.capacity) return 'No spots left for this session';

  saveContext.currentModel = booking.copyWith(
    status: BookingStatus.booked,
    createdAt: DateTime.now(),
  );
  return null;
},
```

Without the lock those two counts are decorative: under READ COMMITTED both clients going for the
last spot count the same four and both get in.

**When the rule is about the row itself** — a role, a consent flag, a balance, a cancellation marker
— the race is on the initial model, which steps 1–2 read outside the transaction. Set
`lockInitialModelForUpdate: true`: on **updates** the row is re-read under `FOR UPDATE` inside the
transaction and `allowSave` / `validateSave` are evaluated against what was actually committed. It
is opt-in so the default lifecycle is unchanged, and it does nothing on insert — there is no row to
lock yet.

**A `scope=serverOnly` column is not overwritten by a client save, and there is nothing to switch on
for that.** Such a field does not exist on the client class, so it is never in the JSON a client
sends, and the model the server deserialises carries `null` there — an update writing the whole row
would blank the column, with no error and an `isOk` response. It is left out of the `UPDATE`
instead, and the database keeps its value. (The outbound half is held too: the value is never sent
to a client in the first place — see
[fields the client must never see](models.md#scopes-fields-the-client-must-never-see).)

The rule is narrow on purpose: the column is skipped **only** when the incoming value is `null` and
the stored row has one. A `beforeSaveTransaction` hook that *computes* a `serverOnly` value assigns
it, and it is written like any other field. The one case that needs an opt-out is a hook meaning to
**clear** such a field back to `null` — `allowServerOnlyOverwrite: true`, which then also lets an
ordinary client save blank the column.

The model is not re-read from the database after the write, so from `afterSaveTransaction` onwards a
`serverOnly` field on `currentModel` still holds what the client sent, even though the stored row
kept its value. A hook that needs the stored one reads `saveContext.initialModel`.

**Every read inside the transaction carries `saveContext.transaction`** — that is the two
in-transaction hooks, and every call they make. A model repository takes it as a named argument, so
does `dw.db(session)` (see
[working with a model you only know as a type](../4-server/generic-database-access.md)), and so do
the framework's profile reads:

```dart
beforeSaveTransaction: (session, saveContext) async {
  final author = await dw.currentUserProfile(session, transaction: saveContext.transaction);
  ...
},
```

Omitting it runs the read on its own connection. In production that works — it is merely blind to
the uncommitted rows around it, which is what makes the omission easy to miss. The bill arrives in
the test: under `serverpod_test` with database rollbacks enabled, which is the default, the proxy
sees a call arriving outside the active transaction, calls it concurrent, and throws `Concurrent
database calls outside an already active transaction are not supported when database rollbacks are
enabled`. The config keeps working in production and can no longer be driven through `save()` by an
integration test at all. `example/` pins this in
`test/integration/dw_core_profile_transaction_test.dart`.

Half of these reads need not happen at all: when the hook only needs to know *who* the caller is,
`session.signedInUserProfileId` is synchronous and costs nothing. Read the profile row when you need
something on it — a role, a balance, a consent flag.

**What comes back.** A successful save returns the persisted model plus `updatedModels`:
`beforeUpdates` + the saved row + `afterUpdates`. The client applies that list to every open list
and single-model provider, which is why the caller's own screens refresh without a refetch. Getting
the change onto *other* users' screens is `broadcastTo` — see [realtime.md](realtime.md).

**Database errors never reach the client verbatim.** A `DatabaseException` is reported through
`dw.alerts` in full and answered with the flat text `Database error during save`. A raw exception
carries table and constraint names, and a unique-violation would tell the caller whether a value
already exists.

## Reading: lists, and single rows by prototype

`DwGetModelListConfig` serves both `getAll` and `getCount`. Its parameters are `accessFilter`
(required), `allowAnonymous` (default `false` — see
[access and roles](access-and-roles.md)), `include` for eager-loading relations, and
`defaultOrderByList`:

```dart
getListConfig: DwGetModelListConfig(
  accessFilter: (session) async => null,
  include: NewsPost.include(authorProfile: UserProfile.include()),
  defaultOrderByList: [Order(column: NewsPost.t.createdAt, orderDescending: true)],
),
```

A filter sent by the client is turned into a `WHERE` and **ANDed with the access filter** — the
client narrows, it never widens. Ordering, `limit` and `offset` come from the client too, with
`defaultOrderByList` as the fallback.

`getModelConfigs` is a **list**, and works differently: each entry declares a `filterPrototype`, and
an incoming `getOne` request is matched against those prototypes by shape — field name, comparison
type, negation — not by value. No matching prototype, no answer: `notConfigured`. That is why one
model may have several read configs, each with its own filter shape, `include` and `accessFilter`.
The framework's own config for the signed-in user's profile is the smallest example:

```dart
DwGetModelConfig<UserProfileClass>(
  accessFilter: (session) async =>
      _userInfoIdColumn.equals(_authenticatedUserId(session) ?? 0),
  filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'id'),
  include: _userProfileInclude,
)
```

Prototypes are built with dedicated constructors — `.equalsPrototype(fieldName:)`,
`.andPrototype(children:)`, `.orPrototype(children:)`; there is no bare `DwBackendFilter(...)` on
the server.

**The trap:** `dw.repo.model<T>(id: 5)` on the client sends an equals-on-`id` filter, so it needs a
config with `equalsPrototype(fieldName: 'id')`. None of the nine configs in `example/` declares one
— the example reads everything through lists — so adding a by-id screen means adding the read config
first. `DwGetModelConfig` also takes `createIfMissing`, a callback that materialises the row when
the query finds nothing (settings, a profile-adjacent singleton).

## Deleting

```dart
deleteConfig: DwDeleteConfig<ClubService>(
  allowDelete: (session, model) => session.isClubAdmin,
),
```

`allowDelete` is nominally optional but effectively required: without it the call answers
`notConfigured`. `afterDelete` returns related rows that changed so the client can refresh them, and
`broadcastTo` mirrors the save side.

Three behaviours worth knowing, all from `DwDeleteConfig.delete`:

- A row that is already gone answers `isOk: true` with the warning `Model not found, possibly
  deleted earlier` — and that check runs *before* permissions.
- A foreign-key violation is translated into `Cannot delete model because other entities reference
  it` rather than surfacing the database error.
- **There is no before-hook and no transaction.** `afterDelete` runs once the row is already gone,
  with no transaction handle.

That last point decides a design question. A deletion that must atomically adjust a shared counter —
free a seat, return stock — cannot be done here. Model it as a status change through `DwSaveConfig`
instead, where a transaction and a lock exist. `example/` does this: a booking is never deleted, it
moves to `BookingStatus.cancelled`, and `sessionBookingCrudConfig` has no `deleteConfig` at all.

## When you do need an endpoint

The configs cover what fits the shape "a client writes a model, the server rules over it". Some
things do not: file upload and download, inbound webhooks, long-running processing, an operation
that is not about a single row.

Two intermediate steps come first, and skipping them is the usual mistake:

1. **A DTO config.** `DwDtoActionConfig<DTO>` runs an arbitrary transaction from a serializable
   model that has no table and returns the models it touched — an action shaped as a save.
   `DwDtoGetListConfig<DTO, Model>` serves a list of projections built from real rows.
2. **A model for the event.** If the operation is a fact worth recording — an auth attempt, a
   balance movement — write the fact as a row and put the logic in its save config. That is how
   DartWay's own auth works: the client saves a `DwAuthRequest`, and `dwAuthRequestConfig` drives
   the whole flow.

When a real endpoint is warranted, write it as an exception and say so in a comment: it is the one
place where the "read the config to know the rules" guarantee does not hold. Return a
`DwApiResponse` with its `updatedModels` filled in, and on the client feed it through
`dw.repo.processApiResponse` so open lists stay in sync — otherwise your bespoke endpoint is the one
operation the app's screens do not notice.
