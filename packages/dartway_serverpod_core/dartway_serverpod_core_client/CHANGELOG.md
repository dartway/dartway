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
