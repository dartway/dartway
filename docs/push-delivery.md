# Push delivery

`dartway_serverpod_core_server` provides an optional push delivery engine that
keeps queue storage compact without owning application users, device tokens or
domain rules. It also provides optional server-side FCM and RuStore providers.

## Storage model

| Table | Lifetime | Purpose |
|---|---|---|
| `dw_push_message` | idempotency window | one immutable title, body and data payload per logical message |
| `dw_push_message_recipient` | until an expired or cancelled message drains | one compact durable membership row per message and recipient |
| `dw_push_delivery` | until sent, skipped or terminally failed | one lightweight queue row per recipient |
| `dw_push_metric_bucket` | configured retention | hourly aggregate counters, not per-delivery history |
| `dw_push_recipient_state` | configured retention or account deletion | generic throttle/aggregation state |
| `dw_push_runtime_state` | persistent | pause and worker health state |

The large payload is never copied to every recipient. For each new
`(messageId, recipientId)` pair, DartWay inserts a compact membership row before
it inserts the delivery. The membership has a unique pair index and survives
sent, skipped and terminal delivery deletion, so the same recipient cannot be
resurrected by a later enqueue. New recipients can still join the same open,
unexpired message after earlier recipients were claimed or completed.

This is an intentional storage tradeoff: one message payload plus compact
membership and pending-delivery rows instead of one payload copy per recipient.
Membership rows remain until the message expires or its audience is explicitly
closed and all deliveries have drained. The message then remains as the
idempotency tombstone through the configured retention window.

All models are `serverOnly`. Both `dw_push_delivery.messageId` and
`dw_push_message_recipient.messageId` have a foreign key to `dw_push_message`
with `ON DELETE CASCADE`. Their `recipientId` columns deliberately have no
foreign key: the framework must not depend on the host application's user
model.

### Host migration and autovacuum

`dw_push_delivery` is an intentionally high-churn table: successful, skipped,
expired and terminal deliveries are deleted instead of becoming permanent
history. `dw_push_message_recipient` is also inserted and later removed in
large batches. Both tables require tighter per-table maintenance settings:

```sql
ALTER TABLE "dw_push_delivery" SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 100,
  autovacuum_analyze_scale_factor = 0.02,
  autovacuum_analyze_threshold = 100
);

ALTER TABLE "dw_push_message_recipient" SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 100,
  autovacuum_analyze_scale_factor = 0.02,
  autovacuum_analyze_threshold = 100
);
```

The DartWay module migration **must contain both statements identically** in its
`migration.sql` and `definition.sql`. Every consuming Serverpod application's
generated host migration must do the same. Serverpod copies module tables and
indexes into a host migration, but it does not copy custom SQL added to the
module migration. After `serverpod create-migration`, add each statement after
the corresponding table indexes in both host files: `migration.sql` covers an
upgrade and `definition.sql` covers a clean database bootstrap. Missing or
different statements for either table are a release blocker. These values are
a safe starting point; production monitoring should still alert on dead tuples,
autovacuum lag and sustained queue or membership growth.

## Configure recipient and provider adapters

The application resolves its own active tokens and preferences. DartWay can
send those targets through its built-in FCM provider and fall back to RuStore
only when FCM explicitly classifies a target as unsupported:

```dart
final fcmConfig = DwFcmPushProviderConfig.fromPasswords(
  serverpod.server.passwords,
  // Optional app-owned client asset override.
  webpushIcon: '/icons/push.png',
);
final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(
  serverpod.server.passwords,
  // Optional app-owned Android resource overrides.
  androidIcon: 'ic_notification',
  androidColor: '#000000',
);
final fcm = fcmConfig.isConfigured
    ? DwFcmPushProvider(config: fcmConfig)
    : null;
final ruStore = ruStoreConfig.isConfigured
    ? DwRuStorePushProvider(config: ruStoreConfig)
    : null;
if (fcm == null && ruStore == null) {
  throw StateError('Configure at least one push provider');
}

dw = DwCore.init<UserProfile>(
  // Other DartWay configuration...
  pushConfig: DwPushConfig(
    recipientResolver: AppPushRecipientResolver(),
    transport: DwPushProviderTransport(
      provider: fcm ?? ruStore!,
      fallbackProvider: fcm == null ? null : ruStore,
      maxConcurrentTargets: 4,
      // Optional: remove application-only keys before provider calls.
      dataTransformer: stripInternalPushData,
    ),
    categoryPriorities: {
      'security': DwPushPriority.high,
      'marketing': DwPushPriority.bulk,
    },
  ),
);
```

The default password keys are `fcmProjectId`, `fcmServiceAccountJson`,
`rustorePushProjectId` and `rustorePushServiceToken`. Pass different key names
to `fromPasswords` when an existing application uses another convention. Keep
credentials in Serverpod password configuration; never put them in a message,
delivery row or log. Add only configured providers to the chain: an
unconfigured primary blocks fallback, while an unconfigured fallback hides the
terminal unsupported-target signal. Client icon/color names are application
resources, so core has no hardcoded values; pass the optional presentation
overrides only when the corresponding clients ship those assets.

Treat producers as trusted server code. The built-ins accept only syntactically
public HTTPS image URLs with a supported extension, but FCM/RuStore still fetch
that public URL on the application's behalf. If producers can supply URLs,
allowlist the application's CDN hosts before enqueueing.

`DwPushProviderTransport` retains the generic batch-oriented `DwPushTransport`
extension point. It adapts one-target providers to that contract and catches an
unexpected provider exception as a retryable failure. Per-recipient target
fan-out is bounded by `maxConcurrentTargets` (default 4); the value must be
positive. This limit is independent of worker delivery concurrency, so the
maximum outbound provider-call concurrency scales with both settings. You can
still implement `DwPushTransport` directly for multicast or another provider.
The built-in providers use bounded provider operations, do not log raw tokens
or response bodies, reject encoded requests above the providers' 4096-byte
limit before OAuth/HTTP, and expose injectable HTTP/token boundaries for
deterministic tests. For FCM, one `requestTimeout` deadline starts before OAuth
token acquisition or refresh and covers the subsequent provider HTTP request;
the HTTP stage receives only the remaining budget. Concurrent sends share one
bounded token refresh. An identity-based compare-and-set guard retires a timed
out refresh and prevents an older completion from overwriting or clearing a
newer refresh, so a later send can recover from a stuck OAuth provider. If a
provider reports `targetNotSupported`, the configured fallback gets the target;
if the provider chain ends without support, the target is invalidated instead
of failing every future message again.

`DwPushRecipientResolver.resolve` runs inside a transaction while the
recipient advisory lock is held. Check account status, marketing consent,
disabled categories and current token activity there. Return no targets to
skip the delivery without retaining history.

`DwPushTransport.send` receives a `DwPushDeliveryAttempt`. It must return one
`DwPushTargetResult` for every input target. A successful target completes the
recipient delivery even when another token is invalid; this avoids sending a
duplicate push to the successful device during a retry. Invalid targets are
passed back to `invalidateTargets` after delivery state has safely committed.

For `429`, `5xx` and other transient provider failures, adapters may set
`DwPushTargetResult.retryAfter`. The worker uses the longer of this positive
provider delay and its retry-policy backoff.

The stable `attempt.idempotencyKey` can be forwarded to providers that support
idempotent requests. Delivery is otherwise at-least-once: a process or database
failure immediately after a provider accepted a message can cause a retry.

The canonical example contains safe adapters that resolve no real targets in
`example/dartway_example_server/lib/src/dartway/dartway_core.dart`.

## Enqueue and extend an open audience

```dart
final push = dw.push!;
final now = DateTime.now().toUtc();

await push.queue.enqueue(
  session,
  message: DwPushMessageInput(
    deduplicationKey: 'new-lesson:$lessonId:v1',
    category: 'newLesson',
    title: lesson.title,
    body: 'A new lesson is available',
    data: {'lessonId': '$lessonId'},
    scheduledAt: now,
    expiresAt: now.add(const Duration(days: 1)),
  ),
  recipientIds: audienceUserIds,
);
```

The deduplication key is unique. The first successful enqueue owns the immutable
content, `scheduledAt` and `expiresAt`. A later enqueue validates the same
content before doing anything else; different content still throws instead of
silently changing the logical message. A newly computed clock value does not
move the original delivery window.

`DwPushMessage.audienceClosedAt` is nullable. While it is null and the message
has not expired, matching-content enqueue calls may add recipients that have no
membership yet, including after another recipient was claimed or successfully
delivered. Claim and delivery outcomes never close the audience. DartWay first
inserts the unique `dw_push_message_recipient` membership and creates a delivery
only for newly inserted memberships. A retained membership therefore prevents
the same recipient from being delivered again after its terminal delivery row
has been removed.

`DwPushEnqueueResult.insertedDeliveries` is the number of new deliveries created
by that call. `existingDeliveries` is the number of unique requested recipients
for which no new delivery was created: their membership already existed, or the
message was closed or expired. A closed or expired enqueue returns zero inserted
and the full requested unique count as existing. This field is not a count of
physical delivery rows.

Large audiences are inserted in bounded chunks to stay below PostgreSQL bind
parameter limits. Keep `category` stable and low-cardinality because it becomes
a metric dimension; do not put user or message IDs in it.

Recipient selection is application logic. Select course members, chat members
or a direct user before calling `enqueue`; do not put course or chat concepts
inside DartWay.

Categories not listed in `categoryPriorities` use normal priority. When several
classes are due together, each batch reserves capacity for high, normal and
bulk traffic, while unused capacity is filled from the remaining due rows. This
prevents a promotion backlog from starving transactional notifications without
leaving worker slots idle.

Applications that keep source-to-message links can cancel by `messageId`.
When the stable producer key is sufficient, use
`queue.cancelByDeduplicationKey`; source identifiers themselves remain
application-owned. `cancelMessage` sets `audienceClosedAt` and removes pending
deliveries; `cancelByDeduplicationKey` delegates to that same operation. These
are the only whole-message audience-closing paths. Membership tombstones remain
until bounded cleanup, and future matching-content enqueues are suppressed.

## Run workers and cleanup

Call a batch from an application-owned Serverpod future call or scheduler:

```dart
final result = await dw.push!.processBatch(session);
```

Workers atomically claim due rows with `FOR UPDATE SKIP LOCKED` and attach a
lease. The attempt number increments only after eligibility checks, immediately
before the provider send starts, so lock contention and skipped recipients do
not consume retry attempts. One batch claims at most one due delivery per
recipient, so a hot recipient cannot consume the batch with rows that would
self-contend. Claim also takes the recipient's non-blocking advisory lock while
leasing, preventing different workers or priority lanes from leasing two rows
for that recipient concurrently. Busy recipients are skipped with cursor-based
backfill until the batch is full or no later due row remains, so a locked queue
prefix cannot starve unrelated recipients. Claim and pause serialize on the
runtime-state row: once pause returns, later claims cannot slip through.
Multiple server instances can run the same worker safely. A crashed worker's
rows become available after the lease. Retry delays use bounded exponential
backoff with jitter. Claims and terminal outcomes mutate delivery state only;
they never set `audienceClosedAt` or prevent new recipients from joining an
otherwise open message.

Each in-flight delivery holds a database transaction and one pool connection
through recipient resolution and provider I/O. The default
`maxConcurrentDeliveries` is 4 per batch. Size the database pool with explicit
headroom for claims, cleanup, health checks and application traffic, and account
for every concurrently running batch and server instance; lower delivery
concurrency instead of allowing push work to exhaust the pool.

Schedule cleanup separately and retain its result:

```dart
final cleanup = await dw.push!.cleanup(session);
```

Cleanup processes bounded sets and skips rows currently locked by a worker. It
drops expired deliveries, then deletes at most 10,000 membership rows belonging
to expired or explicitly closed messages only after those messages have no
deliveries. `DwPushCleanupResult.messageRecipients` reports that membership
count. Once deliveries and memberships are gone, the message remains as a
deduplication tombstone until its expiration or audience-close timestamp is
outside `idempotencyRetention`; cleanup can then delete it. Metric and recipient
state retention remain independently bounded.

Include `messageRecipients` in any host "repeat while cleanup removed work"
predicate. Otherwise a drain loop can stop between membership batches and delay
message-tombstone deletion. Run cleanup repeatedly until all returned counts
drain when clearing a backlog.

Operational controls are persistent:

```dart
await dw.push!.pause(session); // indefinite
await dw.push!.pause(session, until: maintenanceEndUtc);
await dw.push!.resume(session);
await dw.push!.resume(session, extendQueuedMessageLifetime: true);
```

Pausing stops claims, not enqueues. Monitor queue depth and the runtime
timestamps; retention cannot protect the database from an indefinitely paused
worker while producers continue to enqueue.

The optional resume flag preserves only the time that queued work actually
overlapped the pause. The interval starts at the original pause timestamp and
ends at the earlier of `pausedUntil` and resume time. For a message that still
has a delivery and was not already expired when the pause began, DartWay shifts
`scheduledAt` and `expiresAt` by the positive interval after the latest of the
message's creation, schedule and pause start. Each delivery's `availableAt` is
shifted independently after the latest of its creation, availability and pause
start. Work created halfway through a pause therefore receives only the
remaining overlap, while work scheduled or made available wholly after the
pause receives no extension. Use this flag when maintenance must not consume
the applicable message TTL. Repeated `pause` calls keep the original pause
start, and repeated `resume` calls do not extend lifetime again.

```dart
final health = await dw.push!.queue.health(session);
```

Alert on `pendingDeliveries` growth and an old `oldestAvailableAt`. Runtime
timestamps are batch-boundary signals, not an in-flight heartbeat, so provider
timeouts must remain strictly bounded.

## Account deletion race

Account deletion must use the same recipient lock as delivery:

```dart
await dw.push!.withRecipientLock(
  session,
  recipientId: userId,
  action: (transaction) async {
    await dw.push!.queue.cancelRecipient(
      session,
      userId,
      transaction: transaction,
    );
    await dw.push!.recipientState.clearRecipient(
      session,
      userId,
      transaction: transaction,
    );
    await deleteApplicationUser(session, userId, transaction);
  },
);
```

Without an existing transaction, `withRecipientLock` retries short,
non-blocking advisory-lock attempts for up to 30 seconds. This lets deletion
wait for an already-started send without leaving a PostgreSQL connection in a
blocked lock wait. Once deletion completes, a previous worker cannot begin
another send for that recipient. Keep all app-owned token deletion and user
deletion inside the same callback. `cancelRecipient` removes both the
recipient's deliveries and message memberships for privacy. Removing membership
also removes the framework's no-resurrection marker, so host audience selection
must permanently exclude a deleted user from future enqueue calls.

When an application hook already runs in a transaction, pass it through the
optional `transaction` argument instead of opening a nested transaction. That
mode makes one non-blocking attempt and throws
`DwAdvisoryLockUnavailableException` on contention, because retrying an
arbitrary already-open transaction is not safe. Retry the outer operation.

## Application-specific aggregation

Aggregation remains above the generic engine. For example, an application can
collect several content events, build one recipient-specific message and use a
bounded throttle window:

```dart
final accepted = await dw.push!.recipientState.tryAcquire(
  session,
  recipientId: userId,
  stateKey: 'contentDigest',
  interval: const Duration(minutes: 15),
);
```

State keys are application-defined. Clear them during account deletion. Do not
store unbounded event history in `metadata`; it is limited to small string maps
for compact coordination state.

## Defaults to review for production

- `batchSize`: 100 claimed deliveries per pass.
- `maxConcurrentDeliveries`: 4 in-flight delivery transactions per batch.
- `DwPushProviderTransport.maxConcurrentTargets`: 4 provider targets per
  delivery at a time; must be greater than zero.
- `enqueueChunkSize`: 1000 recipient rows per insert.
- `leaseDuration`: 2 minutes.
- `idempotencyRetention`: 7 days.
- `metricsRetention`: 90 days.
- `recipientStateRetention`: 90 days.
- membership cleanup: at most 10,000 rows per pass, reported as
  `DwPushCleanupResult.messageRecipients`.
- retry policy: 6 attempts, exponential backoff capped at 1 hour, 20% jitter.

Set the end-to-end provider timeout below `leaseDuration`. Give every producer
a stable deduplication key and a finite expiration. Alert on a growing queue,
stale `lastCompletedAt`, repeated retry counters and cleanup counts that never
fall.
