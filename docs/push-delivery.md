# Push delivery

Sending one notification to one device is a single HTTP call. Sending to fifteen
thousand people when a post goes live is not: some devices are offline, the
provider rate-limits you, a worker crashes mid-run, the same campaign gets
triggered twice, and someone deletes their account while a send to them is in
flight. The hard part of push is never the send — it is the queue, the retries
and the races around it.

DartWay puts that hard part in one place: the **`dartway_push_server`** Serverpod
module. It is **optional** — an app that needs push adds the dependency; an app
that does not gets none of the `dw_push_*` tables. The module owns the reliable
machinery; your app owns everything that is specific to your domain.

## What each side owns

The module owns a durable queue (one stored message, compact membership rows per
recipient, short pending delivery rows), a worker that claims work with
`FOR UPDATE ... SKIP LOCKED` and leases it, backoff retries, deduplication,
lease recovery after a crash, hourly metric buckets, bounded cleanup, and two
built-in providers — `DwFcmPushProvider` (FCM HTTP v1) and
`DwRuStorePushProvider`, both pure Dart.

Your app owns who receives a message, when it is enqueued, the device tokens and
their lifecycle, user consent and categories, provider credentials, and — this
part matters — **authorization**: who may send a marketing blast, pause the
worker, or read metrics. The module ships no endpoints and no gating, so it can
never leak an "open to everyone" default; gating those privileged operations is
your app's job, where the role model lives.

## Wiring it up

Push is not part of `DwCore` — your app constructs and owns a `DwPush`:

```dart
DwPush? dwPush;

void bootPush(Map<String, String> passwords) {
  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured ? DwFcmPushProvider(config: fcmConfig) : null;
  if (fcm == null) return; // no provider configured → push stays inert

  dwPush = DwPush(
    config: DwPushConfig(
      recipientResolver: AppPushRecipientResolver(),
      transport: DwPushProviderTransport(provider: fcm),
    ),
  );
}
```

`DwPushConfig` is deliberately small. `recipientResolver` and `transport` are the
whole surface most apps ever write. Every performance and retention knob lives on
an optional `fineTuning: DwPushFineTuning(...)`, where each field documents what
it trades off — so the constructor stays readable and you are never staring at a
dozen numbers you don't understand. The one knob worth knowing is
`maxConcurrentDeliveries`: each in-flight send holds a database connection for
the whole provider round-trip, so keep it a small fraction of your Postgres pool.

## The domain seam

Two objects carry your domain into the engine.

`DwPushRecipientResolver.resolve` runs under a per-recipient advisory lock inside
a transaction. Given a recipient id, return the active device tokens that are
eligible right now — after checking consent, disabled categories and account
deletion. An empty list is a clean "skip this one". Tokens the provider rejects
are removed through `invalidateTargets`.

`DwPushTransport` sends resolved targets. The default `DwPushProviderTransport`
wraps one or two providers; give it a `fallbackProvider` and it falls back
**only** on an explicit "this isn't my kind of token" signal — never after a
timeout, a 429 or a 5xx, which are retried instead. Provider outcomes are a
small classified enum, not a raw response body, and raw tokens or bodies never
reach your logs — only a fingerprint.

## Enqueue, worker, cleanup

Enqueue is idempotent on a stable `deduplicationKey`, enforced by a unique index
as the last guard, so triggering the same logical campaign twice does not
double-send:

```dart
await dwPush!.queue.enqueue(
  session,
  message: DwPushMessageInput(
    deduplicationKey: stableKey,
    category: category,
    title: title,
    body: body,
    expiresAt: expiresAt,
  ),
  recipientIds: recipientIds,
);
```

Your app schedules the worker with [`DwRecurringFutureCall`](recurring-jobs.md)
and calls `dwPush!.processBatch(session)` and `dwPush!.cleanup(session)`. Several
instances can run at once safely. Delivery is **at-least-once**: a crash right
after the provider accepted a message can produce a duplicate — a deliberate,
documented tradeoff, since for notifications a rare duplicate beats a silent
drop. The attempt counter only advances on a real send, so recovering a crashed
worker's lease never burns an attempt. On its first batch each process, the
engine self-applies tightened autovacuum settings to its two high-churn tables,
so the dead rows from its delete-as-you-go design are reclaimed under load
without any manual migration step.

## Deleting an account

Removing a user's tokens, deliveries and recipient state races with a send
already in flight — so do it under the same lock the worker takes before a send:

```dart
await dwPush!.withRecipientLock(session, recipientId: userId, action: (tx) async {
  await dwPush!.queue.cancelRecipient(session, userId, transaction: tx);
  await dwPush!.recipientState.clearRecipient(session, userId, transaction: tx);
  // delete app-owned tokens and the user in the same transaction
});
```

After the callback returns, no earlier delivery can begin a new send to that
user, and your audience selection must exclude them from future enqueues for
good.

## Watching a campaign

`dwPush!.campaignProgress(session, messageId: id)` returns `total`, `done` and
`remaining` for a message, computed on demand from two `COUNT(*)`s. It is cheap
enough to poll from an admin dashboard and never contends with the worker,
because the engine keeps no hot per-message counter. It is a few-seconds-fresh
snapshot, not a live millisecond gauge — the right tradeoff for a progress view.

## See also

- [Advisory locks](advisory-locks.md) — the non-blocking primitive the delivery
  and account-deletion guards are built on.
- [Recurring jobs](recurring-jobs.md) — how to schedule the worker.
