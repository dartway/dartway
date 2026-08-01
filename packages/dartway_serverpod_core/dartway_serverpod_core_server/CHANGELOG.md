# Changelog

## 0.3.0

**Generic CRUD is closed to anonymous callers by default.** `DwCrudEndpoint` never overrode
Serverpod's `requireLogin`, which defaults to `false`, so every CRUD operation was reachable without a
session and `accessFilter` was the only gate — and an `accessFilter` that returns `null` filters
nothing. An unset or permissive filter therefore published the whole table to the internet. That
contradicted the framework's own rule: not configured means not allowed.

Read, save and delete configs now carry `allowAnonymous`, default `false`. An unauthenticated caller
is rejected before the config runs, with the new `DwApiResponse.notAuthenticated` — distinct from
`forbidden`, so the client can tell "log in" from "you may not", and send the user to the login
screen.

The gate is per config rather than on the endpoint on purpose: one CRUD endpoint serves every model,
so `requireLogin` would have been all-or-nothing and would have killed legitimately public reads.
A public catalog or settings the splash screen reads now say so in a word that shows up in review —
`allowAnonymous: true` — which `null` never did.

**Breaking, and silently so:** the default changes behaviour at runtime, not at compile time. An app
that served data to signed-out callers keeps compiling and starts refusing them. Audit every config
whose `accessFilter` is absent or can return `null`, and mark the deliberately public ones.

The framework's own sign-in path needed exactly that treatment, and it is worth knowing about before
you audit your own: `dwAuthRequestConfig` and `dwAuthVerificationConfig` are marked
`allowAnonymous: true`, because requesting a code and submitting it *are* how a caller acquires a
session. Without the exception, authentication asks you to authenticate first. What guards them is
not the session but rate limiting, per-identifier locking and a bounded attempt count, all of which
were already there. `dwAuthKeyConfig` needs no exception — it only exposes delete, and deleting a key
requires being its owner.

`saveModelStream` is gated the same way as `saveModel`; a write does not become public by returning
its result over a channel.

**Realtime channels are declared, and an undeclared channel cannot be subscribed to.**
`subscribeOnUpdates` took a channel name as a plain string from the client and opened it, unchecked.
Channel names are guessable by construction — `userUpdates42` is one character from `userUpdates43` —
so the framework's own per-user channel was readable by anyone signed in, not by its owner. That is
why this is not another `allowAnonymous`: authentication was never the missing check.

`DwCore.init` now takes a required `channelConfigurations`, and `DwChannelConfig` says who may listen:
`public` (anyone), `owner` (the user whose profile id the name ends with), `guarded` (your own
predicate over the session and the part of the name after the prefix, with `allowAnonymous` defaulting
to `false`). Declarations match by prefix, longest first. The framework declares its own two —
`DwCoreConst.publicUpdatesChannel` and the per-user channel behind `sendUpdatesToUser`.

**Breaking twice over:** `channelConfigurations` is required, so `DwCore.init` stops compiling until
you pass it; and every channel your app names itself must be listed or its subscriptions are refused
at runtime while everything still compiles. Grep for `broadcastTo` and for
`DwChannelSubscriptionWidget` — between them they name every channel the app has.

**`Session.currentUserProfileId` is now `Session.signedInUserProfileId`, and it is synchronous.**
It read the whole user profile row from the database to return an id that was already in the token —
a habit from the version of Serverpod where `session.authenticated` was itself a `Future` and the
extra query was invisible because everything was async anyway. Since 3.x `authenticated` is a cached
synchronous getter, resolved before any endpoint code runs, so the round trip bought nothing. With
the authentication gate above running on every CRUD call and every subscription, it was no longer a
rounding error. `isUser(profileId)` is synchronous for the same reason.

The rename is deliberate, because dropping `Future` alone would have broken nothing: `await` on a
non-`Future` compiles. The **meaning** changed and had to be looked at, once, at every call site.
What changed: the old getter returned `null` when the profile row was missing, so a deleted profile
whose token was still around read as "not signed in". That was an aliveness check nobody wrote down,
and it only ever caught hard deletion — a banned or soft-deleted user passed it then and passes it
now.

**That check now exists on purpose.** `DwAuth.revokeAuthKeys(session, userProfileId:)` ends every
session a user holds: it deletes the keys, and — because a websocket resolves its authentication once
when it opens and would otherwise keep receiving — broadcasts Serverpod's revocation message to tear
open connections down. Call it on deletion, ban, deactivation, "sign out everywhere", a changed
identifier. Ordinary requests need no more than the delete: `dwAuthenticationHandler` reads the key
from the database every time, so nothing outlives its revocation. Serverpod only listens for
revocation on method streams, so a connection held by the legacy `DwRealTimeEndpoint` survives until
it closes on its own.

**`DwOrphanedAuthKeyCleanup`** is the net under that. A `DwRecurringFutureCall` (hourly by default)
that deletes keys whose profile no longer exists — needed because keys carry no expiry and
`DwAuthKey.userId` cannot carry a foreign key: the profile table belongs to the app, so nothing
cascades from it. Register it with `DwRecurringJobs.startAll(pod, [DwOrphanedAuthKeyCleanup()])`;
`example/` and `template/` now do. It replaces a per-request check with a per-interval one, and the
window it opens is the honest price.

While closing this, a leak was fixed in the same path: guarding a subscription means an `await`
before the stream opens, and a session that closed during that await left a channel listener behind
that nothing would remove. The stream is now opened before the check and torn down if the check
refuses.

Also: `DwDeleteConfig.delete` now answers `notConfigured` before it touches the database. Existence
probing by unauthenticated callers is closed by the gate above; a signed-in caller can still tell a
missing row from one they may not delete, which is documented in the code as a remaining decision.

## 0.2.3

Lockstep release: no changes of its own.

## 0.2.2

Released in lockstep with the rest of `dartway_serverpod_core_*`; the change is in
the Flutter package. Nothing changed here, but the server side is what makes it
work: the internal user-profile config filters by the authenticated user, so a
request carrying a dead key matches no row — which the client now reads as "this
session is over" instead of keeping its cached profile.

## 0.2.1

- **`broadcastTo` on `DwSaveConfig` and `DwDeleteConfig`** — a config answers, per
  operation and with the context in hand, which channels the models it changed
  travel to. That is cross-user realtime as a line of configuration: subscribers
  route each arriving model by type into any `dw.repo.modelList<T>()` they hold,
  so a list already on screen redraws itself with no listener written on either
  side. Deletions are symmetric on purpose — without them the other clients keep
  a row that is no longer there, which is noticed at the worst possible moment.
  Null by default: a channel is an audience the framework cannot check, and what
  you broadcast reaches every subscriber whether or not `accessFilter` would have
  shown them that row.
- **`session.sendUpdates(channels:, updatedModels:, deletedModels:)`** — the same
  delivery, imperatively, for when the choice of *what* travels matters as much
  as where: a save whose own row is private may still need to tell everyone that
  a public counter moved. `sendUpdatesToUser` stays as the named shortcut for the
  one audience that is always safe, and now delegates to it.
- **`DwCoreConst.publicUpdatesChannel`** — a ready-made name for "everyone using
  this app", so both halves can agree on one spelling without a shared package to
  put it in. The core never posts there on its own.
- **Uploads fail with a sentence instead of a null check.** `DwUploadEndpoint` is
  mounted whether or not an app configured storage, and reaching it without
  `cloudStorageConfig` used to die on `dw.cloudStorage!` — a crash that says
  nothing about what is missing. It now states what to configure.

## 0.2.0

- **A closed streaming connection no longer stays in memory.** Two references outlived
  every connection, so a client that reconnects — routinely, on an unstable network —
  stranded a whole connection graph each time: the websocket, the request and the
  buffered session log. Under production load that was one leaked graph every few
  seconds. Both endpoints keep their signatures and their behaviour; only teardown
  moved. Measured against serverpod 3.4.10 and 3.4.11.
  - `DwRealTimeEndpoint` no longer calls the deprecated `setUserObject`. Serverpod
    never releases what that puts in `Endpoint._userObjects`, and the endpoint is a
    singleton living as long as the process, so every authenticated connection stayed
    reachable from it forever. The channel listener is now dropped from a will-close
    listener on the session itself, which makes the endpoint stateless and closes a
    second hole — a `streamClosed` that Serverpod skips when authorization for the
    endpoint has been revoked mid-connection. **Teardown now runs when the session
    closes rather than in `streamClosed`, a few milliseconds later in the same
    shutdown.**
  - `DwCrudEndpoint.subscribeOnUpdates` and `.saveModelStream` no longer use
    `session.messages.createStream`. It registers a cleanup callback in a map keyed by
    the session, and on the teardown path *every* websocket takes — the stream is
    cancelled before the session is closed, so `removeListenersForSession` finds
    nothing left and returns before reaching that map — the entry outlives the
    session. They subscribe to the channel directly instead, releasing the listener
    both on stream cancellation and on session close.

- **Serverpod 3.4.11.** Bumped from 3.4.8 and regenerated everywhere (core, the push
  module, example, template). All three intervening releases are bugfixes — notably
  correct column mapping for joins with long names and deeply nested relations, and
  migrations now being generated when an index's columns change. Framework packages
  keep a caret range (`^3.4.11`) so they stay co-installable with whatever Serverpod
  patch an app is on; `template/` pins exactly, so a new project starts on a
  combination known to match the generator.
- **`DwRecurringFutureCall.startAll` moved to `DwRecurringJobs.startAll`** (same
  signature). Serverpod 3.4.11 validates *every* public method of a `FutureCall`
  subclass as a future-call handler and requires its first parameter to be a
  `Session`, which a starter taking the `Serverpod` instance can never satisfy — so
  the starter now lives on its own class beside the base.

- **`DwSaveConfig.lockInitialModelForUpdate`** — opt-in row-lock serialisation for
  updates. By default the save lifecycle reads the initial model and runs `allowSave`
  / `validateSave` *outside* the transaction and only writes inside it, so two
  concurrent saves of the same row can both read the same pre-state, both pass their
  checks and both write — a lost update, or a rule quietly bypassed. With the flag on,
  the initial model is re-read under `FOR UPDATE` inside the transaction and the rules
  run against it, so a concurrent save waits and then re-validates against what was
  actually committed. Off by default (lifecycle unchanged) and a no-op for inserts,
  which have no row to lock yet. Worth enabling for rows whose rules depend on their
  own current state — roles, consent flags, balances, a deletion marker.
- **Save no longer returns raw database errors to the caller.** A `DatabaseException`
  from a save used to be interpolated straight into the API error string, handing the
  client table and constraint names and the offending key value — schema disclosure,
  and with a unique-constraint violation an oracle for "does this value already
  exist". The caller now gets a stable `Database error during save`; operators still
  get the full exception and stack trace through `dw.alerts`.
- **`DwAuthConfig.preAuthKeyIssuance`** — a final application-owned authorization
  check immediately before an auth key is inserted, running in the *same* short
  transaction as the insert. An app that locks and re-reads its user row through the
  supplied `transaction` can no longer be raced by an account deletion committing
  between the check and the key insert; the two serialise. Returning a
  `DwAuthFailReason` rejects issuance and rolls the insert back, surfaced as the new
  typed `DwAuthKeyIssuanceRejectedException`.

**One `dw` root on the server.** The initialized core is now reached through a single package-private
`dw` object (mirroring the Flutter side), so framework code accesses every service the same way —
`dw.advisoryLock`, `dw.alerts`, `dw.getCrudConfig(...)`. The static `DwCore.instance` accessor is gone;
all internal call sites moved to `dw`. The framework does not export `dw` — the app declares its own
typed `dw` (`DwCore<UserProfile>`), one access style across the whole stack.

- **`dw.advisoryLock`** — `DwAdvisoryLock`, a non-blocking, transaction-scoped Postgres advisory-lock
  primitive keyed on `(namespace, key)`, with framework-reserved namespaces in `DwAdvisoryLockNamespace`.
  Generalises the guard previously inlined in the auth flow (`DwAuthConcurrency` now delegates to it),
  so any subsystem — push delivery, account deletion, outbound jobs — reuses one primitive instead of
  hand-rolling advisory-lock SQL.
- **`DwRecurringFutureCall`** — base class for a recurring future call that owns its whole lifecycle:
  registration, first run, re-arming after every run (including a failed one, reported via `dw.alerts`),
  and cancelling a stale schedule on restart. A subclass declares only `name`, `interval` and `run`;
  the app hands its jobs to `DwRecurringJobs.startAll(pod, [...])` once at startup and touches no
  Serverpod future-call plumbing. The imperative scheduler Serverpod 3 deprecated is isolated to one
  private method behind this seam.

## 0.1.0

First public release — the server half of the DartWay core, a Serverpod module.

**Generic model-driven CRUD.** `getOne` / `getList` / `save` / `delete` and realtime `subscribe`
for any model, with no hand-written endpoints. One `DwCrudConfig<T>` per model declares the whole
behaviour: `accessFilter` for reads; `allowSave` → `validateSave` guards, then
`beforeSaveTransaction` → write → `afterSaveTransaction` inside a single transaction, and
`afterSaveTransform` / `afterSaveSideEffects` outside it; ordering, includes, pagination.

**Rules that guard a shared count are enforced where they hold.** `allowSave` and `validateSave`
run *before* the transaction opens, so a rule about seats left or stock on hand can be raced —
fired together, two saves both read four-of-five and both get in. The two in-transaction hooks
reject the same way a validation does: return the error text and the write rolls back with that
message reaching the client, instead of the rule quietly buying nothing.

**Secure by default.** A model with no config is not reachable. Access is something you grant, never
something you forget to take away — and an AI agent cannot ship a feature with an open backend by
omission.

**Passwordless phone auth** on the app's own user model: the framework never owns your
`UserProfile`. Limits are on by default and configurable through `DwAuthConfig` — codes expire
(10 min), guesses are capped per request (5, after which the request is burned), and requests are
rate-limited per identifier (5 per 10 min). `DwAuthFailReason` tells the client which limit it hit.

**The limits are enforced in the database, not by read-then-write in Dart.** Under Postgres' default
READ COMMITTED isolation, checking a counter and then updating it is not a limit at all: fired
concurrently, twenty guesses buy ten evaluated attempts against a cap of five, and a "single-use"
access token signs the caller in twice. Verification attempts and rate limiting take
transaction-scoped advisory locks, and an access token is claimed with a conditional
`UPDATE ... WHERE status = 'verified'`, so a second redemption matches no rows (`DwAuthConcurrency`).

The locks are **non-blocking on purpose**: a waiting lock holds a pooled connection while it queues,
so hammering one identifier could drain the pool — trading a race for a denial of service. Failing
to take the lock means a request for that identifier is already in flight, which for a rate limit is
not an error but the answer.

**Pluggable password hashing** — bring your users' passwords with you. `DwAuthConfig.passwordHasher`
is the one format DartWay writes (`DwBcryptPasswordHasher` by default);
`legacyPasswordVerifiers` lists formats it can only *read*: the hashes of a system you are migrating
off. A hash is one-way, so without their old algorithm your users simply cannot log in. Register it,
and DartWay lets them in with the password they have always used and **rewrites the hash in the
active format during that sign-in** — the plaintext exists only then, which is why an offline
migration script cannot do this and a lazy upgrade must. Each migrated user pays the legacy path
exactly once.

**External identity providers** (Apple, Google, Telegram): `DwAuthConfig.verifyExternalCredential`
validates a credential issued by a third party and lets DartWay register or sign the user in.
Leaving it unset rejects every external provider — an unconfigured provider is a closed door.

**Also:** file uploads over S3/MinIO-compatible cloud storage (`DwCloudStorage`, login required),
and error alerts to Telegram with structured context.
