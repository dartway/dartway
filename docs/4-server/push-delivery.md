# Push delivery: how does a notification reach a device exactly once?

**A handler never talks to FCM.** It queues a message for accounts in its own transaction, and the
framework's job queue delivers it later: claims in short transactions, provider calls outside any,
a record of every outcome in the provider's own words. A rolled-back command sends nothing; a
retried one sends once; two workers never send one device the same message; a token of one
transport is never judged by another.

Packages: `dartway_push_server` (this page), `dartway_push_shared` (the calls and the payload both
sides read), and the app half — [Push notifications](../3-flutter/push-notifications.md).

## Wiring

```dart
// app_shared — the project's categories, and the protocol both sides speak
enum AppPushCategory with DwPushCategory { news, bookings }

final appProtocol = DwWireProtocol(dwPushProtocolEntries, include: appGeneratedProtocol);
```

```dart
// app_server
DwAppServer(
  protocol: appProtocol,
  modules: [
    DwPushModule(
      providers: [
        DwFcmProvider(
          account: DwFcmServiceAccount.fromJson(File(serviceAccountPath).readAsStringSync()),
          webLinkBase: Uri.parse('https://app.example.com'),
        ),
        DwRuStoreProvider(projectId: ruStoreProjectId, serviceToken: ruStoreServiceToken),
      ],
      eligibility: appPushEligibility,
    ),
  ],
  // ...
);
```

`DwPushModule` is a server module (`DwServerModule`): it brings its migrations under the namespace
`push`, the handlers of `DwRegisterPushToken` and `DwUnregisterPushToken`, the job
`dw.push.deliver` and the recurring job `dw.push.cleanup`. The server refuses to start when the
protocol does not register the push calls, when a project answers them itself, or when a setting
cannot work. The example reads its providers from the environment
(`example/dartway_example_server/lib/src/core/example_push.dart`). A project's migration CLI replays the
namespace beside the framework's:

```dart
DwMigrationCli(..., modules: {'dw': DwAppServer.frameworkMigrations, dwPushNamespace: dwPushMigrations});
```

A service account is read when the provider is built: a file that is not JSON, lacks a field or
holds a key that is not RSA throws `FormatException` naming what is wrong. The OAuth assertion is
signed with RS256 implemented in the package — no Google SDK — and checked in its tests against
OpenSSL.

## Sending

```dart
await ctx.push.send(
  memberIds,
  message: DwPushMessage(
    title: post.title,
    body: excerpt,
    data: NewsAlert(id: post.id),       // a data object of the protocol: the app receives it typed
    link: '/news',                      // the in-app path a tap opens; the web opens it too
  ),
  category: AppPushCategory.news,
  dedupKey: 'news:${post.id}',
  scheduledAt: tomorrowAtNine,          // optional: now
  lifetime: const Duration(hours: 6),   // optional: DwPushSettings.messageLifetime
);                                      // → how many deliveries were queued
```

One statement writes the message once and a delivery per recipient; a second enqueues the job that
will send them. Both go through `ctx.db` — in the command's transaction, or in one of their own
when there is none.

- **The payload is a DTO**, not a map of keys. `DwPushData` writes its wire name and JSON into the
  provider's data map (`dw_type`, `dw_payload`, `dw_link`), and the app reads it back with the same
  class and its protocol: the keys exist once, in `dartway_push_shared` (#85).
- **`dedupKey`** holds per recipient while a delivery with it is pending or finished within
  `retention` (7 days): a retried command, a job that runs twice, two events about one thing send
  once. Without it every call sends.
- A message that cannot be sent — an empty title, a payload the protocol does not register, a link
  that is not a path, an image that is not an http or https URL, data too large for a provider —
  throws `ArgumentError` at the call site.
- **An `http` image is sent without the image**, with a warning naming the URL logged when the
  message is queued. Providers show only `https` images; `http` is what a development storage's
  public URL is, and a picture — decoration — must not fail the command that queued the
  notification, nor every acceptance test that runs on a local storage.

## Who receives it, and when: eligibility

```dart
Future<Map<int, DwPushDecision>> appPushEligibility(
  DwCallContext ctx,
  DwPushNotice notice,
  List<int> accountIds,
) async {
  final settings = await ctx.db.notificationSettings.find(where: (t) => t.accountId.inList(accountIds));
  return {
    for (final s in settings)
      if (!s.allows(notice.categoryIn(AppPushCategory.values)))
        s.accountId: DwPushDecision.skip
      else if (s.quietUntil(DateTime.now()) case final end?)
        s.accountId: DwPushDecision.delayUntil(end),
  };
}
```

The rule runs **when deliveries fall due**, not when they are queued: a member who opts out before
the send is not sent to, and a delay asks again at its time. It is called once per message per
batch with every due account, so preferences are read with one query, never one per recipient.
An account absent from the answer is sent to; an answer about an account that was not asked about
fails the run, and the job retries. It runs inside the claiming transaction: it reads, and calls
nothing slow. `skip` records the delivery as skipped (its dedup key stays used); a `delayUntil`
past the message's lifetime records it as expired.

## Devices

The app registers its token with `DwRegisterPushToken(transport, token, platform)`. The account is
the caller's, and the registration is **bound to the session key** the call was signed in with:

- a key revoked anywhere — sign-out, `revokeKeys`, an admin — stops that device's pushes at once,
  even when the app never got to unregister, and the cleanup of revoked keys removes the row;
- the same token registered by another account moves to it (a phone changing hands);
- a token is unique per transport: the same string of FCM and of RuStore is two registrations;
- an account keeps its `maxDevicesPerAccount` (10) most recently registered devices.

`DwUnregisterPushToken(token)` removes the caller's own registration and answers the same for a
token that is someone else's or absent. Deleting an account removes its devices and deliveries.

## Delivery

`dw.push.deliver` is a non-transactional job of the framework queue: it holds a lease, not a
transaction. One run repeats until its budget (`runBudget`, 10 s) is spent or nothing is due:

1. **Claim** — one short transaction: up to `batchSize` due, unleased deliveries of any message,
   `FOR UPDATE SKIP LOCKED`, oldest first. Expired ones finish; eligibility decides the rest; the
   recipients' devices are read in one query (revoked keys excluded); a delivery with no device
   left finishes; the others are leased to the run and the transaction commits.
2. **Send** — holding no connection: every leased (delivery, device) pair not yet settled,
   `concurrentSends` (16) at a time, each bounded by `sendTimeout`, each through the provider of
   the device's transport. No send starts after the budget; the rest is released untouched.
3. **Record** — one short transaction, one statement for the batch, guarded by the lease: the
   devices each delivery settled, the providers' error text, the next attempt's time or the
   outcome. Devices whose token is invalid are deleted.

A run lasts at most `runBudget + sendTimeout` plus two short transactions and costs a fixed handful
of statements per batch, whatever its size. A run that stops with work left queues its
continuation, so other jobs get the executor in between.

**Coverage.** Every pending delivery is due no earlier than some pending job: `send` enqueues one
at the scheduled time, and a run that moves a delivery later (a retry, a delay) enqueues one at the
earliest such time in the same transaction. Several runs may drain at once; they claim different
rows. Should a delivery job run out of attempts on database failures (which alerts),
`dw.push.cleanup` finds work overdue by more than a lease, logs it and queues a run.

**Exactly once.** A device is sent a delivery only by the run holding its lease, and the lease
(`runBudget + 2 × sendTimeout + 1 min`) outlasts the run; a device the delivery settled is never
sent it again, so a retry after a partial failure goes only to the devices that failed. One window
is left: a process dying between a provider's acceptance and the record. After the lease expires,
that device may receive the message a second time. A run whose record finds its lease taken says
so in the log.

## Outcomes and failures

| The provider answers | The device | The delivery |
|---|---|---|
| accepted | settled | `sent` once nothing is left |
| token invalid | its registration — of that transport only — is deleted | the text is recorded |
| retry later (429, 5xx, timeout, network) | kept | an attempt is counted; next try after `backoff` (15 s … 1 h, ±20 %) or the provider's `Retry-After`, whichever is longer |
| rejected (a message or credential the provider refuses) | settled, token kept | the text is recorded |

A delivery ends `sent` (at least one device accepted), `failed` (none did, and nothing is left to
try — logged at error level with the text), `skipped`, `noDevices` or `expired`. Its `last_error`
is what the providers said — `fcm device 17: fcm 503 UNAVAILABLE: The service is unavailable.`,
`rustore device 4: rustore send failed: HttpException: Connection closed before full header was
received` — never an exception's type name. An attempt is counted once, when its failure is
recorded.

**FCM** (HTTP v1). `UNREGISTERED`, `SENDER_ID_MISMATCH` and an `INVALID_ARGUMENT` about the
registration token mean an invalid token. Any other `INVALID_ARGUMENT` — a reserved data key, a
message too big — is a rejection and keeps the token: deleting live registrations over a malformed
message would silence every device. A `401` drops the cached access token and the send is tried
once more with a fresh one; the token is cached until five minutes before it expires and shared by
concurrent sends. `THIRD_PARTY_AUTH_ERROR` (APNs or web push credentials) is a rejection. With
`webLinkBase`, a web message carries `webpush.fcm_options.link` — the link on the app's origin — so
the browser opens it even where the service worker's click handler does not run (#78).

**RuStore.** A 404 `NOT_FOUND` ("wrong push token") and a 400 about the token mean an invalid
token; 401/403, 429 and 5xx retry; other 400s are rejections. RuStore does not show an image given
in its notification block, so a message with an image travels as data only, with `dw_title`,
`dw_body` and `dw_image`, and `dartway_push_rustore` draws it on the device.

## Cleanup

`dw.push.cleanup` (every `cleanupInterval`, 10 min) removes finished deliveries past `retention` —
freeing their dedup keys — and messages left without deliveries, in bounded batches, and recovers
uncovered work. The tables need no runtime storage settings: pending deliveries are read through a
partial index, finished ones are deleted by age.

## Settings

`DwPushSettings`: `batchSize` 100 · `concurrentSends` 16 · `runBudget` 10 s · `sendTimeout` 15 s ·
`maxAttempts` 6 · `backoff` · `messageLifetime` 1 day · `retention` 7 days ·
`maxDevicesPerAccount` 10 · `cleanupInterval` 10 min.

## Testing

`package:dartway_push_server/testing.dart` has `DwFakePushService`: a local HTTP service that
speaks FCM's send API, Google's token endpoint (verifying the RS256 assertion against its test key)
and RuStore's send API, records what it was sent and answers what the test says. No credentials:

```dart
final fcm = await DwFakePushService.start();
final server = await DwTestServer.start(buildServer(push: ExamplePush.module(providers: [fcm.fcmProvider()])));
// ...
fcm.answer = (send) => DwFakePushAnswer.fcmError(404, 'NOT_FOUND', 'Requested entity was not found.', fcmCode: 'UNREGISTERED');
```

The example's `test/push_acceptance_test.dart` publishes a post and checks who is notified. The
package's own suites run on Postgres: an enqueue rolled back with its command, dedup, eligibility
skip and delay, four workers draining 200 deliveries without a duplicate, provider failures
recorded with their text and retried with backoff, an invalid token removing only its transport's
registration, a run budget ending runs, a pool of one connection free while a provider holds its
answer, retention and recovery.
