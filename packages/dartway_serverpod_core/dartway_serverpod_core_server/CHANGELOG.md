# Changelog

## Unreleased

- Added the optional `DwPush` delivery engine with one stored message payload,
  compact durable `dw_push_message_recipient` membership rows, lightweight
  deliveries, idempotent enqueueing, PostgreSQL leases and `SKIP LOCKED`
  claiming, bounded retries and metrics, cleanup, pause controls, recipient
  throttling state and application-owned recipient adapters.
- Added provider-neutral `DwPushProvider` / `DwPushProviderTransport` APIs and
  built-in FCM HTTP v1 and RuStore providers with explicit credential config,
  app-owned presentation overrides, a bounded end-to-end FCM timeout shared by
  OAuth token acquisition and HTTP, compare-and-set-safe recovery from a stuck
  token refresh, safe error classification and FCM-to-RuStore fallback only for
  explicitly unsupported targets.
- Made recipient advisory locking namespaced and non-blocking at the database
  level, and count an attempt only immediately before a provider send starts.
- Serialized pause with claim, limited each batch to one delivery per recipient,
  added exhaustive backfill past busy recipients, sanitized unexpected push
  errors, and rejected oversized provider requests before network I/O.
- Added nullable `DwPushMessage.audienceClosedAt`, written only by whole-message
  cancellation. Claims and delivery success leave unexpired messages open, so
  matching-content enqueue calls may add new recipients after earlier claims or
  completions; content mismatches still throw.
- Inserted unique message-recipient membership before delivery creation. A
  retained membership prevents terminally handled recipients from being
  resurrected, while `existingDeliveries` also reports recipients suppressed by
  existing membership, message cancellation or expiration.
- Added bounded cleanup of at most 10,000 memberships for expired or closed
  messages with no deliveries, exposed the count as
  `DwPushCleanupResult.messageRecipients`, retained message tombstones through
  idempotency retention, and removed delivery plus membership on recipient
  cancellation for privacy; hosts must permanently exclude deleted recipients
  from later enqueue selection.
- Applied custom autovacuum settings to both `dw_push_delivery` and
  `dw_push_message_recipient`; module and generated host migrations must retain
  both statements in `migration.sql` and `definition.sql`.
- Lowered the default `maxConcurrentDeliveries` to 4 and bounded per-delivery
  provider fan-out with positive `maxConcurrentTargets` (default 4).
- Limited resume lifetime extension to each queued message and delivery's
  actual pause overlap, excluding already-expired or wholly future work and
  granting work created during a pause only its remaining overlap.

## 0.1.0

- First public release of the DartWay core Serverpod module: generic
  model-driven CRUD (getOne/getList/save/delete/subscribe) configured per
  model via `DwCrudConfig` (access filters, allowSave/validateSave hooks,
  transactional before/after steps), passwordless phone auth on the app's
  own user model, S3/MinIO cloud storage helpers and Telegram alerts.
