---
name: dartway-crud-config
description: >-
  The DartWay/Serverpod server playbook: how to write CRUD configs — DwCrudConfig<T> (one per
  model), DwGetModelConfig, DwGetModelListConfig (both require accessFilter), DwSaveConfig
  (allowSave/validateSave/beforeSaveTransaction/afterSaveTransaction/afterSaveTransform/
  afterSaveSideEffects), DwDeleteConfig (allowDelete/afterDelete), DwModelWrapper,
  Event models, the domain(pure)/app(session-aware) boundary. All server logic goes through
  configs, not through endpoints. Use when adding or changing server logic, permissions,
  validations, or side effects for a model.
---

# DartWay — CRUD configs (server)

In DartWay, **all server logic goes through CRUD configs**, not through arbitrary endpoints. That buys consistency and predictability. The configs are wrappers (`DwSaveConfig`, `DwDeleteConfig`, `DwGetModelConfig`, `DwGetModelListConfig`) with callbacks for permissions, validation, processing, and side effects. See also `__SERVER_PKG__/CLAUDE.md`.

## DwCrudConfig<T> — the entry point per model

One `DwCrudConfig<T>` per model aggregates all the rules — it is the place both the developer and the AI look at.

**One config per file, and the file is named after its model.** The rule sounds like tidiness and is not: a config carries the model's whole access story, so a file holding several of them is several access stories under one name, and the name stops being a place to look. It rots the way you would expect — a real project had `studio_issue_activity_crud_config.dart` at 556 lines with five configs inside, named after `StudioIssueActivity`, a model that has never existed. Private helpers (`_validate…`, `_prepare…`) live with the config they serve; if one is genuinely needed by two models, that is a shared file of its own, not a reason to merge two configs.

```dart
final userProfileCrudConfig = DwCrudConfig<UserProfile>(
  table: UserProfile.t,
  getModelConfigs: [ ... ],   // several are allowed
  getListConfig: ...,
  saveConfig: ...,
  deleteConfig: ...,
);
```

Don't forget to register the config in `crudConfigurations` at `DwCore.init`. If the config is missing → the API returns `DwApiResponse.notConfigured`.

> **This is the one thing here that fails without a trace**, so `dartway check` guards it: a config
> written and left out of the list answers exactly as if the file did not exist (`crudConfigUnregistered`,
> an error), and a model with a table and no config at all is reported too (`crudConfigMissing`, a
> warning — the absence is also how you say "this table is the server's own", and the checker cannot
> tell which you meant). A config carrying hand-written save or delete logic that no server test names
> is `crudRuleUntested`; where that test goes is `dartway-testing`.

A registered config can still **fail** — a table not migrated yet, a filter naming a column the
schema does not have. That is a different answer from "not configured", and it reads differently:
`Unexpected error while handling the getAll request for ClubService`, with the exception and the
stack reported to `DwAlerts`. When a list is broken, the text tells you which of the two you are
looking at — the registration, or the query.

## accessFilter — the heart of secure-by-default

Two separate questions, and until 0.3.0 they were conflated into one:

- **who may call at all** — `allowAnonymous`, default `false`;
- **which rows they see** — `accessFilter`.

`accessFilter` is a **required** parameter: `(Session session) => Future<Expression?>`. It returns an SQL condition narrowing the selection, or `null` — "no row restriction".

**`null` here does not mean "signed-in users only".** It means no filter at all. Authentication is a separate gate: without `allowAnonymous: true` an unauthenticated caller is rejected before the config runs, with `DwApiResponse.notAuthenticated` — which the client can turn into "go to the login screen", unlike `forbidden`.

That is what makes access closed by accident impossible: no config → the model is not served; a config exists → the filter is written explicitly, and reaching it requires a session unless the config says otherwise **in a word you can grep for**:

```dart
// A public catalog: readable before the login screen, deliberately.
final clubServiceListConfig = DwGetModelListConfig<ClubService>(
  allowAnonymous: true,
  accessFilter: (session) async => null,
);
```

Before 0.3.0 there was no such word. A CRUD endpoint does not require a session (Serverpod's `requireLogin` defaults to `false` and `DwCrudEndpoint` never overrode it), so an `accessFilter` returning `null` published the whole table to the internet — and this skill used to call that "visible to every logged-in user". If you are upgrading, walk every config whose filter can return `null` and decide which ones are genuinely public.

```dart
/// Clients see only their own bookings, staff see all of them.
Future<Expression<dynamic>?> _bookingAccessFilter(Session session) async {
  if (await session.isStaffMember) {
    return null; // no restrictions
  }
  final userProfileId = session.signedInUserProfileId;
  return SessionBooking.t.clientProfileId.equals(userProfileId ?? -1);
}
```

The current user's id is `session.signedInUserProfileId` (not `session.userId`) — **synchronous**, read off the token Serverpod already resolved, so it costs nothing and needs no `await`. It says the caller presented a valid token, not that the profile row still exists. Ownership checks go through `session.isUser(profileId)`, which is also synchronous and takes a **non-nullable** id on purpose: written as `model.ownerId == session.signedInUserProfileId` over a nullable column, an anonymous caller reads `null == null` and is let in. Need the whole profile row — `dw.currentUserProfile(session)`, and that one does hit the database.

## DwGetModelConfig — a single entity by filter

Parameters: `accessFilter` (**required**), `filterPrototype` (**required** — which requests it applies to), `createIfMissing` `(session, filter) => model`, `include` (eager loading of relations), `defaultOrderByList`. A model may have several configs — different filters or different permissions.

On the server the prototype is built with dedicated constructors: `DwBackendFilter.equalsPrototype(fieldName: ...)`, `.andPrototype(children: [...])`, `.orPrototype(children: [...])`. There is no bare `DwBackendFilter(...)` — the constructor is private.

The prototype describes the **shape** of the request (which field and how it is compared), not the value: concrete filters from the client are matched against it. On the client side filters are not built by hand — there you have an enum with `DwBackendFiltersMixin` and its `.equals()` / `.greaterThan()` (the contract is in `dartway-data-layer`):

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();
}

// in the data layer: AppBackendFilters.clientProfileId.equals(userProfileId)
```

```dart
final userProfileGetConfig = DwGetModelConfig<UserProfile>(
  accessFilter: (session) async => null,
  filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'id'),
  include: UserProfile.include(address: Address.include()),
);
```

## DwGetModelListConfig — a list

Parameters: `accessFilter` (**required**), `include`, `defaultOrderByList`.

```dart
final clubSessionListConfig = DwGetModelListConfig<ClubSession>(
  accessFilter: (session) async => null,
  include: ClubSession.include(service: ClubService.include()),
  defaultOrderByList: [
    Order(column: ClubSession.t.startsAt, orderDescending: false),
  ],
);
```

**An `include` is not a property of one config — it is a property of the model.** Give it a name of
its own (`final clubSessionInclude = …`) and hand that same value to every config returning the
entity, and to every hand-written read of it. **The client replaces the model with whatever
arrives**, so one exit that forgets the include blanks the nested lists on every device — with no
error anywhere. The full rule, and the three exits it covers, are in `dartway-data-layer` §3a.

## DwSaveConfig — create + update (unified)

**All hooks share one signature:** `(Session session, DwSaveContext<T> saveContext)`. No `(initial, updated)` — both of them live in the context.

`DwSaveContext<T>`: `currentModel` (the model at the current step — this is the one you edit), `initialModel` (what was in the DB, null on insert), `isInsert`, `currentUserId`, `transaction`, `beforeUpdates`/`afterUpdates` (lists of `DwModelWrapper` for the client), `extras` (to carry data between steps).

Execution order and signatures:

1. `allowSave` → `Future<bool>` — permissions, **required**
2. `validateSave` → `Future<String?>` — the error text or null
3. **the transaction opens:** `beforeSaveTransaction` → `Future<String?>` → insert/update → `afterSaveTransaction` → `Future<String?>`
4. outside the transaction: `afterSaveTransform` → `Future<String?>` (awaited, can reject), then `afterSaveSideEffects` → `Future<void>` (non-blocking)

**Both in-transaction hooks return `String?` — just like `validateSave`.** Returned text → the save is rejected, the transaction is rolled back, the text reaches the client; returned `null` → we move on. This is precisely how you reject on a rule that is only visible inside the transaction.

**Nobody waits for `afterSaveSideEffects`, so nothing it does can reach the caller — its failure included.** By the time it throws, the response has been built and says `isOk`. The framework reports the throw to `DwAlerts`, so the operator hears it, and that is the whole of its audience. **Anything the user has to be told about goes in the awaited hook**, `afterSaveTransform`: it returns `String?` like the rejecting hooks above, and its text becomes the error in the response.

The question is who needs to know, not when the work happens. A push notification nobody misses if it is late → `afterSaveSideEffects`. A verification code, a payment handed to a provider, an invitation the whole feature is about → `afterSaveTransform`, and the caller waits for it.

One consequence to write into the hook: `afterSaveTransform` runs **after** the commit, so rejecting there does not undo the write. The row stays saved and only the response says no. Write the hook so that a retry is harmless, and say in the error text that retrying is what to do.

**Its other job: re-reading the saved model with its `include`.** `saveContext.currentModel` holds
the flat row that was written — hand that back and every client replaces its copy with a parent that
has no children. Running after the commit, the hook also sees what the hooks themselves created:

```dart
afterSaveTransform: (session, saveContext) async {
  final reloaded = await loadTicketGraph(session, saveContext.currentModel.id!);
  if (reloaded != null) saveContext.currentModel = reloaded;
  return null;
},
```

```dart
afterSaveTransform: (session, saveContext) async {
  try {
    await sendInvitationEmail(session, saveContext.currentModel);
  } catch (exception, stackTrace) {
    // The operator gets the provider's actual complaint, the user gets a
    // sentence they can act on. Do not hand the provider's message to the
    // client — it names your delivery configuration.
    dw.alerts.reportError(
      'Failed to send the invitation',
      exception: exception,
      stackTrace: stackTrace,
    );
    return 'Could not send the invitation. Please try again.';
  }
  return null;
},
```

**Why this and not `validateSave`:** steps 1–2 run BEFORE the transaction, so a rule guarding a shared counter (seats, stock, limits) is evaluated there — two parallel saves would both get a "yes". Check such a rule in `beforeSaveTransaction`, taking a **row lock** in the same transaction: `findById(..., transaction:, lockMode: LockMode.forUpdate)` — a single call both locks the row (`SELECT ... FOR UPDATE`) and returns it. `validateSave` checks the model, `beforeSaveTransaction` checks the world around it.

**A hook that runs inside the transaction reads the database only through `saveContext.transaction`.** That is `beforeSaveTransaction` and `afterSaveTransaction`, and it applies to every read they make — a model repository (`UserProfile.db.findById(session, id, transaction: saveContext.transaction)`), `dw.db`, or the framework's own profile reads, which take the transaction as a named argument:

```dart
beforeSaveTransaction: (session, saveContext) async {
  final author = await dw.currentUserProfile(session, transaction: saveContext.transaction);
  ...
},
```

A read that omits it runs on its own connection: in production it works, merely blind to the uncommitted rows around it — which is what makes the omission easy to miss. **The bill arrives in the test.** Under `serverpod_test` with database rollbacks enabled, which is the default, the proxy sees a call arriving outside the active transaction, calls it concurrent, and throws `Concurrent database calls outside an already active transaction are not supported when database rollbacks are enabled`. So the config still runs in production and can no longer be driven through `save()` by an integration test at all.

**And half of these reads should not happen.** When the hook only needs to know *who* the caller is — stamping an author, an owner, a `createdBy` — `session.signedInUserProfileId` is synchronous, costs no query, and sidesteps the question entirely. Reach for the profile row only when you need something on it (a role, a balance, a consent flag).

**If the rule depends on the current state of the row itself** (roles, consent flags, balance, a deleted marker) — turn on `lockInitialModelForUpdate: true`. Then on an **update** the initial model is re-read under `FOR UPDATE` inside the transaction, and steps 1–2 are evaluated against it: a parallel save of the same row waits and gets re-validated against what was actually committed, instead of passing on a stale pre-state. The flag is optional (defaults to `false`, the cycle is unchanged) and has no effect on insert — there is nothing to lock yet.

**A `scope=serverOnly` field is held in both directions, and there is nothing to configure for it.** Such a field is absent from the generated **client** class entirely, and the framework honours that on both legs of the round trip:

- it is **never sent** — stripped out of every CRUD response, every realtime broadcast and the sign-in payload;
- it is **never blanked by a client save** — the field cannot be in the JSON a client sends, so the deserialised model carries `null` there, and an update writing the whole row would erase the column. It is left out of the `UPDATE` instead, and the database keeps its value.

So `scope=serverOnly` is the right tool for anything the server owns and the client must not read: an internal hash, a computed score, a verification secret, a moderation note.

The second rule is narrow on purpose — it skips the column **only** when the incoming value is `null` and the stored row has one. A hook that *computes* a `serverOnly` value writes it like any other field:

```dart
beforeSaveTransaction: (session, saveContext) async {
  saveContext.currentModel = saveContext.currentModel.copyWith(
    internalScore: await recomputeScore(session, saveContext),
  );
  return null;
},
```

The one case that needs an opt-out is a hook meaning to **clear** a `serverOnly` field back to `null`: set `allowServerOnlyOverwrite: true` on the config, and accept that an ordinary client save will then blank the column too.

One residual behaviour worth knowing: the model is not re-read from the database after the write, so from `afterSaveTransaction` onwards a `serverOnly` field on `currentModel` still holds what the client sent — `null` — even though the stored row kept its value. A hook that needs the stored value reads `saveContext.initialModel`.

### Returning a value the row does not hold

`scope=serverOnly` says "the server keeps this and never sends it". The opposite need is just as ordinary — **the server sends this and never stores it**: a freshly issued access key, a one-time code, a receipt computed during the write. A save can answer with it, entirely through CRUD, and the pattern is three pieces that say nothing on their own:

1. **`!persist` on the field** — a place on the model with no column behind it;
2. **`saveContext.extras`** — carries the value from the hook that produced it to the hook that answers;
3. **assignment to `saveContext.currentModel` in `afterSaveTransform`** — the response is built from that object, after the commit.

```dart
// device_registration.spy.yaml
//   deviceId: String
//   accessKey: String?, !persist        ← sent, never stored

beforeSaveTransaction: (session, saveContext) async {
  final key = generateAccessKey();
  await storeKeyHash(session, key, transaction: saveContext.transaction);
  saveContext.extras['accessKey'] = key;   // the hash is written, the key is not
  return null;
},
afterSaveTransform: (session, saveContext) async {
  saveContext.currentModel = saveContext.currentModel.copyWith(
    accessKey: saveContext.extras['accessKey'] as String,
  );
  return null;
},
```

**Assign it in `afterSaveTransform`, not earlier.** A value merely left on the model before the transaction reaches the caller only for as long as the framework does not re-read the row after writing. It does not today — but that is somebody else's internal detail, and a feature built on it breaks on a change nobody will connect to it. The hook is where the response is assembled, so that is where the answer is decided.

> ⚠️ **What you assign is also what gets broadcast.** The response and `broadcastTo` are built from the **same** object: `updatedModels` carries `DwModelWrapper(object: saveContext.currentModel)`, and every channel this config broadcasts to receives it. A one-time code assigned this way reaches every subscriber of that channel, not only the caller who earned it. So a save that issues a secret **must not broadcast** — and if the model genuinely needs live updates elsewhere, the secret is not travelling this way; it wants `scope=serverOnly` plus a read of its own.

**Why this is worth spelling out.** Each piece is documented somewhere and none of them announces the pattern, so the reasoning that actually happens is: *the response is the row · the value is not in the row · therefore CRUD cannot do this · therefore a custom endpoint.* Only the third step is wrong, and it looks like arithmetic. The bill is not the exception spent for nothing: a write outside `dw.repo` leaves every list over that model stale, so the app reaches for `ref.invalidate` to patch the list up by hand — propagation, which the clean-code contract forbids (`dartway-clean-code` §1.5) — and the damage surfaces three layers from its cause, looking like the framework's fault.

**To make other users see the change** — `broadcastTo` in the config: a callback over the context that returns the list of channels all the models touched by the save fly into. On the subscribers' side they are routed by type into any `dw.repo.modelList<T>()`, and the list redraws itself — nothing has to be written in Flutter (the app is subscribed to the public channel at the root).

```dart
broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],   // public model
broadcastTo: (session, ctx) => ['chat:${ctx.currentModel.chatId}'],  // a narrower audience
```

What flies out is `beforeUpdates` + `currentModel` + `afterUpdates` — the very same set the caller
gets back. So a model with an `include` reaches the channel with its graph **only if
`afterSaveTransform` re-read it**; otherwise the subscribers' copies lose their children while the
saver's own screen looks fine (`dartway-data-layer` §3a). The same goes for an imperative
`session.sendUpdates(...)` and for a worker's `sendUpdatesToUser(...)`: whatever model you hand
them is what replaces the client's.

**A channel your app names itself has to be declared**, or nobody can subscribe to it. Add it to `channelConfigurations` in `DwCore.init` next to the `broadcastTo` that invented it — a channel name arrives from the client as a bare string, and the declaration is how the server tells a real one from a guess:

```dart
channelConfigurations: [
  DwChannelConfig.public(prefix: 'catalogue'),                    // anyone, signed in or not
  DwChannelConfig.owner(prefix: 'orders'),                        // orders42 — user 42 only
  DwChannelConfig.guarded(                                        // your own check
    prefix: 'chat:',
    allowListen: (session, suffix) async => await session.isChatMember(int.parse(suffix)),
  ),
],
```

`DwCoreConst.publicUpdatesChannel` is declared by the framework — a config that broadcasts only there needs nothing added. Forgetting the declaration fails silently at runtime: the app compiles, the save broadcasts, and the subscription is refused. A prefix is a prefix, so give a parametrised channel a separator (`chat:`, not `chat`) and name a public one in full.

**A channel is an audience whose payload the framework cannot verify:** everything the save touched flies out to every subscriber, regardless of `accessFilter`. The declaration says who may be in the audience; it does not filter what travels. Hence the default of `null`, and the public channel is only for models everyone is entitled to read anyway. If a private row is being saved while something else changed publicly (the booking is private, the seat counter is public) — do not attach `broadcastTo`; instead pick in `afterSaveSideEffects` what exactly to send: `session.sendUpdates(channels: [...], updatedModels: [publicModel])`.

```dart
beforeSaveTransaction: (session, saveContext) async {
  if (!saveContext.isInsert) return null;
  // Lock and read the session in one call — concurrent bookings
  // serialize on this row, overselling seats is impossible.
  final clubSession = await ClubSession.db.findById(
    session,
    saveContext.currentModel.clubSessionId,
    transaction: saveContext.transaction,
    lockMode: LockMode.forUpdate,
  );
  if (clubSession == null) return 'Session not found';

  final taken = await SessionBooking.db.count(
    session,
    where: (t) => t.clubSessionId.equals(clubSession.id!) &
        t.status.equals(BookingStatus.booked),
    transaction: saveContext.transaction,
  );
  if (taken >= clubSession.capacity) return 'No spots left';
  return null;
},
```

```dart
final clubSessionSaveConfig = DwSaveConfig<ClubSession>(
  allowSave: (session, saveContext) async => session.isStaffMember,
  validateSave: (session, saveContext) async {
    final clubSession = saveContext.currentModel;
    if (clubSession.capacity < 1) {
      return 'Capacity must be at least 1';
    }
    if (saveContext.isInsert && clubSession.startsAt.isBefore(DateTime.now())) {
      return 'Session cannot start in the past';
    }
    return null; // the model is fine — let it through
  },
  beforeSaveTransaction: (session, saveContext) async {
    saveContext.currentModel = saveContext.currentModel.copyWith(
      capacity: saveContext.currentModel.capacity.clamp(1, 100),
    );
    return null; // no objections — otherwise we would return the error text
  },
  afterSaveSideEffects: (session, saveContext) async {
    await AppNotifications.sendSessionUpdated(session, saveContext.currentModel);
  },
);
```

The model is edited through `saveContext.currentModel`; related updates for the client go into `saveContext.beforeUpdates` / `saveContext.afterUpdates`. Transactional hooks must end with `return null` when they do not reject — otherwise the analyzer will catch `body_might_complete_normally_nullable`.

**What goes into those lists is subject to the same include rule.** A child is put in flat and the
client folds it into its parent itself; a **parent** is re-read with its include first. A bare
`DwModelWrapper(object: parentModel)` — including from a child's own config, which is where it
usually appears — wipes the graph on every subscriber, silently (`dartway-data-layer` §3a).

## DwDeleteConfig — deletion

Parameters: `allowDelete` `(session, model) => bool` (without it → `notConfigured`), `afterDelete` `(session, model) => [related]`, `broadcastTo` `(session, model) => [channels]` — symmetric to the save config. **If a model broadcasts its saves, it almost always has to broadcast its deletions too**: otherwise the other clients keep a row hanging around that no longer exists, and that gets discovered at the worst possible moment. If the model is not found → ok with a warning. A `DatabaseException` (an FK, for example) → an error.

**An important limitation:** `DwDeleteConfig` has neither a before hook nor a transaction — `afterDelete` runs **after** the row has already been deleted, without a transaction handle. A race-sensitive recomputation (free up a seat, return stock to the warehouse) cannot be done here. If the deletion has to change a shared counter atomically — do not delete the row, do a **soft delete via a status** through `DwSaveConfig` (`status: cancelled`): there you have a transaction and `beforeSaveTransaction` with a lock. Example — cancelling a booking for a session.

```dart
final userProfileDeleteConfig = DwDeleteConfig<UserProfile>(
  allowDelete: (session, model) async => model.balance <= 0,
  afterDelete: (session, model) async => BalanceEvent.db.find(
    session,
    where: (t) => t.userProfileId.equals(model.id),
  ),
);
```

## Which logic goes where

- **Keep configs small** — permissions, checks, processing, side effects only.
- **Pure logic** (computations from fields, no Session/IO) → `/domain` (extensions on models).
- **Workflow** (session-aware: external APIs, orchestration) → `/app`.
- **Transactional/money flows** → Event models (`BalanceEvent`) instead of updating a field directly: safety from races, an audit trail, one place for the rules.
- Wrap all updates in responses in `DwModelWrapper`.

### An operation that spans several models goes through `dw.db`

In `/app` you will hit work where the model is a **type parameter**, not a name: a data migration, a background cleanup, an export, a purge. Serverpod generates a repository per model and none of a common type, so there is nothing typed to call — and its generic `session.db.find<T>()` / `insertRow<T>` / `updateRow<T>` are marked `@internal`. Use `dw.db(session)` instead, which wraps the five that matter:

```dart
Future<int> purgeStale<T extends TableRow>(Session session, Expression stale) async {
  final db = dw.db(session);
  final rows = await db.find<T>(where: stale);
  for (final row in rows) {
    await db.deleteRow<T>(row);
  }
  return rows.length;
}
// find<T>, insertRow<T>, updateRow<T>, deleteRow<T>, count<T> — each takes an
// optional `transaction`, and inside a hook that is not optional (see above).
```

**`// ignore_for_file: invalid_use_of_internal_member` in application code means a Serverpod upgrade can break your build silently** — you have reached into another package's private surface, and nothing warns you when it moves. If you catch yourself writing that line, or writing a three-line adapter per model whose bodies differ only in the model's name, `dw.db` is the answer.

For **one known model**, keep using that model's own repository (`ClubSession.db.findById(...)`) — typed, public, and more readable. `dw.db` is not a replacement for it.

## A custom endpoint — the last resort

Only when it does not fit into CRUD (file upload/download — often still shaped as a `FileUploadRequest` model, webhooks, heavy async processing). Document it as an exception.

**Before concluding that it does not fit, check the rungs that are easy to miss** — each of these has been re-implemented as an endpoint by somebody who did not know it was there:

| The need | Where it already lives |
|---|---|
| The response must carry a value the row does not hold | `!persist` + `extras` + `afterSaveTransform` — "Returning a value the row does not hold" above |
| The operation is a write that is not one model | `DwDtoActionConfig` |
| The answer is a projection over rows rather than the rows | `DwDtoGetListConfig` |
| The response must carry the model's relations | `afterSaveTransform` re-reading with the same `include` |

One class of operation genuinely has no rung, and it is worth naming so the search stops: an operation whose **answer comes from outside the database** — probing an external service under credentials the client must not hold, verifying that a connection works, resolving something from a third party. It reads nothing, writes nothing, and its result must not be stored, because a stored answer to "is this working right now" goes stale in silence. `DwDtoGetListConfig` cannot carry it (the projection is synchronous, and its only argument becomes a SQL `WHERE`), and `DwDtoActionConfig` holds a database connection open across the network call. That one is an endpoint, deliberately — not because you failed to find the rung.

## Workflow and tests

Model in `/models` → `serverpod generate` → `create-migration` → `dart format` over both generated paths (in that order — `create-migration` regenerates, and the generator's `dart_style` is not the project's; see `dartway-models`) → a `DwCrudConfig` in `/crud` → logic in `/domain` or `/app` → tests. Unit tests for every config (permissions, validation, pre/post, sideEffects) and for Event models. A bugfix starts with a failing test for the cause.
