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
