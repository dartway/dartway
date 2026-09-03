# Changelog

## 0.12.0

- **Uploads: the server names the object, and confirms only the reservation it issued.**

  `DwUploadEndpoint.getUploadDescription` took an object path from the caller and signed an S3
  policy for exactly it. `requireLogin` was the whole check — nothing tested that the key was
  free, that it belonged to the caller, or that it had any shape at all. So a signed-in user who
  knew somebody else's key overwrote the object behind it, and object storage reports an overwrite
  on neither side. `verifyUpload` completed the picture: it stated any path it was given and
  inserted a `DwCloudFile` naming the caller as the owner, so an object could be claimed without
  uploading a byte.

  The caller now names neither. It passes the folder the object belongs in, the extension of the
  bytes actually being sent and, optionally, a file name to be readable by; the server builds
  `<folder>/u<userId>/<stamp>_<name><ext>`, records it as a reservation and answers with a
  `DwUploadTicket` — the signed description plus the id of that row. `verifyUpload` takes that id
  and answers `null` for a reservation that is unknown, is not the caller's, or holds no bytes.

  `DwCloudFile` gains `fileName` and a **unique index on `(bucket, path)`**. The ledger is what
  makes a key unique now, so a repeat is a refused insert the endpoint answers by trying the next
  candidate rather than a silent overwrite.

  **The migration fails on a table that already holds two rows for one `(bucket, path)`** — which
  is precisely the trace this defect leaves. Find them before applying it:

  ```sql
  SELECT bucket, path, count(*), array_agg(id)
  FROM dw_cloud_file GROUP BY bucket, path HAVING count(*) > 1;
  ```

  Objects already in the bucket do not move, and `publicUrl` values already stored keep resolving:
  what changes is how new keys are built. Closes #191.

- **`dw_auth_request` is indexed on `(userIdentifier, createdAt)`.**

  Every code request reads that identifier's own send history — rate limiting asks, by
  construction, "how many times have we sent to them in the window". Without an index the answer
  is a sequential scan of the whole table on every sign-in: 126 thousand rows and 12 ms per
  request on a production app, and the number grows with a table that only ever accumulates.

  An app inherits the index the ordinary way: its own `serverpod generate` and
  `create-migration` pick it up from the module definition.

- **`DwSaveConfig.resolveExistingRowForInsert` — a create onto a taken natural key becomes an
  update of that row.**

  A model with a natural key besides its id — one person's answer to one question, one membership
  of one user in one chat — gets *created* by clients that have not seen the stored row: the list
  lagged, the person acted from a second device, the first response never arrived. That write hit
  the unique index and came back a database error: an alert for the team, and for the caller a
  failure it could do nothing about, because what it sent was exactly what it wanted stored.

  The new hook runs before everything else on an insert, looks the row up by that key and returns
  the model to write instead — the incoming values carrying the stored id. From there it is an
  ordinary update, so `isInsert`, `initialModel` and every later hook describe the save that is
  actually happening. Opt-in; return `null` and the insert stays an insert.

  It runs before the transaction, so two simultaneous creates can still both find nothing and race
  to the unique index — guard that in `beforeSaveTransaction` where it matters.

- **Breaking: `DwAuthConfig.normalizeIdentifier` is required.**

  It arrived a release earlier with a default that changed nothing, on the reasoning that folding
  case cannot be right for every app and must not break stored data. Both true — and together they
  meant the defect the parameter exists to close stayed open in every project that did not remember
  to declare a rule, which is precisely the projects that needed it. A default that changes nothing
  is not a safe default; it is the old behaviour wearing a new name.

  So the compiler asks once, per project. `DwIdentifierForm.folded` trims and case-folds;
  `DwIdentifierForm.asTyped` keeps the identifier byte for byte, and is still the only choice that
  cannot break identifiers already stored in mixed forms — but it is now chosen rather than
  inherited. A rule of your own still works; it only has to be idempotent.

  **Migration:** one line at the `DwAuthConfig` call site. An app that wants today's behaviour
  passes `DwIdentifierForm.asTyped` — and, having read this far, knows what it is keeping. The
  skeleton and `example/` state `DwIdentifierForm.folded`, so a new project starts on the rule
  rather than remembering to add it.

- **The same address, typed with a capital, no longer signs a person into a second account.**

  The auth identifier was matched byte for byte, so `Ivan@acme.com` found nothing where
  `ivan@acme.com` was stored. No step failed: the lookup honestly reported "unknown", the flow
  honestly resolved the request as a registration, and the person ended up with an empty second
  account — in no team, owning nothing. Nothing was logged, because nothing went wrong.

  `DwAuthConfig.normalizeIdentifier` lets the app state the rule once — `(id) => id.trim()
  .toLowerCase()` for an email app — and DartWay applies it at the edge, to the auth request the
  moment it arrives. Everything downstream reads the identifier off that one field: the profile
  lookup, the per-identifier lock, the rate-limit bucket (two spellings used to be two buckets),
  and the profile a registration builds. `dw.normalizeAuthIdentifier` exposes the same rule to an
  app's own seeds and admin tools, and `getUserProfileByIdentifier` applies it too.

  Switching a rule on over live data is a data migration — rows written in another form stop being
  found, silently, as "no such user". The parameter shipped optional in this same cycle and is
  required by the entry above; within this release there is no "no rule declared" state.

- **A web route no longer answers the caller with whatever the exception happened to say.**

  `DwWebServerLogger.handleWithExceptions` caught everything and wrote `e.toString()` into the
  response body. An arbitrary exception carries what it carries — a database error carries its
  query, a null check carries a file path — and it was written for us, while whoever called a
  webhook is not somebody we authenticated. The `500` looked ordinary from the outside, so nothing
  drew attention to what had been sent with it.

  `DwPublicWebException` makes "safe to show the caller" a type instead of a convention: its
  message and status code go to the caller verbatim, and it raises no alert, because a route
  refusing on its own terms is not an incident. Everything else answers with a fixed sentence and
  `500`; the text lives in the alert and in the `DwWebServerLog` row.

  The decision is `DwWebServerLogger.failureFor`, a function rather than two branches inside a
  `try`, so the security-relevant half can be checked without a server, a session or a socket.

- **A secret inside a list is now hidden in the log row too.** The sanitiser walked nested maps and
  stopped there, so `{"items":[{"token":"…"}]}` was written into `DwWebServerLog` intact — and
  nothing failed, which is the whole difficulty with this class of bug.

- Web routes are documented: `docs/4-server/web-routes.md`. Three of the four things every project
  was rewriting had been in the framework for a while with nothing pointing at them.

## 0.11.0

**New: `DwProxyHttpClient.fromEnv`** — alerts reach Telegram from a host that cannot reach it
directly. Reads `dwTelegramAlertsProxyUrl` (`http://user:pass@host:port`, credentials optional)
from `passwords.yaml` and returns the `http.Client` to hand `DwAlerts.init(httpClient: ...)`. The
key absent, blank or unparseable returns null — no client, direct access, today's behaviour bit for
bit — and says so through the optional `logFunction` rather than failing the boot. See the alerts
entry in `dartway_serverpod_core_shared` for the timeout that ships with it.

**A refusal now says on the wire that it is one.** A rule saying no and a server breaking both
travel in `DwApiResponse.error`, so the client could tell them apart only by comparing the message
against strings it hoped the server still used. It did not, and every ordinary refusal reached the
app's error policy looking like an incident.

- **New: `DwApiResponse.isRefusal`**, and `DwApiResponse.refusal(message)` to build one. Written to
  the JSON only when true, so nothing changes for the responses that are the overwhelming majority
  and an older client — which reads the missing key as "not a refusal" — is right about them.
- Marked as refusals: every rejection by a rule (`validateSave`, `beforeSaveTransaction`,
  `afterSaveTransaction`, `afterSaveTransform`, `validateAction`, `DwActionRejection`),
  `forbidden()` from `allowSave`/`allowDelete`, a delete refused because other rows still reference
  the model, and a save of a row that is already gone.
- **Not** marked: a `DatabaseException`, anything the endpoint's guard caught, `notConfigured` (no
  rule decided anything — the operation does not exist on this server) and `notAuthenticated` (an
  answer, but its text carries a source written for the logs; sending the user to the login screen
  needs a channel of its own).
- `DwDeleteConfig`'s foreign-key refusal now answers with `value: null` rather than `false`. The
  error was always what callers read.

See `dartway_serverpod_core_flutter` for what the other side does with the flag.

## 0.10.0

**A CRUD call that fails now says which model it was about.** `getAll` and `getCount` had no error
handling of their own, so a missing table, a column the schema never grew or a filter naming a field
that does not exist escaped as a bare HTTP 500: nothing reached `DwAlerts`, and the client-side
report read `Failed call: dartway_serverpod_core.dwCrud.getAll` — identical whichever list broke,
while `className` sat right there in the arguments.

- Every method of `DwCrudEndpoint` now runs inside one error boundary. A thrown failure comes back
  as `DwApiResponse(isOk: false)` with the operation and the model in the text — `Unexpected error
  while handling the getAll request for ClubService` — and is reported through `dw.alerts` with the
  exception. `delete` keeps the id of the row it was about.
- **`notConfigured` and `notAuthenticated` are unaffected.** They are answers, not accidents: they
  travel back out unchanged and are not reported.
- The report now carries **the stack of the throw**. `returnError` took a `stackTrace` and then
  reported `StackTrace.current`, so every alert from `saveModel` and `delete` pointed at the handler
  instead of at the code that failed.
- `getOne` reported the raw `ex.toString()` as the alert headline; all five methods now report the
  same way.

**A `DwDtoActionConfig` can now refuse without crashing.** `actionProcessing` had no way to say no
except `throw`, and the endpoint's error boundary treats a throw as an incident: the user read
"Unexpected error while handling the saveModel request", the text the rule was written in was lost
on the way out, and the operator was paged. One production install collected twenty such alerts in
two days, every one of them a rule doing its job.

- **New: `validateAction`** — `Future<String?> Function(Session, DTO)`, run before the transaction
  opens. Return the error text to refuse, or null to let the action through. The same contract as
  `DwSaveConfig.validateSave`.
- **New: `DwActionRejection`** — throw it from inside `actionProcessing`, where there is nothing to
  return the text in and where throwing is the only thing that rolls a Serverpod transaction back.
  The transaction rolls back and the caller is answered with the message.
- Both are **answers**: the text reaches the client verbatim and nothing is reported to `dw.alerts`,
  the way `notConfigured` and `notAuthenticated` already behaved. Any other exception is still a
  failure — wrapped in the guard's message and alerted, unchanged.
- Nothing to migrate: a config that refuses by throwing keeps working exactly as before. It now has
  a way to do it right.

This release also carries the Flutter side's optional local-storage contract for `dw.repo` —
`DwRepoLocalReads` and `DwRepoLocalWrites`, declared on the core as a plugin. Nothing changes for an
app that declares no store. See the changelog of `dartway_serverpod_core_flutter`.

## 0.9.0

**The sign-in response now waits for your SMS or mail provider, and reports it when the provider
says no.** Until now the verification code was sent from a hook nobody awaited: the response was
already built and said `isOk`, so a failed delivery reached neither the user nor the operator. The
screen said "code sent" and no code was sent. If your delivery is flaky, applications that were
quietly succeeding will start showing errors — that is the point of the change, not a side effect
of it, and the failures were always happening.

- **Breaking: `afterSaveTransform` returns `Future<String?>` instead of `Future<void>`.** A non-null
  string rejects the save and becomes the error text in the response, exactly as with `validateSave`
  and `beforeSaveTransaction`. Migration is one line per hook: add `return null;` at the end.

  ```dart
  // before
  afterSaveTransform: (session, ctx) async {
    ctx.currentModel = await enrich(session, ctx.currentModel);
  },

  // after
  afterSaveTransform: (session, ctx) async {
    ctx.currentModel = await enrich(session, ctx.currentModel);
    return null;
  },
  ```

  The analyzer catches every site (`body_might_complete_normally_nullable`), so nothing migrates
  silently.

  **A rejection here does not undo the write** — the transaction committed two steps earlier, so
  the row stays saved and only the response says no. Undoing it would mean deleting a committed
  row to report a failed email, which is worse. Write the hook so that a retry is harmless. A
  rejection does stop what follows: `afterSaveSideEffects` does not run and `broadcastTo` sends
  nothing.

- **The hook's contract is stated honestly now.** It was documented as "enrich the model, outside
  the transaction", which is what sent the verification code to `afterSaveSideEffects`, where it
  could not be heard. It is the place for **any expected work after the write that the caller is
  entitled to hear about** — enrichment, a payment handed to a provider, a code sent. The name is
  unchanged: `docs/DESIGN.md` asks for one way to do a thing, and a second post-commit hook would
  have been the second way.

- **Fixed: a failure in `afterSaveSideEffects` reached nobody.** Its contract is unchanged — still
  not awaited, still unable to fail the save — but a throw is now reported to `DwAlerts` with the
  model's name and the stack trace instead of vanishing into the zone's error handler. Same fix for
  `DwDtoActionConfig.afterSaveSideEffects`, which had the identical hole.

  So the two hooks now differ by audience rather than by timing: what the user must be told goes in
  `afterSaveTransform`, what only the operator needs goes in `afterSaveSideEffects`.

- **The built-in auth request config sends the verification code from `afterSaveTransform`.** A
  delivery failure comes back as "Could not send the verification code. Please try again." while
  the provider's actual complaint — unverified sender domain, expired key, rejected recipient —
  goes to the operator through `DwAlerts`. The two are deliberately separate: the sign-in endpoint
  answers anonymous callers, and the provider's message names the delivery configuration.

  The auth request row survives a failed delivery. That is harmless: the retry issues a fresh code,
  and the abandoned request expires on its own.

## 0.8.0

**`scope=serverOnly` did not hold, in either direction. Worth upgrading now rather than at your
convenience** — the outbound half is a data leak that is live in every application on 0.7.0 and
earlier, and neither half reported anything while it was happening.

- **Fixed: `serverOnly` fields were sent to clients.** Serverpod asks a model for
  `toJsonForProtocol()` — the map without the `serverOnly` fields — for everything it sends a
  client, but only for the objects it reaches by walking the result. The core's own envelopes
  flatten their contents by hand before Serverpod ever sees them, and all three called `toJson()`
  inside: `DwApiResponse` (which additionally did not declare `ProtocolSerialization` at all, so it
  was never asked), `DwModelWrapper`, and `DwAuthData`.

  So every CRUD response, every realtime broadcast and the sign-in response carried the full row.
  **Invisible from the application, which is why it survived:** the generated client class has no
  field for a `serverOnly` column, its `fromJson` drops the key on arrival, and every screen looks
  correct — while the value sits in the response body on the wire.

  What was travelling in this repository's own models: `DwAuthRequest.verificationHash`, and the
  `testVerificationCode` that example and template put on `UserProfile` — a fixed sign-in code, so
  the leak handed over a working login. **Check your own models for `scope=serverOnly` and treat
  anything you find as disclosed to every client that received such a row**; rotate it if it is a
  secret. Serialisation now goes through one place, and a regression test stands on the generator's
  own output.

- **Fixed: a client save blanked `serverOnly` columns.** A `serverOnly` field does not exist on the
  client class, so it is never in the JSON a client sends; the server's `fromJson` read the missing
  key as `null`, and the update wrote the whole row — including the column the client could not have
  said anything about. No error, `isOk` in the response, the value silently gone.

  Such a column is now left out of the `UPDATE` when the incoming value is `null` and the stored row
  has one, so the database keeps what it had. The rule is deliberately narrow: a
  `beforeSaveTransaction` hook that *computes* a `serverOnly` value still writes it normally.

- **Added: `DwSaveConfig.allowServerOnlyOverwrite`**, default `false`. The one case the narrow rule
  costs is a hook that means to clear a `serverOnly` field back to `null`; turn this on for that
  config, and accept that an ordinary client save will then blank the column too.

  Note what the hooks see afterwards: the model is not rebuilt from the database, so from
  `afterSaveTransaction` onwards a `serverOnly` field on `currentModel` still holds what the client
  sent. A hook that needs the stored value reads `saveContext.initialModel`.

## 0.7.0

Two additions, both about server code an application could not write — or could not test — until now.

- **`dw.getUserProfile`, `dw.getUserProfileByIdentifier` and `dw.currentUserProfile` take an optional
  `Transaction`.** Without one the read runs on its own connection, so a CRUD hook that reads the
  caller's profile — `beforeSaveTransaction`, `afterSaveTransaction`, anything inside the save
  transaction — was asking the database a question from outside the transaction it was running in.

  In production that is a second query with a slightly stale answer. Under `serverpod_test` it is
  fatal: with database rollbacks enabled, which is the default, the proxy sees a call arriving
  without the active transaction, treats it as concurrent, and throws `Concurrent database calls
  outside an already active transaction are not supported when database rollbacks are enabled`. So
  **any CRUD config whose hooks read the caller's profile** — nearly every config where the server
  stamps the author itself — could not be driven through `save()` in an integration test at all.
  Found twice, in different configs of different projects.

  Pass `saveContext.transaction` from inside a hook. Purely additive: existing calls keep compiling
  and keep their behaviour. Half of these cases need no query in the first place — when only the
  caller's id is wanted, `session.signedInUserProfileId` is synchronous and free.

- **`dw.db(session)` — generic, model-agnostic database access.** Five operations: `find<T>`,
  `insertRow<T>`, `updateRow<T>`, `deleteRow<T>`, `count<T>`, each taking an optional `Transaction`.

  Serverpod generates a repository per model and gives no repository of a common type, and its
  generic `session.db.find<T>()` / `insertRow<T>` / `updateRow<T>` are marked `@internal` — the core
  has been calling them behind `// ignore_for_file: invalid_use_of_internal_member` in seven files.
  An application with an operation spanning several models (a data migration, a background cleanup,
  an export) had the choice of repeating that ignore or writing a three-line adapter per model whose
  bodies differ only in the model's name. The exposure is now concentrated in one file inside the
  core instead of being copied into every application: when Serverpod changes those methods one file
  needs fixing rather than N applications, and that same file is the seam a replacement for the ORM
  would be fitted into.

  For a single known model keep using that model's own repository — typed, public, and more
  readable. `dw.db` is for the cases where the model is a type parameter.

## 0.6.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.6.0 is the
Flutter side replacing the `ref.watchSignedInUserId` extensions with `dw.signedInUserIdProvider` —
see the changelog of `dartway_serverpod_core_flutter`.

## 0.5.0

- **`sendUpdates` and `sendUpdatesToUser` take `global`, so an update can leave the process that
  sends it.** Default `false` — the right answer while an app is one server process, where the
  clients are connected to the process doing the sending. Pass `true` from somewhere else: a
  background worker in its own container, a future call, a cron job. The message then travels through
  Redis and reaches the clients hanging off the API server.

  Until now the flag was not reachable at all: the extension called Serverpod's `postMessage` without
  it. **A worker calling `sendUpdatesToUser` therefore compiled, threw nothing and delivered to
  nobody** — its own process has no subscribers on that channel, and an audience of zero is not an
  error. A real project found this only by reading Serverpod's own source, and had hand-assembled
  `DwUpdatesTransport` to get at the flag; the workaround was correct and should never have been
  necessary. Its tests did not catch it and could not have: a worker's publisher is injected, so the
  suite checked *who* the recipients were while delivery was a fake, and `redis: enabled: false` in a
  test config looks perfectly ordinary.

  Existing calls are unaffected — the default preserves today's behaviour, and the trap is now
  written down in the doc comment, in `docs/2-core/realtime.md` and in the `dartway-data-layer` skill.

## 0.4.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.4.0 is the
Flutter side gaining `dw.userProfileProvider` / `dw.requireUserProfileProvider` — see the changelog
of `dartway_serverpod_core_flutter`. Nothing in this package changed.

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

**Realtime leaves Serverpod's deprecated streaming endpoint, and revoking a session now reaches the
connections it already holds.**

`DwRealTimeEndpoint` is deleted rather than ported. It ran on `streamOpened(StreamingSession)` — the
lifecycle Serverpod deprecated — and subscribed each connection to the signed-in user's channel from
the server side. That channel now travels on the method stream that already carried every other one,
`dwCrud.subscribeOnUpdates`: the client asks for `userUpdates<id>` by name, and the `owner`
declaration hands it to nobody else. Deleting the endpoint was only possible because the declarations
landed first — before them, moving the personal channel onto a name the client sends would have
opened it to everyone. `DwCoreConst.userUpdatesChannel(id)` is that name, and both halves build it
from there.

**Revocation is why this could not wait.** A websocket resolves its authentication once, when it
opens, so `revokeAuthKeys` broadcasts Serverpod's revocation message to end what a deleted key alone
cannot. Serverpod acts on that message only for endpoints declaring `requireLogin` or scopes, and the
one CRUD endpoint serving the public catalogue and the private order list alike can declare neither —
so migrating the endpoint would not, on its own, have closed anything. The framework now listens for
the message itself, in every channel stream: the subscription ends with a `DwChannelClosed`, the
client does not reconnect, and the local session ends. A banned user reaches the sign-in screen
instead of a screen that quietly stopped updating.

`DwChannelClosed(channel:, reason:)` is a serializable exception on purpose. Anything else arrives at
the client as an ordinary dropped connection, which it would reconnect its way out of — `notAllowed`
would become a hot retry loop against a channel nobody may listen to, and `authenticationRevoked`
would be indistinguishable from a lift blocking the signal.

**`DwSocketStatus` replaces `StreamingConnectionStatus` on `dw.socketService.statusNotifier`, and
`onStreamingStatusChanged` is now `onSocketStatusChanged`.** Under method streams there is no
connection apart from the subscriptions: Serverpod's client opens the socket with the first stream
and closes it with the last. So the states are the three that can be observed — `idle` (nothing
subscribed, and therefore nothing to be offline about), `connected`, `waitingToRetry` — rather than
four describing a connection that no longer exists. Reconnection moved with it: nothing in Serverpod
retries a method stream, so `DwSocketService` reopens every requested channel five seconds after a
failure, for as long as it takes.

**Breaking, and it will not compile:** `dw.socketService.statusNotifier` changes type, and the
`DwCore` hook is renamed. An indicator built on the old enum is a four-arm switch that becomes a
three-arm one — `disconnected` and `connecting` have no successor, because neither was ever
distinguishable from `waitingToRetry` in practice. `DwSessionService.invalidateSession` is public now,
for the same story: something other than startup can decide a session is over.

**A generated `futureCalls` extension no longer escapes the package.** Serverpod's generator writes
`extension ServerpodFutureCallsGetter on Serverpod` into every project that has a future call of its
own, and the core has had one since it started sweeping orphaned auth keys. Both were exported, so
they collided by construction: a file importing this package's barrel and its own `generated/` failed
with `ambiguous_extension_member_access` — on the app's line, in the app's file, the day the app
wrote its first future call rather than the day it upgraded. The barrel now hides it. Nothing is
lost: the core arms its own jobs through `DwRecurringJobs.startAll`. If an app worked around this
with a `hide` of its own, the workaround can go.

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
