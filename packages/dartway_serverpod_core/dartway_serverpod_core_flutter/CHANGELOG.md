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

Also: `DwDeleteConfig.delete` now answers `notConfigured` before it touches the database. Existence
probing by unauthenticated callers is closed by the gate above; a signed-in caller can still tell a
missing row from one they may not delete, which is documented in the code as a remaining decision.

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
