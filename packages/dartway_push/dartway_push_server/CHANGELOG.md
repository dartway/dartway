## 0.3.0

**A worker pass now respects a wall-clock deadline, and stops re-reading one
message per delivery.**

`DwPushWorker.processBatch` (and `DwPush.processBatch`) take an optional
`deadline`. A caller that drains in a loop could only check its budget *between*
passes, and the pass it was inside of was the one that overran it: a batch is
`batchSize` deliveries at `maxConcurrentDeliveries` in flight, each waiting out a
provider round-trip, which is minutes when the provider is slow. Observed on a
production app: a 20-second drain budget producing runs of 55 to 77 seconds. With
a deadline the batch stops between concurrency chunks and hands the deliveries it
did not reach straight back to the queue — unleased, so the next pass can take
them instead of waiting out `leaseDuration`.

The batch also loads its messages in one query and passes them to the deliveries.
A fan-out is thousands of deliveries of the *same* message, and each of them was
re-reading that one row: on the same app, 11 to 13 thousand queries in a single
pass. The row is written once at enqueue and never updated, so reading it once
per batch sees exactly what the per-delivery read saw.

`DwPushBatchResult.claimed` now counts the deliveries the pass actually
processed, not the ones it claimed — the two differ only when a deadline cut the
pass short.

Web click-through no longer rests on the app's service worker alone, and a
provider that was asked for and not finished now says so.

**Breaking.** `DwFcmPushProviderConfig.fromPasswords` no longer takes
`serviceAccountJsonKey`. The service account is read from a **file** —
`DwFcmPushProviderConfig.defaultServiceAccountFile`, that is
`config/fcm-service-account.json`, overridable with `serviceAccountFile:`. An
app that kept the JSON in `passwords.yaml` moves it with
`dartway deploy secret put-file` and names it under `requires.files` in
`deploy/config.yaml`; nothing else in the wiring changes. The plain constructor
still takes the JSON directly, for an app that obtains it some other way.

- **What a project inherits from this module is now pinned by a test.** The
  module's `migrations/` folder looks alarming: its first migration creates a
  whole schema — `serverpod_log`, `dw_auth_key` and the rest — rather than only
  the tables the module owns, which reads like a module that can be installed
  into an empty database and nowhere else. That shape is what
  `serverpod create-migration` writes for any module, the core module included;
  it folds every dependency module into `migration.sql` and `definition.sql` and
  offers no way to ask it not to. Those two files are also never applied to
  anything: Serverpod 3.4.11 builds its migration manager from the *project*
  directory and migrates one module, the project. A module's chain is read once,
  by `create-migration` in the project, and only `definition_project.json` of the
  module's latest version — which is why the tables reach a live database as an
  ordinary `CREATE TABLE` inside the project's own migration.

  So the file that decides the module's effect on somebody's database is that
  one, and it is now asserted to list exactly the eight `dw_*` tables the module
  owns, each attributed to `dartway_push`, with the registry checked against the
  version directories on disk. The bootstrap-shaped SQL is inert; this file
  quietly growing a table the module does not own would not be.

  The push delivery documentation gained a section on adding the module to a
  database that already has data: the three commands it takes, and the repair
  migration that gets a database out of a collision without dropping tables.

- **A service-account JSON is not a password, and steering it into one was our
  doing.** The comment that shipped with push described `fcmServiceAccountJson`
  as "the whole service-account JSON … on one line", and `fromPasswords` was the
  only factory the documentation showed — so a couple of thousand characters of
  JSON went into the master copy of every environment's secrets, with a silent
  failure attached: the value starts with `{`, so unquoted YAML parses it as a
  flow mapping rather than as a string. Meanwhile the CLI already had
  `deploy secret put-file`, whose own help names this case verbatim, and since
  `dartway_cli` 0.8.0 a file named under `requires.files` is genuinely mounted
  into the container. `config/<name>` is now the path, and it resolves to the
  same file locally and in the image.

- **A declared-but-incomplete provider fails at startup instead of going
  quiet.** `isConfigured` returned `false` on any missing field, which is also
  the answer for "this environment sends no push" — so a forgotten key and a
  deliberate decision were indistinguishable from inside a running server, and
  the difference surfaced weeks later as "why did that notification never
  arrive?". The project id is now the **declaration**: once `fcmProjectId` or
  `rustorePushProjectId` is present, everything else that provider needs has to
  be there too, or the config constructor throws the new
  `DwPushProviderConfigurationException` — naming what is missing and where it
  was looked for. A service account that is not a JSON object is refused the
  same way, so a truncated upload or a value that lost its YAML quotes is caught
  at boot rather than at the first send. An environment that wants no push
  declares nothing and is believed.

- **`dwPushLinkDataKey` joins the wire keys.** The in-app path a payload carries
  under `link` is now named on the server as it already was on the app half.
  `DwFcmPushProvider` reads it and sets `webpush.fcm_options.link`, so FCM
  navigates a tap by itself when the app has no `notificationclick` handler of
  its own — or has one that never runs.
- The `webpush` block is no longer skipped for a message that has a link but
  neither an image nor an icon, and its `notification` is emitted only when it
  has something to say rather than as an empty object.
- **The wire keys are pinned on both halves now.** The Flutter side asserted the
  constants rather than the literals, so a rename there broke nothing — which is
  the one thing that test exists to prevent.

## 0.2.0

The half of push that faces the app: a device can now register its token, and
the module knows which transport that token belongs to instead of guessing.

**Breaking.** `DwPushRecipient` and `DwPushDeliveryAttempt.targets` carry
`DwPushTarget` (token + provider) instead of bare strings. A resolver that
returned tokens becomes `DwPushRecipient.tokens([...])`; a custom
`DwPushTransport` reads `target.token`.

- **Targets know their transport.** `DwDevicePushToken` gained a `provider`
  column and `DwPushProviderTransport.routed(providers: {...})` sends each
  target through the transport that issued it. A token of unknown provenance is
  probed once, in `probeOrder`, and what the probe found is reported through
  `DwPushTargetResult.discoveredProvider` and persisted by the resolver
  (`rememberTargetProvider`), so no token is probed twice. The probe treats any
  non-accepting answer as a reason to try the next transport and drops a token
  only when **every** transport refused the target itself — previously an FCM
  `UNREGISTERED` answer to a RuStore token deleted a live registration.
  Identifiers are plain strings (`DwPushProviders.fcm`, `.ruStore`), so an app
  can plug in a transport the module has never heard of.
- **Token registration without an endpoint.** `dwPush.tokenRegistrationConfig()`
  returns a `DwDtoActionConfig<DwPushTokenRegistration>` for the app's
  `dtoConfigurations`; the device calls it through the ordinary CRUD action.
  The recipient comes from the authenticated session and is not a field on the
  request, the write runs under the same recipient lock a delivery takes, and
  nothing is reachable until an app declares the config.
- **`DwDevicePushTokenStore.register` / `unregister` / `setProvider` /
  `targetsForRecipient`** — the registration transaction itself: canonical
  form, an advisory lock on the token so two devices cannot collide on the
  unique index, duplicate collapse, the per-recipient cap and the refresh
  window. A token that turns up under another recipient is reassigned by
  default (`DwDevicePushTokenConflict.reassign`): an installation changes
  hands, and leaving the old owner attached sends their notifications to
  somebody else's phone.
- **`DwDevicePushTokenResolver`** — the resolver most apps want, reading the
  module's own token store and asking the app only `isEligible` (consent, muted
  categories, deleted accounts).
- **`DwPushDispatcher`** — everything between a domain event and `enqueue`:
  drop the actor, drop recipients with no device, apply the app's audience
  filter, invent a deduplication key, pick a per-category lifetime, chunk a
  large audience, and page through "everybody" with an app-supplied callback.

## 0.1.0

Initial release of the DartWay push delivery module — a standalone Serverpod
module extracted from application code so any DartWay app can reuse one reliable
push pipeline instead of hand-rolling the same queue, retries and races.

- **Compact delivery engine.** A durable queue over six `dw_push_*` tables: one
  message payload, compact membership rows per recipient, and short pending
  delivery rows. Worker claims batches with `FOR UPDATE ... SKIP LOCKED`, leases
  them, retries transient failures with backoff, deduplicates by a stable key,
  and reclaims crashed-worker leases. Terminal deliveries are deleted; hourly
  metric buckets and a periodic `cleanup()` keep storage bounded.
- **Built-in providers.** `DwFcmPushProvider` (FCM HTTP v1) and
  `DwRuStorePushProvider`, both pure Dart. Provider outcomes are a classified
  enum, never a raw response; RuStore fallback fires only on an explicit
  "not this provider's token" signal, never on timeout/429/5xx. Raw tokens and
  response bodies are never logged — only a fingerprint.
- **Thin domain seam.** The app supplies a `DwPushRecipientResolver` (its own
  device tokens, consent and eligibility) and a `DwPushTransport`
  (`DwPushProviderTransport` by default). The engine knows nothing about the
  app's domain.
- **Device-token store** (`DwDevicePushToken` + `DwDevicePushTokenPolicy` +
  `DwDevicePushTokenStore`) — the generic token plumbing every push app needs:
  canonical-whitespace normalization, byte-length validation, a per-recipient
  cap with newest-N eviction, refresh windows, canonical-token dedup lookup, and
  "has a usable token" filtering to skip enqueue for no-token recipients. Keyed
  on an opaque `recipientId`, no app types.
- **Source-linked cancellation** (`DwPushSourceLink` +
  `linkMessageSources(...)` / `cancelMessagesBySources(...)`) — map arbitrary
  business `(sourceType, sourceId)` values to a queued message, then cancel the
  message when a source disappears (e.g. a post deleted before its notification
  is sent), so an immutable payload never goes out stale.
- **Small public surface.** `DwPushConfig(recipientResolver, transport)` is all
  most apps write; every tuning knob lives on an optional `DwPushFineTuning`
  with per-field documentation of what it affects.
- **`campaignProgress(messageId)`** — delivery progress (`total` / `done` /
  `remaining`) computed on demand from two `COUNT(*)`s, so reading it never
  contends with the worker.
- **Self-applied storage settings.** The two high-churn tables get tightened
  autovacuum settings via an idempotent `ALTER TABLE` run once per process at
  worker start — no manual migration checklist.
- **Account deletion.** `withRecipientLock(...)` runs destructive per-recipient
  cleanup under the same advisory lock used before a provider send, so deletion
  cannot race an in-flight delivery.

Authorization for privileged operations (marketing sends, pause/resume, reading
metrics) is intentionally left to the app, which owns its endpoints and role
model; the module ships no gating and no "open to all" default.
