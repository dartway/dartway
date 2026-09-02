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

Your app owns who receives a message, when it is enqueued, user consent and
categories, provider credentials, and — this part matters — **authorization**:
who may send a marketing blast, pause the worker, or read metrics. The module
ships no endpoints and nothing routable, so it can never leak an "open to
everyone" default; gating those privileged operations is your app's job, where
the role model lives.

The device half of push — asking for permission, obtaining the token, turning a
tap into a screen — is [`dartway_push_flutter`](../3-flutter/push-notifications.md).

## Wiring it up

Push is not part of `DwCore` — your app constructs and owns a `DwPush`:

```dart
DwPush? dwPush;

void bootPush(Map<String, String> passwords) {
  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured ? DwFcmPushProvider(config: fcmConfig) : null;
  final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(passwords);
  final ruStore = ruStoreConfig.isConfigured
      ? DwRuStorePushProvider(config: ruStoreConfig)
      : null;
  if (fcm == null && ruStore == null) return; // no provider → push stays inert

  dwPush = DwPush(
    config: DwPushConfig(
      recipientResolver: DwDevicePushTokenResolver(isEligible: appConsentCheck),
      transport: DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: ?fcm,
          DwPushProviders.ruStore: ?ruStore,
        },
      ),
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

## Adding the module to a database that already has data

Nothing special is required, and it is worth knowing why, because the shape of a
Serverpod module's `migrations/` folder suggests otherwise. Open
`dartway_push_server/migrations/` and the first migration there creates a whole
schema — `serverpod_log`, `serverpod_migrations`, `dw_auth_key` and the rest,
alongside the `dw_push_*` tables. That is what `serverpod create-migration`
writes for any module: it folds every module the module itself depends on into
`migration.sql` and `definition.sql`, and offers no way to ask it not to. The
core module's first migration has the identical shape.

**Those two files are never applied to anything.** In Serverpod 3.4.11 the
runtime migration manager is constructed with the *project* directory and
migrates exactly one module — the project. A module's chain is read once, by
`serverpod create-migration` running **in your project**, and only
`definition_project.json` of the module's latest version, which lists the eight
tables the module owns and nothing else. Those tables are merged into your
project's target schema, and the difference against your previous migration
becomes an ordinary `CREATE TABLE` step in **your** migration. Adding push to a
five-year-old database is therefore the same three commands as adding a model of
your own:

```bash
serverpod generate
serverpod create-migration
dartway deploy run --env production
```

The deploy's migration step now prints what the container said and fails when it
says the schema did not move ([the CLI page](../5-tooling/cli.md)), so a
collision is visible on the run that caused it rather than days later.

If the `dw_push_*` tables somehow already exist — created by hand, or left behind
by a migration that was rolled back in the repository but not in the database —
the migration will die on `relation "dw_push_delivery" already exists`, and every
later migration stays queued behind it. Do not resolve that by dropping tables:
the supported route is a **repair migration**, which diffs the *live* database
against the target schema instead of replaying history — Serverpod's own answer
to "everything else is already here".

```bash
serverpod create-repair-migration --mode production
# then start the server once with --apply-repair-migration
```

`create-repair-migration` connects to the database named by that mode's
configuration to read what is actually there, so it has to be run from somewhere
that can reach it. The repair lands in `repair-migration/`, is committed like any
other migration, and is applied by a single run carrying
`--apply-repair-migration` — after which the ordinary queue moves again.

## Where the credentials come from

**Short values are passwords; a whole document is a file.** `fcmProjectId`,
`rustorePushProjectId` and `rustorePushServiceToken` are a line each and live in
`passwords.yaml`, delivered with `dartway deploy secret set`. FCM's service
account is a couple of thousand characters of JSON and is not a password key at
all: it goes to the server with `dartway deploy secret put-file`, is named under
`requires.files` in `deploy/config.yaml`, and is read from
`config/fcm-service-account.json` — a relative path that means the same file
locally and inside the container, where the deploy mounts every declared file at
`/app/config/<name>`.

That is not tidiness. A document in `passwords.yaml` is a document in the master
copy of **every** environment's secrets, and it has a silent failure attached:
the value begins with `{`, so unquoted YAML parses it as a flow mapping rather
than as a string, and what reaches the provider is not what was written.

```yaml
# <project>_server/config/passwords.yaml.example
staging:
  # Naming this key is what declares that this environment sends push. The
  # credential itself is a file: `dartway deploy secret put-file
  # fcm-service-account.json`, listed under requires.files in
  # deploy/config.yaml.
  fcmProjectId:
```

## Half-configuration is loud

A provider's project id is its **declaration**. Once it is set, everything else
that provider needs must be there too, or the config constructor throws
`DwPushProviderConfigurationException` and the server does not start — naming
what is missing and where it was looked for. A service account that is not a
JSON object is refused the same way, so a truncated upload or a YAML value that
lost its quotes is caught at boot rather than at the first send.

`isConfigured == false` used to be the answer both to "we do not send push here"
and to "the key never reached this environment". From inside a running server
those are indistinguishable, and the second is normally discovered weeks later
by somebody asking why a notification never arrived. An environment that
genuinely wants no push declares nothing — no project id, no file — and
`isConfigured` is false without anybody being misled.

## The domain seam

Two objects carry your domain into the engine, and for most apps neither is much
code.

`DwPushRecipientResolver.resolve` runs under a per-recipient advisory lock inside
a transaction and returns the targets that are eligible right now.
`DwDevicePushTokenResolver` is the one to use: it reads the module's own token
store, keeps values canonical, deletes the targets a provider rejected, and asks
your app the single question it cannot answer — `isEligible`, which is where
consent, muted categories and deleted accounts live. An empty result is a clean
"skip this one".

`DwPushTransport` sends those targets. `DwPushProviderTransport.routed` sends
each one through the transport that issued it — which the device reported when it
registered — so nothing is guessed. A token from a build too old to report a
provider is probed once, in `probeOrder`, and what the probe found is written
back, so it is probed at most once. A token is dropped only when **every**
configured transport refused the target itself: anything transient keeps it. That
matters more than it sounds, because the alternative is real: FCM answering a
RuStore token with `UNREGISTERED` used to delete a perfectly live registration.

Provider outcomes are a small classified enum, not a raw response body, and raw
tokens or bodies never reach your logs — only a fingerprint.

## Registering a device token

The device sends its token through the module's own CRUD action, so your app
writes no endpoint:

```dart
dw = DwCore.init<UserProfile>(
  dtoConfigurations: [dwPush!.tokenRegistrationConfig()],
  // ...
);
```

Nothing becomes reachable until you declare it. The recipient is taken from the
authenticated session and is not a field on the request, so a caller cannot
register a token against somebody else's account, and the write runs under the
same recipient lock a delivery takes — a token cannot slip in behind an account
deletion already in flight.

A token that turns up under a different recipient is **reassigned** to the caller
by default. A push token identifies an app installation, not a person: hand the
phone over, sign in as somebody else, and the previous owner's notifications
would otherwise keep arriving on a device they no longer hold.

## Enqueue, worker, cleanup

Between a domain event and the queue there is always the same stretch of code:
drop the person who caused the event, drop the ones who muted this, drop the ones
with no device at all, invent a key so a retry does not double-send, decide how
long the message is worth delivering, and cut a large audience into chunks.
`DwPushDispatcher` is that stretch:

```dart
await dwPushDispatcher!.send(
  session,
  recipientIds: recipientIds,
  category: 'chat_reply',
  title: title,
  body: body,
  deduplicationKey: 'chat_reply:$messageId',
  excludeRecipientId: actorId,
);
```

`sendToEveryone(page: ...)` pages through a whole user base with a callback of
yours, keeping one message and one deduplication key for the campaign.

**Where the tap should land travels in `data`, under `dwPushLinkDataKey`.** The
app half reads it back under the same name, and on web the transport hands the
same value to FCM a second time as `webpush.fcm_options.link` — so a tap opens
the right screen even in an app whose service worker never got a
`notificationclick` handler. It is an in-app path (`/chats/12`), not a URL; the
browser resolves it against the app's own origin.

```dart
data: {dwPushLinkDataKey: '/chats/$channelId'},
```

Underneath, enqueue is idempotent on a stable `deduplicationKey`, enforced by a
unique index as the last guard, so triggering the same logical campaign twice
does not double-send:

```dart
await dwPush!.queue.enqueue(
  session,
  message: DwPushMessageInput(
    deduplicationKey: stableKey,
    category: category,
    title: title,
    body: body,
    scheduledAt: now,
    expiresAt: expiresAt,
  ),
  recipientIds: recipientIds,
);
```

Your app schedules the worker with [`DwRecurringFutureCall`](recurring-jobs.md)
and calls `dwPush!.processBatch(session)` and `dwPush!.cleanup(session)`. Several
instances can run at once safely.

**A job that drains in a loop passes its budget in**, as `processBatch(session,
deadline: ...)`. Without it a pass runs to the end of its claimed batch however
long the provider takes, and a loop that checks its own clock between passes is
measuring the wrong thing — the pass it is inside of is the one that overran. A
production app watched its 20-second drain budget produce 55-to-77-second runs
exactly this way. Given a deadline the batch stops between concurrency chunks
and hands the deliveries it did not reach back to the queue **unleased**, so the
next pass takes them immediately instead of waiting out `leaseDuration`:

```dart
final deadline = DateTime.now().add(const Duration(seconds: 20));
while (DateTime.now().isBefore(deadline)) {
  final result = await dwPush!.processBatch(session, deadline: deadline);
  if (result.claimed == 0) break;
}
```

`DwPushBatchResult.claimed` counts what the pass processed, so that loop ends on
an empty queue rather than on a batch the deadline cut short.

Delivery is **at-least-once**: a crash right
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

## Device tokens and stale cancellation

Two pieces of plumbing every push app needs ship with the module, so you don't
rebuild them. `DwDevicePushToken` plus `DwDevicePushTokenStore` and
`DwDevicePushTokenPolicy` keep device tokens canonical (whitespace-normalized,
deduped), bounded (a per-recipient cap with newest-first eviction), routed (each
row remembers the transport that issued it) and usable (filter out recipients
with no valid token before you enqueue). And when a
message is queued "about" something that can vanish — a post deleted before its
notification goes out — `dwPush.linkMessageSources(...)` records the link and
`dwPush.cancelMessagesBySources(...)` cancels the message when the source is
gone, so an immutable payload never ships stale.

## See also

- [Push on the device](../3-flutter/push-notifications.md) — the app half:
  permissions, the token, and what happens between a tap and a screen.
- [Advisory locks](advisory-locks.md) — the non-blocking primitive the delivery
  and account-deletion guards are built on.
- [Recurring jobs](recurring-jobs.md) — how to schedule the worker.
