## 0.3.0

Web click-through no longer rests on the app's service worker alone.

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
