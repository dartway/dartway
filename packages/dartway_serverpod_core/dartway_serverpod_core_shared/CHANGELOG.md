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

Lockstep release: no changes of its own.

## 0.2.2

Released in lockstep with the rest of `dartway_serverpod_core_*`; the change is in
the Flutter package (a stored session is validated against the server before it
signs anyone in). No changes to this package.

## 0.2.1

Released in lockstep with the rest of `dartway_serverpod_core_*`; the change is on
the server side (`broadcastTo` on the CRUD configs, `session.sendUpdates`).
This package gained `DwCoreConst.publicUpdatesChannel` — a name both halves
can use for "everyone using this app" without a shared package of their own.

## 0.2.0

No changes to this package. The four `dartway_serverpod_core_*` packages are released in lockstep —
one version across all four — so that an app never has to reason about which combination of them is
co-installable.

## 0.1.0

First public release — the pure-Dart layer both halves of the DartWay core share, so that the server
and the Flutter app format an alert and name a config key the same way instead of drifting apart.

- `DwAlerts` — the alert sink, with Telegram delivery. Without a config it degrades to logging, so a
  fresh project stays runnable instead of crashing on a missing token.
- `DwAlertContext` — the app state around a failure (route, features, action, platform, user).
  Messages arrive MarkdownV2-safe, with the stack trimmed to its top frames: the part that says
  where it broke, without the forty lines that say how the framework got there.
- `DwTelegramAlertsConfig` (and `DwTelegramAlertsKeys`, the `passwords.yaml` names it reads).
- `DwCoreConst` — the wire contract: the API and column names the server and the client must spell
  identically, in one place instead of two.

You do not usually depend on this package directly — the server and Flutter core packages both pull
it in.
