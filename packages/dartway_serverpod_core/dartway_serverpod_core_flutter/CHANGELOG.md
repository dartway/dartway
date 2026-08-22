# Changelog

## 0.11.0

**A server refusal is no longer an exception like any other.** `processApiResponse` turned every
`error` into `throw Exception(...)`, so a rule saying no arrived at the app indistinguishable from a
crash: the alert channel filled with ordinary refusals, and telling them apart meant matching the
message against strings.

- A response carrying `isRefusal` is now answered with **`DwRefusal`** (from `dartway_flutter`),
  which holds the text the rule was written in. Everything else still throws the same `Exception` it
  did.
- **The framework's own error policy no longer alerts a refusal.** `DwCore.dispatchReport` steps
  over it the way it already steps over connection blips. An app that installed its own
  `DwConfig.onErrorReport` still receives it and decides for itself — one type check,
  `if (report.error is DwRefusal) return;`, instead of a list of message prefixes.
- `dw.action` shows the refusal's own words to the user instead of the action's generic
  `onErrorNotification` — see `dartway_flutter` 0.7.0.

**What changes for an app that does nothing:** refusals stop arriving in the alert channel, and the
user reads the rule's text rather than a generic error. An app whose `onErrorReport` filtered
refusals by matching message strings can delete that code.

## 0.10.0

**Everything `dw.repo` sends to the server now goes through one narrow port, `DwServerTransport`,
and a test can hand the core its own.** Eight operations — `getOne`, `getAll`, `getCount`,
`saveModel`, `delete`, `subscribeOnUpdates`, `getUploadDescription`, `verifyUpload` — are the whole
dependency the client-side repository has on the generated Serverpod client, and they are now stated
as a type instead of being reached for through `dw.endpointCaller`.

Two things this buys, in the order they matter:

- **A widget test can watch a feature write.** `package:dartway_serverpod_core_flutter/testing.dart`
  ships `DwRecordingServerTransport`: it answers reads from what the test prepared, keeps every save
  and delete that left, and throws `DwUnpreparedServerCall` — naming the call and the field that
  would answer it — for a read nobody prepared. What it replaces is a subclass of
  `ServerpodClientShared` implementing `callServerEndpoint(endpoint, method, args)` against
  string-keyed wire arguments; the four such props inside this package came to ~150 lines and are
  gone. A save that needs no particular answer needs no setup at all — the default echoes the model
  back, because the assertion is about what *left*. **An application hands it its own generated
  `Protocol()`** as `serializationManager`; a model it cannot name is refused rather than sent under
  a name no server knows, because falling back to `runtimeType` would be silently wrong for every
  generated model (they are abstract classes, so it reads `_NewsPostImpl`).
- **Serverpod is replaceable.** `DwServerpodTransport` is now the only place in the Flutter half that
  knows a generated `Caller` exists.

The local store is still not this seam and is still documented as not being one: a write always
leaves by the transport first, and `dw.repo.localWrites` is reached only after the connection
refuses it.

**Breaking: `dw.endpointCaller` is gone; the replacement is `dw.serverTransport`.** An app that
called DartWay's own CRUD endpoints directly — in practice, only a dev stand deliberately failing a
call — renames `dw.endpointCaller.dwCrud.getOne(...)` to `dw.serverTransport.getOne(...)` and
`dw.endpointCaller.dwUpload.verifyUpload(...)` to `dw.serverTransport.verifyUpload(...)`. Everything
reached through `dw.repo`, `dw.client` and `DwFileUploadHandler` is unchanged.

**`DwCore`'s `client` is now optional, and `transport:` takes its place.** An application passes
`client:` exactly as before and nothing about it changes — `dw.client` is still non-nullable, so no
call site grows a `!`. A test passes `transport:` *instead*, and then nothing in the process stands
up a Serverpod client merely so a widget can render. A core built with neither is refused with an
`ArgumentError` naming both options, and refused before the ambient `dw` is claimed, so a
misconfigured core cannot be left registered as the one and only. Reaching `dw.client` on a
transport-only core throws and says how the core was built.

**The two "not initialized" errors now name the missing step.** `DwCore is not initialized` and
`Dw is not initialized` used to be bare; they now point at the core the app failed to build, and say
that a widget test needs one too — a feature reaches `dw` while *building*, not on the tap. Their
"already initialized" counterparts say why an app's initializer has to be idempotent.

**`dw.repo` can keep a local copy of its reads and writes, and the contract for doing so is new
public API.** Two optional boundaries — `DwRepoLocalReads` and `DwRepoLocalWrites` — let a store
outside the core keep repository responses and queue mutations that failed on the connection.
Nothing changes for an app that declares no store: every read and write is network-only, exactly as
before, and the defaults say so (`DwRepoReadStrategy.networkOnly`, a `null` store).

Declared with the core rather than assigned to it:

```dart
dw = DwCore(
  config: ..., client: ..., dwAlerts: ..., getUserId: ...,
  plugins: [DwOfflinePlugin(config: offlineConfig)],
);
```

There is no setter. A store assigned after startup outlives the core it was attached to, and the
failure is quiet — everything keeps working, the writes simply go somewhere that belongs to nobody.

The dangerous half of both contracts is held by the shape of the call: the store opens a
transaction (`write<R>` for writes, `keep<R>` for reads) and the core writes the binding check and
the commit inside it, so an implementation cannot separate them. Getting that wrong costs
differently on each side — a write committed after a sign-out is replayed on the server as somebody
else, a read committed after one outlives the purge meant to remove it — but the shape is the same
and so is the fix. What a signature still cannot state — that the transaction is real, that the
check reads inside it — is held by two suites the core now ships in
`package:dartway_serverpod_core_flutter/testing.dart`, which every store is expected to run.

Also new: `DwRepoQueryKey` (the stable identity of a read), `DwRepoScope` / `DwRepoBinding` (an
opaque, revocable capability the application gives meaning to — the core never derives a user
identity itself), `DwRepoMutation`, `DwRepoWritePlan`, and `readStrategy` on the list and single
configs. Note the asymmetry, because reading it as one paired switch is the natural mistake: a read
opts in at its config, a write opts in inside the store, per operation and model.

A store keeps writes; it does not send them. The core sends every write by its one path, whether or
not it is kept locally, and hands the store the mutation it sent — so a replay is that same
mutation rather than a new one. That identity stops at the device: the mutation's idempotency key
is not carried by the CRUD endpoints, so a server that accepted the first attempt and lost the
response cannot tell a replay is a repeat. Deduplicating that is the application's job today —
[issue #105](https://github.com/dartway/dartway/issues/105).

`isStreamingConnectionError` is now load-bearing for data, not only for logging: it is the single
condition under which a write falls back to local storage, which keeps a rejected authorization out
of the outbox. Widening it changes where data goes.

## 0.9.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.9.0 is the
server side making a failed side effect audible: `afterSaveTransform` is now `Future<String?>` and
can reject a save (breaking, one `return null;` per hook), a throw in `afterSaveSideEffects` is
reported to `DwAlerts` instead of vanishing, and a verification code that could not be sent comes
back as an error rather than a silent success. See the changelog of `dartway_serverpod_core_server`.

## 0.8.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.8.0 is the
server side making `scope=serverOnly` hold in both directions — such a field was being sent to
clients, and a client save was blanking it. See the changelog of `dartway_serverpod_core_server`;
if your models use `scope=serverOnly`, read it.

## 0.7.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.7.0 is the
server side gaining a `Transaction` parameter on the profile reads and the generic `dw.db(session)`
facade — see the changelog of `dartway_serverpod_core_server`.

## 0.6.0

**Breaking: the `ref.watchSignedInUserId` / `ref.readSignedInUserId` extensions are gone, replaced by
`dw.signedInUserIdProvider`.**

```dart
ref.watchSignedInUserId  ->  ref.watch(dw.signedInUserIdProvider)
ref.readSignedInUserId   ->  ref.read(dw.signedInUserIdProvider)
```

They dated from before there was a `dw` to hang anything on, and they carried the cost of that: both
getters read `dw.sessionProvider!`, and `sessionProvider` is legitimately `null` when the app runs
without a `DwAuthenticationKeyManager`. Such an app got a null check operator error out of a package
it does not own — for a state the core already treats as ordinary, the same one `dw.userProfileProvider`
answers with `null` (see 0.4.0). The new provider answers `null` there too.

Form, as much as the crash: the profile is read through providers on the core instance
(`dw.userProfileProvider`, `dw.requireUserProfileProvider`) while the id went through an extension on
`Ref` — two ways to reach neighbouring facts about one session. There is one way now, and being a
provider it composes: `.select`, `ProviderContainer` in a test, an override in a scope.

## 0.5.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.5.0 is the
server side gaining a `global` flag on `sendUpdates` / `sendUpdatesToUser` — see the changelog of
`dartway_serverpod_core_server`.

## 0.4.0

**The signed-in profile is a framework provider now: `dw.userProfileProvider` and
`dw.requireUserProfileProvider`.** The core knew the signed-in id (`watchSignedInUserId`) but stopped
short of the profile itself, so every project wrote the same derived provider over
`sessionProvider` — with the same null-guard for the case where the app runs without an auth key
manager, and the same `!` at each reading. It never needed to be the project's: `DwCore` is generic
over the profile model, so a provider declared on it comes out typed as the app's own `UserProfile`.

The pair splits the way `maybeModel` and `model` do. `userProfileProvider` returns `UserProfile?` —
signed out is a legal answer for a splash, a router guard, the auth zone. `requireUserProfileProvider`
returns a non-nullable profile and throws a `StateError` naming `DwUserAsyncScope` when nobody is
signed in, because under an authenticated subtree that is a wiring mistake, not a state to render.
Being non-nullable it also makes `.select` usable — `requireUserProfileProvider.select((p) => p.name)`
rebuilds on one field, which a `UserProfile?` provider cannot express.

Nothing breaks: a project's own provider keeps working. What `dartway create` scaffolds shrinks to
the two getters `ref.watchUserProfile` / `ref.readUserProfile` over the framework provider — they
stay in the project because Dart has no generic getters, and an extension on `Ref` inside the package
cannot name your profile model.

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

Moves to `dartway_flutter` 0.2.0, whose `DwFeatureSpec` dropped `description` for the
fields that carry a feature's actual behaviour. Nothing in this package uses the spec —
the bump is here so an app can hold both packages at once.

## 0.2.2

- **A cached profile no longer signs a user in on its own.** On startup the
  session was restored from the local cache first and validated afterwards — and
  the validation had no way to fail: the profile fetch returned `void` and its
  result reached the session only through a repository update. When the stored
  key had expired, or the user was gone from the database, the server answered
  with an empty `DwApiResponse` rather than an error (the internal profile config
  filters by the authenticated user, so an unauthenticated request simply matches
  no row). Nothing arrived, nothing was cleared, and the app kept running as the
  previous user — across databases, too.

  `DwSessionService` now treats the cached profile as a claim and lets the server
  decide: `fetchUserProfile` returns the confirmed profile (or `null`), and an
  empty answer clears the stored key together with the cached profile, leaving
  every listener signed out. The same request that loads the profile is the
  session check — a profile comes back only while the key is valid *and* still
  belongs to that user, so a key pointing at someone else is dropped as well.

  Offline behaviour is unchanged: a connection-level failure is not an answer, so
  a cached profile still starts the app and refreshes once connectivity returns.
  Startup latency is unchanged too — `initDwCore` already awaited this request.

  Sign-out stays silent by design: the framework drops the session and the app
  routes to its auth screen. Telling the user *why* is a product decision and
  belongs to the app, not to the core.

## 0.2.1

Released in lockstep with the rest of `dartway_serverpod_core_*`; the change is on
the server side (`broadcastTo` on the CRUD configs, `session.sendUpdates`).
No changes to this package: the app side already routes whatever arrives on a
subscribed channel into `dw.repo` lists.

## 0.2.0

- **Channel subscriptions survive a reconnect.** A channel stream dies with the
  connection that carried it, and nothing reopened it: `subscribeToChannel` returned
  early while the socket was down and the dead entry was simply dropped, so after a
  network blip realtime went quiet for the rest of the session with nothing in the
  logs to say so. `DwSocketService` now keeps what the app asked to follow apart from
  the streams that carry it (`DwChannelSubscriptions`) and reopens every requested
  channel on each connect. Same public methods; `subscribeToChannel` may now be called
  while offline — the channel opens as soon as the connection is back.
  `DwChannelSubscriptionWidget` no longer resubscribes on connection status itself,
  which also removes a race where a reconnect could land on a not-yet-dropped dead
  subscription and skip reopening it for good.
- **The streaming reconnect delay is back to Serverpod's own default of 5 seconds**,
  from the 1 second `DwSocketService` used to pass. The handler retries on a fixed
  interval with no backoff, so on an unstable network a one-second delay turned every
  outage into a reconnect storm — and each attempt opens a fresh server-side session
  with its own socket and log buffer. Deliberately not exposed as a parameter: no app
  has a reason to prefer one value over the other, and the retry loop belongs to the
  deprecated streaming API that is on its way out.

**`dw.repo` — one client-side data-access point.** Reads are Riverpod providers consumed natively —
`ref.watch(dw.repo.model<T>(...))` (reactive), `ref.read(...future)` (one-shot),
`ref.refresh(...future)` (force). Writes and realtime are plain methods: `dw.repo.saveModel/deleteModel`,
`dw.repo.addUpdatesListener/removeUpdatesListener`; default-model registration moved here too
(`dw.repo.setupRepository/mockModelId/getDefault`).

- `dw.repo.model<T>(...)` resolves to a non-null `T` (StateError when absent); `maybeModel<T>` is the
  nullable view; `modelList<T>` is the backend-filtered list. No app code names a provider type or
  touches `.notifier` — the whole Riverpod surface an app uses is `ref.watch/read/refresh(dw.repo.<x>)`.
- Local (frontend) list filtering is no longer a framework feature — do it with a plain `.where` in the
  widget; `backendFilter` still narrows the query server-side.
- Added alongside the existing `DwRepository` statics and `ref.watchModel*` extensions (additive); those
  are being migrated away and will be removed once call sites move to `dw.repo`.

## 0.1.0

First public release — the Flutter half of the DartWay core.

**A typed realtime data layer.** `ref.watchModelList<T>()` returns a live `AsyncValue<List<T>>`:
realtime sync, pagination, declarative backend filters and skeleton loading states out of the box.
`ref.watchModel` / `ref.readModel` read a single one; `DwRepository.saveModel` /
`DwRepository.deleteModel` write. No repositories, no services, no sockets, no cache invalidation.

**Sessions** on the app's own user model, surviving restarts through the authentication key manager.

**Connection-aware error handling.** A network blip becomes a toast, a real failure becomes a
report — `dwReportingOnFailedCall` and the streaming error classifier tell them apart, so a subway
tunnel does not page you at 3am.

**Context-rich alerting, zero-config.** Every error carries the app's state at the moment it broke:
the route, the features mounted on the screen, the action the user tapped or the `endpoint.method`
that failed, the platform, the app version and the user — instead of a minified web stack trace.

Re-exports [`dartway_flutter`](https://pub.dev/packages/dartway_flutter), so one import covers the
standard app surface.
