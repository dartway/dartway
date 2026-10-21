## 9. Startup, seeds, settings

`DwAppServer(startup: [...])` and `DwServerFeature(startup: [...])` run after the migrations, before the
port opens — the server's steps first, then each feature's — one transaction per step; a throw stops
the start. `bin/server.dart` does nothing after
`server.start()` but log.

| What | Where |
|---|---|
| rows carried across a schema change | `m.backfill` in that migration (`dartway-migrations`) |
| rows the code declares — a catalogue, a questionnaire | `DwSeedRows` on the feature they belong to |
| one value per app with a default for every field | a settings object |
| anything else true before the first call | a `DwStartupStep`; the first admin is `DwFirstAdministrator` (the skeleton's `account_feature.dart`) |
| development data | `bin/seed_dev.dart`, never in production |

`DwSeedRows('exercise catalogue', table: ExerciseRow.tableDef, key: (t) => [t.slug], rows: …)` inserts a
missing row, overwrites a changed one by its key, and leaves undeclared rows alone — so a seed owns its
rows (rows operators edit are made in the admin panel, with defaults in code), the key is a unique
`NOT NULL` natural key, the rows are constants, a row is retired by a column (`isPublished: false`), and
a seed pointing at another's comes after it. Insert-only defaults that admins may later edit belong
in a project `DwStartupStep` with `tryInsert(… DwOnConflict.doNothing)` on a unique natural key;
`DwSeedRows` would overwrite those edits. A long catalogue lives in a
`<feature>_<part>_rows.dart` of `const` drafts only, which the length check passes over.

**Settings** are a data object of the contract (`dartway-contract`) read and written through
`ctx.settings` — `read<T>()` (the defaults until saved), `update<T>((current) => …)` (locked between
read and write), `save(value)`; no table of the project's. Sample: the skeleton's
`lib/src/settings/settings_handlers.dart`. Only what differs from the defaults is stored: a default
changed in code changes every stored value equal to the old one, and renaming the class resets it. A preference per member stays a column of the member's row.

**A value that belongs to this deployment has no default** — a sender address, a provider key, a
webhook URL: a guessed one points the system at somebody else. Read it with `read.required(…)` so an
unset one stops the start, and list it under `requires.secrets` in `deploy/config.yaml`. (The admin
identifier is optional — unset, the server starts and warns; bucket names have defaults derived from
the project.)

## 10. The environment and other services

`lib/src/core/environment.dart` reads every variable once, at start: `AppEnvironment` holds
`DwServerEnvironment` and one typed sub-config per concern, read by `DwEnvironmentReader` —
`read.required`, `optional`, `integer`, `flag`, `list`, `report` — which throws every problem at once
and never repeats a text value (a number or flag read with `secret: true` neither).
Its doc comment in the skeleton is the sample. `bin/server.dart` reads
`AppEnvironment.read(DwLocalEnvironment.overlay(Platform.environment))` and hands the sub-configs to
the server factory; `bin/` parses nothing itself — no `env['NAME']`.

**Another service's HTTP API is `ctx.http`**: `get`/`post`/`put`/`patch`/`delete`/`send`, `json:` or
`body:`; any status is a `DwOutboundResponse`, no answer throws `DwOutboundException`; bounded by
`DwServerSettings.outboundTimeout` and `outboundMaxResponseBytes`; logged without path, query, headers
or body; `followRedirects: false` when a header carries a credential. Not inside a transaction ([transactions](handlers.md)).
A service class takes `ctx.http` per call — tests replay recorded real answers (`dartway-testing`), nothing is threaded
through the server factory for them. A standalone `bin/` or `tool/` script creates
`DwOutboundHttp.network()` and closes it in `finally`; server code uses its context's client.
The default response cap is 10 MiB including base64/JSON; for image APIs, raise `maxResponseBytes:`
on that call (for example `64 << 20`), accounting for the whole body being held in memory.

Sign-in delivery preferences: pass a project-defined `deliveryHint` on `DwRequestCode` only when
requesting an explicit delivery choice. Allow accepted strings in `DwAuthConfig.allowedDeliveryHints`
and read `ctx.deliveryHint` inside `generateCode` or `deliverCode`; null means the project default.
Unknown hints refuse `dw.invalid` on `deliveryHint`. Every accepted choice requests a new ticket and
shares the same identifier cooldown, request window and idempotency rules. Never implement a separate
anonymous dispatcher or write framework ticket tables to route delivery.

## HTTP ingress quotas

For a public call needing a peer quota, declare its registered type in
`DwServerSettings.callRateLimits` with a `DwCallRateLimit`. The default period is
one minute; `burst` is the number of additional immediate requests. This runs
before body reading and SQL and uses the existing `tooManyRequests` refusal.
State is bounded by `maxPeers` per call and belongs to one process; do not describe
it as a shared quota across replicas. Health, live and in-process calls are exempt.

Wire `trustedProxyNetworks: env.server.trustedProxyNetworks`,
`behindProxy: env.server.httpBehindProxy` and
`deploymentVersion: env.server.deploymentVersion` in the server entry point.
Forwarding headers are trusted only from declared actual CIDRs; the chain is
walked right to left, so a forged client prefix cannot choose the quota key.
A proxy deployment with quotas and no trust declaration fails before migrations.
Native config's `trusted_proxy_networks` supplies `DW_TRUSTED_PROXY_NETWORKS`;
Kamal supplies the full SHA in `KAMAL_VERSION`. Health reports the configured SHA
as a quoted ETag for deployment checks. Never trust every address.

### Identifier confirmation links

Configure `DwAuthConfig.attachDelivery` by kind with `DwIdentifierLinkPolicy` when an identifier
must be confirmed by a link. The policy requires a trusted absolute URL template containing one
`{token}`, a `deliverLink` callback, and fixes replace intent; lifetime defaults to 24 hours. Do not
derive URLs from request headers. Default code delivery and sign-in remain unchanged.
`DwRequestIdentifierCode` returns metadata only; the token goes only to postcommit delivery.
A public landing calls `DwConfirmIdentifierLink`, without switching the browser's session.
All invalid/expired/used/superseded/occupied links refuse existing `DwCoreRefusal.invalid` on `token`.
Only the latest account attach-link request works. Success is single-use, not idempotency-replayed;
response loss can show invalid after a committed change. Publish using the change hook's account.
Prefer web fragment URLs, clear the token before calls/diagnostics, and never log bearer links.

### External commands

Run external commands through `ctx.process.run('git', ['--version'])`, with optional
`workingDirectory`, `environment`, `timeout` and `maxOutputBytes`. It uses no shell expansion,
returns `DwProcessResult` (`exitCode`, `stdout`, `stderr`), and kills an over-limit command.
A nonzero exit is a result; failure to start, timeout and excess output throw
`DwProcessException`. Never hold a database transaction while awaiting an external service.
Direct `Process.run`, `Process.runSync` and `Process.start` in server `lib/` fail
`forbiddenProcessRun`, including tear-offs. Tests use `server.process` and recorded answers;
see `dartway-testing`.
