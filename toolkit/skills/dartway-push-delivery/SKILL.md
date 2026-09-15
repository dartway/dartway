---
name: dartway-push-delivery
description: >-
  Push notifications in a DartWay project, both halves: the server module `DwPushModule`
  (`dartway_push_server`) in `DwAppServer(modules:)` with `DwFcmProvider` / `DwRuStoreProvider`,
  the protocol composed with `dwPushProtocolEntries`, a category enum `with DwPushCategory`, a typed
  payload data object, `ctx.push.send(...)` in the command's transaction with a `dedupKey`, the
  eligibility rule (`DwPushDecision.send / skip / delayUntil`, one call per message per batch) for
  consent, preferences and quiet hours; devices registered by `DwRegisterPushToken` and bound to the
  session key; the app half `DwPush` (`dartway_push_flutter`, `dw.plugins.push`) with
  `DwFirebasePush` and `DwRuStorePush`, `requestPermission`, `pause` / `resume`, the `opened`
  stream with `payloadAs<T>()`, the web service worker template; tests with `DwFakePushService`
  (server, no credentials) and `DwFakePushTransport` (widget tests). Use when a feature must notify
  someone who is not looking at the app, when a push does not arrive, arrives twice or opens the
  wrong screen, or when reading why a delivery failed.
---

# DartWay — push notifications (`dartway-push-delivery`)

**A handler never calls FCM.** It queues a message for accounts in its own transaction; the
framework's job queue delivers it later and records every outcome in the provider's words. The
project writes four things: **the category, the payload, who is eligible, and where a tap leads.**

The example does all of it for news: `example/dartway_example_shared/lib/src/example_push.dart`
(category, protocol), `NewsAlert` in `news.dart` (payload), `example_push.dart` on the server
(eligibility by marketing consent, providers from the environment), `PublishNews` in
`content_handlers.dart` (the send), `lib/core/push/push_opened_listener.dart` in the app (the tap),
and `test/push_acceptance_test.dart` / `test/app/push_test.dart`. Read them first.

The framework's pages: *Push delivery* (server) and *Push notifications* (app) in the DartWay
documentation.

---

## 1. The contract — `__SHARED_PKG__`

```dart
/// What a news notification carries to the app: the post it is about.
final class NewsAlert extends DwDataObject with _$NewsAlert {
  const NewsAlert({required this.id});
  @override
  final int id;
}

enum AppPushCategory with DwPushCategory { news }

final appProtocol = DwWireProtocol(dwPushProtocolEntries, include: appGeneratedProtocol);
```

- **The payload is a generated data object**, never a `Map<String, String>` of keys agreed in two
  places. Keep it small (an id or two): FCM refuses a message above 4 KiB, and the screen loads
  the rest with a request.
- **Server and app both use `appProtocol`** (`DwAppServer(protocol:)`, `DwFlutterCore(protocol:)`,
  `DwFakeServer(protocol:)`). Without the push entries the server refuses to start and the plugin
  fails its start, both naming `dwPushProtocolEntries`.

## 2. The server — `__SERVER_PKG__`

```dart
DwAppServer(
  modules: [
    DwPushModule(
      providers: [
        if (env['FCM_SERVICE_ACCOUNT_FILE'] case final file?)
          DwFcmProvider(
            account: DwFcmServiceAccount.fromJson(File(file).readAsStringSync()),
            webLinkBase: Uri.parse(env['WEB_APP_ORIGIN']!),   // https; web clicks open links there
          ),
      ],
      eligibility: appPushEligibility,
    ),
  ],
);
```

and in `bin/migrate.dart`: `modules: {'dw': DwAppServer.frameworkMigrations, dwPushNamespace: dwPushMigrations}`.

**Send from the command that causes the notification, inside its transaction:**

```dart
await ctx.push.send(
  recipientAccountIds,
  message: DwPushMessage(title: post.title, body: excerpt, data: NewsAlert(id: post.id), link: '/news'),
  category: AppPushCategory.news,
  dedupKey: 'news:${post.id}',
);
```

- **Always give a `dedupKey` that names the event** (`news:<id>`, `booking-reminder:<bookingId>`):
  a retried command or a job that runs twice then notifies once per recipient.
- `scheduledAt` for later ("tomorrow at 9"), `lifetime` for how late it may still go out.
- Recipients are **account ids**. Do not pre-filter by consent or quiet hours here: that is the
  eligibility rule, which runs when the delivery is due and so sees today's preferences.
- Never send from a request handler, and never call a provider yourself.

**The eligibility rule** — one call per message per batch, with every due account; read preferences
with one query:

```dart
Future<Map<int, DwPushDecision>> appPushEligibility(DwCallContext ctx, DwPushNotice notice, List<int> accountIds) async {
  switch (notice.categoryIn(AppPushCategory.values)) {
    case AppPushCategory.news:
      final agreed = {
        for (final p in await ctx.db.userProfiles.find(
          where: (t) => t.accountId.inList(accountIds) & t.agreedForMarketing.equals(true),
        )) p.accountId,
      };
      return {for (final id in accountIds) if (!agreed.contains(id)) id: DwPushDecision.skip};
    case null:
      return const {};
  }
}
```

An account absent from the answer is sent to. `DwPushDecision.delayUntil(time)` for quiet hours:
the rule is asked again at that time. It runs in the claiming transaction — reads only.

## 3. The app — `__FLUTTER_PKG__`

```dart
plugins: [DwSharedPreferences(), DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)])],
```

- Registration is automatic: token + signed-in account, once per pair. **Do not call anything on
  sign-out** — the server stops sending when the session key is revoked.
- Ask permission at a moment the user understands: `dw.plugins.push.requestPermission()`.
- A settings toggle: `dw.plugins.push.pause()` / `resume()`, and `DwPush(isEnabled: ...)` reading
  the stored choice at start.
- Route taps in one listener under `MaterialApp.builder`, by payload type first, link second:
  `dw.plugins.push.opened.listen(...)`. The notification that started the app waits for it.
- Web: copy `web/firebase-messaging-sw.js` from `dartway_push_firebase` and fill in only the
  config; never reorder it (the SDK's click handler stops every handler registered after it).

## 4. Tests

- **Server**, on Postgres with `DwFakePushService` (`package:dartway_push_server/testing.dart`) —
  build the module with `fcm.fcmProvider()`, register a device with `DwRegisterPushToken` from a
  real client, run the command, `eventually` read `dw_push_delivery.outcome` and `fcm.sends`:
  who was notified, who was skipped, what the payload decodes to, and that a refused command sent
  nothing.
- **App**, with `DwFakePushTransport` (`package:dartway_push_flutter/testing.dart`) and the
  `DwFakeServer` answering `DwRegisterPushToken`: one registration for a signed-in start,
  `transport.open(DwPushData(payload: ...))` leads to the screen, a cold start with `initialOpen`
  lands there.

## 5. When a push does not arrive

Read the delivery rows, not the logs first:

```sql
SELECT d.account_id, d.outcome, d.attempts, d.last_error, d.run_at, m.category, m.title
FROM dw_push_delivery d JOIN dw_push_message m ON m.id = d.message_id
ORDER BY d.id DESC LIMIT 20;
```

| `outcome` | Means |
|---|---|
| `NULL` | pending: `run_at` in the future is a retry or a delay |
| `skipped` | the eligibility rule said so |
| `noDevices` | no registration under a live session key — the app never registered, or signed out |
| `expired` | due after its lifetime (a long delay, a long outage) |
| `failed` | every device refused or ran out of attempts; `last_error` has each provider's words |
| `sent` | a provider accepted it — from here it is the device, its permission and the vendor |

`last_error` like `fcm device 17: token invalid, removed: fcm 404 NOT_FOUND: … (UNREGISTERED)`
means the registration was deleted and the app re-registers on its next start. A duplicate on one
device is only possible after a process died between a provider's acceptance and the record.

## Rules

- One `DwPushModule` per server; categories and payloads are the project's, in shared.
- `ctx.push.send` inside the command's transaction, with a `dedupKey`, to account ids.
- Consent, preferences and quiet hours live in the eligibility rule, not before `send`.
- No sign-out unregistration; no provider calls in handlers; no hand-written data keys.
- Test both halves with the fakes; never with real credentials.
