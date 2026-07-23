---
name: dartway-push-delivery
description: >-
  Server-side push delivery in DartWay via the optional dartway_push_server
  Serverpod module: DwPush engine, DwPushConfig with recipientResolver +
  transport, built-in FCM/RuStore providers, idempotent enqueue, worker/cleanup,
  retries, account-deletion lock, campaign progress. Use when adding or
  reviewing push notifications in a DartWay Serverpod app. The module is opt-in —
  an app that does not depend on it has no push tables.
---

# DartWay — push delivery (module)

Push lives in a **separate, optional** Serverpod module `dartway_push_server`,
not in the core. An app that needs push adds the dependency; an app that does
not depend on it gets none of the `dw_push_*` tables. The engine owns the
reliable machinery (queue, worker, lease/retry/cleanup, providers); the app owns
everything domain-specific.

## Responsibility boundary

The module owns: one stored message payload, compact membership rows per
recipient, short pending delivery rows, the worker (claim/lease/retry/cleanup),
provider transport, metrics. It ships built-in `DwFcmPushProvider` and
`DwRuStorePushProvider`.

The app owns:

- audience selection and enqueue timing;
- the user model and the account-deletion path;
- device tokens and their lifecycle;
- user preferences, consent and categories;
- provider credentials;
- **authorization** — who may send marketing, pause/resume, or read metrics.

Never add domain names (courses, chats, posts), product enums, or FK to the
app's user table into the module.

## Wiring

Add the module dependency, then construct a `DwPush` the app **owns** (it is not
part of `DwCore` — push is an independent module):

```dart
DwPush? dwPush;

void initDartwayCore({required Map<String, String> passwords}) {
  dw = DwCore.init<UserProfile>(/* ... */);

  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured ? DwFcmPushProvider(config: fcmConfig) : null;
  final ruStore = ruStoreConfig.isConfigured
      ? DwRuStorePushProvider(config: ruStoreConfig)
      : null;
  if (fcm == null && ruStore == null) {
    dwPush = null; // no provider configured → push inert
    return;
  }

  dwPush = DwPush(
    config: DwPushConfig(
      recipientResolver: AppPushRecipientResolver(),
      transport: DwPushProviderTransport(
        provider: fcm ?? ruStore!,
        fallbackProvider: fcm == null ? null : ruStore,
      ),
    ),
  );
}
```

Default password keys are `fcmProjectId`, `fcmServiceAccountJson`,
`rustorePushProjectId`, `rustorePushServiceToken`; override them in
`fromPasswords`. Secrets stay in the app and never reach the queue or logs.
Include only providers whose `isConfigured == true`; if none are, keep `dwPush`
null. Icons and colours are the app's choice — pass optional `webpushIcon`,
`androidIcon`, `androidColor` explicitly.

`DwPushConfig` is deliberately small: `recipientResolver` and `transport` are the
whole surface most apps write. Every tuning knob lives on an optional
`fineTuning: DwPushFineTuning(...)` where each field documents what it affects
(throughput, recovery, storage). Reach for it only under a real load profile —
most notably `maxConcurrentDeliveries`, which bounds parallel sends and, because
each in-flight send holds a DB connection, must stay a small fraction of the
Postgres pool.

## Config seam

`DwPushRecipientResolver.resolve` is called under a recipient advisory lock and
inside a transaction. Check account deletion, consent and disabled categories
there and return only active tokens. An empty list is a terminal skip. Invalid
targets are removed through `invalidateTargets`.

`DwPushTransport.send` must return exactly one `DwPushTargetResult` per target.
If at least one target is accepted the delivery is done; otherwise a transient
failure may retry. For a different provider or batch/multicast, implement your
own `DwPushTransport`.

Provider outcome is a classified enum, never the raw response. `fallbackProvider`
fires **only** on an explicit `targetNotSupported` (the "not this provider's
token" signal); after timeout, 429/5xx or any other retryable error it does not.
Raw tokens, credentials and provider bodies never reach logs — only a
fingerprint. Built-in providers reject an encoded payload over 4096 bytes before
any HTTP.

If `imageUrl` is not fully built by trusted server code, validate its host
against the app's CDN allowlist before enqueue: the built-in check rejects
local/IP and non-HTTPS URLs, but a public URL is then fetched by the provider.

## Enqueue

```dart
await dwPush!.queue.enqueue(
  session,
  message: DwPushMessageInput(
    deduplicationKey: stableDomainKey,
    category: category,
    title: title,
    body: body,
    data: data,
    scheduledAt: now,
    expiresAt: expiresAt,
  ),
  recipientIds: recipientIds,
);
```

- the deduplication key is stable for one logical message and never reused with
  different content; a UNIQUE index enforces it as the last guard;
- while `audienceClosedAt == null` and the message has not expired, a
  matching-content enqueue may add new recipients even after others succeed;
- only `cancelMessage` / `cancelByDeduplicationKey` close the audience — worker
  outcomes never do;
- `category` is a stable, low-cardinality value (no user/message id);
- never copy the payload onto each recipient; always set a finite `expiresAt`;
- enqueue of a large audience is already chunked safely by the engine.

## Worker and cleanup

The app schedules a recurring job (use `DwRecurringFutureCall`) and calls:

```dart
await dwPush!.processBatch(session);
await dwPush!.cleanup(session);
```

Several instances may run: claim uses `FOR UPDATE SKIP LOCKED` + leases, takes at
most one delivery per recipient per batch, and serialises with `pause` via
runtime state. `attemptCount` is incremented only immediately before a real
provider send, so a reclaimed lease after a crash never burns an attempt.
Delivery is at-least-once — a crash after a provider accepted a message can
cause a duplicate; this is a documented, accepted tradeoff. On its first batch
per process the engine self-applies tightened autovacuum settings to its two
high-churn tables (idempotent `ALTER TABLE`); there is no manual migration
checklist for it.

`pause` stops the worker but not enqueue; a growing queue during a long pause is
an operational incident — monitor depth and retry metrics.

## Account deletion

Run token/delivery/recipient-state removal for a user under the delivery lock:

```dart
await dwPush!.withRecipientLock(
  session,
  recipientId: userId,
  action: (transaction) async {
    await dwPush!.queue.cancelRecipient(session, userId, transaction: transaction);
    await dwPush!.recipientState.clearRecipient(session, userId, transaction: transaction);
    // Delete app-owned tokens and the user in the same transaction.
  },
);
```

After the callback, no earlier delivery can start a new send. `cancelRecipient`
removes both the delivery and the membership row for privacy, so the app's
audience selection must forever exclude the deleted user from enqueue.

## Observability

`dwPush!.campaignProgress(session, messageId: id)` returns `total` / `done` /
`remaining` for one message, computed from two `COUNT(*)`s — cheap to poll for an
admin dashboard, never contends with the worker. It is a snapshot, not a live
per-millisecond gauge (the engine keeps no hot per-message counter by design).

## Reusable helpers (device tokens, source cancellation)

The module ships the generic plumbing so the app does not hand-roll it:

- **Device tokens** — `DwDevicePushToken` (keyed on `recipientId`) plus
  `DwDevicePushTokenPolicy` (normalize/validate/cap/refresh rules) and
  `DwDevicePushTokenStore` (`findByNormalizedValue`, `evictExcessForRecipient`,
  `recipientHasToken`, `filterRecipientsWithTokens`). The resolver returns
  tokens from this store; drop no-token recipients before enqueue with
  `filterRecipientsWithTokens`. Writing/registering tokens (an endpoint) stays
  in the app; keep them canonical via the policy and bounded via eviction.
- **Cancel-on-source-removal** — `dwPush.linkMessageSources(session,
  sourceType:, sourceIds:, messageId:, transaction:)` records that a message was
  enqueued "about" some business sources; `dwPush.cancelMessagesBySources(...)`
  cancels those messages when a source disappears (a post deleted before its
  push is sent), so an immutable payload never goes out stale. `sourceType`/
  `sourceId` are opaque app strings.

## Authorization

The module ships no endpoints and no gating. Marketing sends, `pause`/`resume`
and metric reads are privileged — the **app** must gate them in its own
endpoints, where the role model lives. Do not expose these to any authenticated
user. The module deliberately keeps no "who is admin" concept.

## Checks

- engine imports no domain code (no course/chat/post/lesson);
- resolver returns only eligible active tokens; empty list is a terminal skip;
- RuStore fallback only for `targetNotSupported`; not on timeout/429/5xx;
- raw token/credentials/provider body never logged;
- deduplication key stable and unique; `expiresAt` always set;
- worker scheduled via `DwRecurringFutureCall`; several instances safe;
- account deletion runs under `withRecipientLock`; host excludes the deleted
  user from enqueue forever;
- privileged operations are admin-gated by the app;
- unit-test retry/result and resolver business filters.
