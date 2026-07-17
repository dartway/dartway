# Changelog

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
