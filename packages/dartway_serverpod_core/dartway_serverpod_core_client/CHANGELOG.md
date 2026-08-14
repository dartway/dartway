# Changelog

## 0.6.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.6.0 is the
Flutter side replacing the `ref.watchSignedInUserId` extensions with `dw.signedInUserIdProvider` —
see the changelog of `dartway_serverpod_core_flutter`.

## 0.5.0

Version bump only. The four `dartway_serverpod_core_*` packages move in lockstep, and 0.5.0 is the
server side gaining a `global` flag on `sendUpdates` / `sendUpdatesToUser` — see the changelog of
`dartway_serverpod_core_server`.

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
the Flutter package (a stored session is validated against the server before it
signs anyone in). No changes to this package.

## 0.2.1

Released in lockstep with the rest of `dartway_serverpod_core_*`; the change is on
the server side (`broadcastTo` on the CRUD configs, `session.sendUpdates`).
No changes to this package.

## 0.2.0

Regenerated against Serverpod 3.4.11 (from 3.4.8). No hand-written change and no change to the
protocol surface — the version moves because the four `dartway_serverpod_core_*` packages are
released in lockstep and are only ever installed as a set.

## 0.1.0

First public release — the generated Serverpod protocol client of the DartWay core module:
`DwModelWrapper`, `DwApiResponse`, `DwBackendFilter`, `DwAuthFailReason` and the endpoint callers.

You do not write against this package directly. It is a dependency of
[`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter) — that is
the package your app uses.
