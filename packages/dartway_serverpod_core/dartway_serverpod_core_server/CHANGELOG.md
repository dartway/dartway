# Changelog

## Unreleased

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
  the app hands its jobs to `DwRecurringFutureCall.startAll(pod, [...])` once at startup and touches no
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
