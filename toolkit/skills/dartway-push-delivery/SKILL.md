---
name: dartway-push-delivery
description: >-
  Push notifications in DartWay, both halves: the optional dartway_push_server
  Serverpod module (DwPush engine, resolver + routed transport, FCM/RuStore
  providers, idempotent enqueue, dispatcher, worker/cleanup, retries,
  account-deletion lock, campaign progress, device token registration as a CRUD
  action) and the app half (dartway_push_flutter as dw.plugins.push, with the
  dartway_push_firebase and dartway_push_rustore transports). Use when adding or
  reviewing push notifications in a DartWay app. Everything here is opt-in — an
  app that does not depend on these packages has no push tables and no vendor
  SDK.
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
  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured ? DwFcmPushProvider(config: fcmConfig) : null;
  final ruStore = ruStoreConfig.isConfigured
      ? DwRuStorePushProvider(config: ruStoreConfig)
      : null;

  dwPush = fcm == null && ruStore == null
      ? null // no provider configured → push inert
      : DwPush(
          config: DwPushConfig(
            recipientResolver: const DwDevicePushTokenResolver(
              isEligible: appConsentCheck,
            ),
            // Each device goes through the transport that issued its token.
            transport: DwPushProviderTransport.routed(
              providers: {
                DwPushProviders.fcm: ?fcm,
                DwPushProviders.ruStore: ?ruStore,
              },
            ),
          ),
        );

  // Built before the core: the registration action is one of its DTO configs.
  dw = DwCore.init<UserProfile>(
    dtoConfigurations: [if (dwPush != null) dwPush!.tokenRegistrationConfig()],
    /* ... */
  );
}
```

### The module reaches an existing database like any other model change

`serverpod generate` → `serverpod create-migration` → deploy. Nothing else, and
no special handling for a database that has been in production for years.

Worth knowing, because the module's `migrations/` folder says otherwise: its
first migration creates a whole schema — `serverpod_log`, `dw_auth_key` and the
rest — rather than only the `dw_push_*` tables. That is what
`serverpod create-migration` writes for **any** module, the DartWay core module
included; it folds every dependency module into `migration.sql` and
`definition.sql` and offers no way to ask it not to. Serverpod 3.4.11 never
applies those two files: its migration manager is built from the *project*
directory and migrates one module, the project. The module's chain is read once,
by `create-migration` in the app, and only `definition_project.json` of its
latest version — so the module's tables arrive as an ordinary `CREATE TABLE` in
the app's own migration.

Do not hand-edit anything under the module's `migrations/`, and do not copy its
SQL into the app. If a deploy dies on `relation "dw_push_*" already exists`, the
tables are physically there while the migration history says they are not — the
route out is `serverpod create-repair-migration --mode <env>` and one run with
`--apply-repair-migration`, never a `DROP TABLE`.

### Credentials come from two places, and which one is not a preference

**Short values go in `passwords.yaml`; a credential that is a whole document
goes in as a file.** Default password keys are `fcmProjectId`,
`rustorePushProjectId`, `rustorePushServiceToken` — two identifiers and a token,
each a line long. FCM's service account is a couple of thousand characters of
JSON and is **not** a password key: it is delivered with
`dartway deploy secret put-file`, named under `requires.files` in
`deploy/config.yaml`, and read from `config/fcm-service-account.json` — a
relative path that resolves to the same file locally and inside the container,
where the deploy mounts every declared file at `/app/config/<name>` beside
`passwords.yaml`. `fromPasswords` reads it from there by default;
`serviceAccountFile:` names a different path.

A document in `passwords.yaml` is a document in the master copy of **every**
environment's secrets, and it carries a silent failure: the value starts with
`{`, so unquoted YAML parses it as a flow mapping rather than as a string.

So `passwords.yaml.example` documents the project id and nothing else:

```yaml
staging:
  # Push. Naming this key is what declares that this environment sends push —
  # the server refuses to start when it is set and the credential is missing.
  # The service account is not a password but a file: deliver it with
  # `dartway deploy secret put-file fcm-service-account.json`, list it under
  # requires.files in deploy/config.yaml, and it is read as
  # config/fcm-service-account.json.
  fcmProjectId:
```

### Half-configuration fails at startup, by design

A provider's project id is its **declaration**. Once it is present, everything
else that provider needs has to be there too, or the config constructor throws
`DwPushProviderConfigurationException` and the server does not start — naming
what is missing and where it was looked for. A service account that is not a
JSON object (a truncated upload, a YAML value that lost its quotes) is refused
the same way.

Deliberate, because `isConfigured == false` used to be the answer both to "we do
not send push here" and to "the key never reached this environment": a forgotten
credential looked exactly like a decision, and was noticed weeks later by
somebody asking why a notification never arrived.

An environment that genuinely wants no push declares nothing — no project id, no
file — and `isConfigured` is false without anyone being lied to.

Secrets stay in the app and never reach the queue or logs. Include only
providers whose `isConfigured == true`; if none are, keep `dwPush` null. Icons
and colours are the app's choice — pass optional `webpushIcon`, `androidIcon`,
`androidColor` explicitly.

`DwPushConfig` is deliberately small: `recipientResolver` and `transport` are the
whole surface most apps write. Every tuning knob lives on an optional
`fineTuning: DwPushFineTuning(...)` where each field documents what it affects
(throughput, recovery, storage). Reach for it only under a real load profile —
most notably `maxConcurrentDeliveries`, which bounds parallel sends and, because
each in-flight send holds a DB connection, must stay a small fraction of the
Postgres pool.

## Config seam

`DwPushRecipientResolver.resolve` is called under a recipient advisory lock and
inside a transaction. It returns `DwPushTarget`s — a token **and** the transport
that issued it. Prefer `DwDevicePushTokenResolver(isEligible: ...)`: it reads the
module's own token store, keeps the values canonical, deletes the targets a
provider rejected and records a probed provider, leaving the app only the
question the module cannot answer (consent, muted categories, deleted account).
An empty list is a terminal skip. Implement the interface yourself only when the
tokens live outside the module.

`DwPushTransport.send` must return exactly one `DwPushTargetResult` per target.
If at least one target is accepted the delivery is done; otherwise a transient
failure may retry. For a different provider or batch/multicast, implement your
own `DwPushTransport`.

Provider outcome is a classified enum, never the raw response. With
`DwPushProviderTransport.routed` a target whose provider is known is sent there
and nowhere else; a target of unknown provenance (an older build that reported no
provider) is probed in `probeOrder`, the answer travels back as
`DwPushTargetResult.discoveredProvider` and the resolver persists it, so a token
is probed at most once. A probed target is dropped **only** when every configured
transport refused the target itself — anything transient keeps it. The plain
constructor keeps the older single-provider behaviour, where `fallbackProvider`
fires only on an explicit `targetNotSupported`; after timeout, 429/5xx or any
other retryable error it does not.
Raw tokens, credentials and provider bodies never reach logs — only a
fingerprint. Built-in providers reject an encoded payload over 4096 bytes before
any HTTP.

If `imageUrl` is not fully built by trusted server code, validate its host
against the app's CDN allowlist before enqueue: the built-in check rejects
local/IP and non-HTTPS URLs, but a public URL is then fetched by the provider.

## Enqueue

Prefer `DwPushDispatcher` over calling the queue directly — it is the stretch
between a domain event and the queue that is the same in every app:

```dart
dwPushDispatcher = DwPushDispatcher(
  push: dwPush!,
  audienceFilter: appAudienceFilter,      // consent, in bulk, before queueing
  isEnabled: appPushKillSwitch,           // one place to stop generating pushes
  categoryLifetimes: const {'chat_reply': Duration(hours: 1)},
);

await dwPushDispatcher!.send(
  session,
  recipientIds: recipientIds,
  category: 'chat_reply',
  title: title,
  body: body,
  deduplicationKey: 'chat_reply:$messageId',
  excludeRecipientId: actorId,            // never notify the person who acted
);
```

It drops recipients with no device, applies the filter, invents a deduplication
key when there is no natural one, picks the lifetime for the category and chunks
the audience. `sendToEveryone(page: ...)` pages through a whole user base with an
app-supplied callback, under one message and one deduplication key.

The primitive underneath, when a call needs something the dispatcher does not
express:

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

**Draining in a loop with a time budget — pass the budget in.** A pass without a
deadline runs to the end of its claimed batch however long the provider takes, so
a loop that only checks its clock between passes overruns by whatever the pass
inside it cost (a real case: a 20-second budget producing 55-77-second runs).
With `deadline:` the batch stops between concurrency chunks and returns what it
did not reach to the queue unleased, ready for the next pass:

```dart
final deadline = DateTime.now().add(const Duration(seconds: 20));
while (DateTime.now().isBefore(deadline)) {
  final result = await dwPush!.processBatch(session, deadline: deadline);
  if (result.claimed == 0) break; // claimed counts what the pass processed
}
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

- **Device tokens** — `DwDevicePushToken` (keyed on `recipientId`, carrying the
  `provider` that issued it) plus `DwDevicePushTokenPolicy`
  (normalize/validate/cap/refresh rules) and `DwDevicePushTokenStore`
  (`register`, `unregister`, `setProvider`, `targetsForRecipient`,
  `findByNormalizedValue`, `evictExcessForRecipient`, `recipientHasToken`,
  `filterRecipientsWithTokens`). Registration is **not** an endpoint the app
  writes: `dwPush.tokenRegistrationConfig()` returns a `DwDtoActionConfig` the
  app adds to `dtoConfigurations`, and the device calls it through the ordinary
  CRUD action. The recipient always comes from the session. A token found under
  another recipient is reassigned by default — an installation changes hands,
  and leaving it attached sends one user's notifications to another's phone.
- **Cancel-on-source-removal** — `dwPush.linkMessageSources(session,
  sourceType:, sourceIds:, messageId:, transaction:)` records that a message was
  enqueued "about" some business sources; `dwPush.cancelMessagesBySources(...)`
  cancels those messages when a source disappears (a post deleted before its
  push is sent), so an immutable payload never goes out stale. `sourceType`/
  `sourceId` are opaque app strings.

## The app half (Flutter)

`dartway_push_flutter` is a plugin — `dw.plugins.push` — and carries no vendor
SDK. Transports arrive as separate packages: `dartway_push_firebase` (FCM;
Android, iOS, web) and `dartway_push_rustore` (Android).

```dart
plugins: [
  DwPush(
    config: DwPushConfig(
      providers: [DwRuStorePush(), DwFirebasePush(webVapidKey: kVapidKey)],
      onOpened: (opened) => appRouter.go(routeFor(opened.data)),
    ),
  ),
],
```

Then wrap the app: `DwPushScope(push: dw.plugins.push, child: ...)`.

Rules that matter:

- **do not configure who the token belongs to.** The plugin takes
  `dw.signedInUserIdProvider` at `init`, which is the same identity the server
  derives the real recipient from — a registration carries a token and a
  provider, never an id. On the client the id is local bookkeeping only (is
  there anybody to register for, has this exact registration been made, did a
  sign-out invalidate it), so a second source redirects nothing and only puts
  that bookkeeping out of step with the server; the symptom is push going quiet
  after an account switch. `recipientIdProvider` is for an app that
  authenticates through an `AuthenticationKeyManager` of its own, and what it
  passes must mirror the identity its calls are authenticated as. **Never write
  `dw.<anything>` inside the `plugins:` list** — `dw` is being assigned by that
  very constructor and throws `LateInitializationError` before the first frame;
- **declaration order is the policy** — the first transport that builds for the
  platform and is available on the device wins. No platform switch in app code;
- the plugin **never navigates**. `onOpened` fires once per tap, after a frame,
  for cold start, background and foreground alike; mapping a data map to a route
  is the app's business, and the payload keys are the app's too. The `appRouter.go`
  above is not a lapse from the navigation rule — `onOpened` is declared in this
  very `plugins:` list, before `ProviderScope` and before the first frame, so
  there is no context to go through. `dartway-navigation`, "The one transition
  that has no context", holds the boundary: one seam per application, in `core/`,
  cancelled when the tree is destroyed;
- `requestPermissionOnAttach: false` plus `dw.plugins.push.requestPermission()`
  asks at a moment the user understands;
- **call `dw.plugins.push.revokeToken()` before signing out**, while the session
  is still valid — afterwards nothing can authenticate the call and the device
  keeps receiving the previous user's notifications;
- the app still owns the native setup: `Firebase.initializeApp` plus
  `DwFirebasePush.registerBackgroundHandler()` in `main()`, the platform
  config files, the web service worker (template in the firebase package), and
  the RuStore `project_id`/icon meta-data in the Android manifest.

**On web the tap has two paths, and they are not equivalent.** The server sets
`webpush.fcm_options.link` from the payload's `link` key, so a tap opens the
right screen even in an app with no service worker of its own — that is the
fallback, and it costs a fresh tab every time. The template's
`notificationclick` handler is the path worth having: it focuses a tab that is
already open and hands the path to the router. It takes the click by being
registered **before** `firebase.messaging()` and calling
`stopImmediatePropagation()`, because the SDK installs a listener of its own in
there and stops propagation the same way — a handler placed after it never runs,
on any browser, with nothing in the console. Copy the template as it stands and
do not reorder those two blocks.

**Check the tap on a device rather than from a metric.** `delivered` means FCM
accepted the request. It says nothing about whether anything was shown, and less
about where the tap went; the distance between "accepted" and "opened the right
screen" is where this section comes from.

## Authorization

The module ships no endpoints and no gating; the one thing it does ship — the
token registration config — is reachable only once the app declares it, and it
writes only for the authenticated caller. Marketing sends, `pause`/`resume`
and metric reads are privileged — the **app** must gate them in its own
endpoints, where the role model lives. Do not expose these to any authenticated
user. The module deliberately keeps no "who is admin" concept.

## Checks

- engine imports no domain code (no course/chat/post/lesson);
- resolver returns only eligible active targets; empty list is a terminal skip;
- targets carry their provider; a probed target is invalidated only when every
  transport refused the target itself, never on timeout/429/5xx;
- token registration goes through `tokenRegistrationConfig()`, not through an
  endpoint of the app's own, and never takes the recipient from the request;
- the app half passes no `recipientIdProvider`, and the `plugins:` list mentions
  `dw` nowhere;
- the FCM service account is a file under `requires.files`, never a key in
  `passwords.yaml`; the project id is a password key and declares the intent;
- raw token/credentials/provider body never logged;
- deduplication key stable and unique; `expiresAt` always set;
- worker scheduled via `DwRecurringFutureCall`; several instances safe;
- account deletion runs under `withRecipientLock`; host excludes the deleted
  user from enqueue forever;
- privileged operations are admin-gated by the app;
- unit-test retry/result and resolver business filters.
