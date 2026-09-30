---
name: dartway-push-delivery
description: >-
  Push notifications, both halves: DwPushModule (dartway_push_server) with FCM / RuStore providers,
  the protocol composed with dwPushProtocolEntries, a category enum and a typed payload,
  ctx.push.send in the command's transaction with a dedupKey, the eligibility rule (send / skip /
  delayUntil), the app plugin DwPush (dw.plugins.push: permission, pause/resume, opened), and the
  fakes for tests. Use when a feature must notify someone not looking at the app, or when a push
  does not arrive, arrives twice or opens the wrong screen.
---

# DartWay — push notifications (`dartway-push-delivery`)

**A handler never calls FCM.** It queues a message for accounts in its own transaction; the job queue
delivers it and records every outcome. The project writes four things: **the category, the payload,
who is eligible, where a tap leads.** The framework's example does all of it for news — read it first:
the category ([`dartway_example_push_category.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_shared/lib/src/dartway_example_push_category.dart)),
the protocol ([`dartway_example_protocol.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_shared/lib/src/dartway_example_protocol.dart)),
the module and providers from the environment ([`core/push.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/core/push.dart)),
the send (`PublishNews` in [`content_handlers.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/content/content_handlers.dart)),
a push from a job ([`bookings_jobs.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/bookings/bookings_jobs.dart)),
the tap ([`push_opened_listener.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/lib/core/push/push_opened_listener.dart)),
and the tests ([`push_test.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/test/src/core/push_test.dart),
[`push_opened_listener_test.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/test/core/push/push_opened_listener_test.dart)).

## The contract

`enum AcmePushCategory with DwPushCategory { news }` in `acme_push_category.dart`; the payload a
generated data object — an id or two (FCM refuses over 4 KiB; the screen loads the rest), never a map of
agreed keys; the protocol `DwWireProtocol(dwPushProtocolEntries, include: …)` in `acme_protocol.dart`,
used by `DwAppServer`, `DwFlutterCore` and `DwFakeServer` alike — without the entries both sides refuse
to start, naming them.

## The server

`DwPushModule(providers:, eligibility:)` in `modules:` (built in `core/push.dart`, providers from the
typed environment, the eligibility rule from the `_access.dart` of the feature that owns consent), and
`dwPushNamespace: dwPushMigrations` in `bin/migrate.dart`'s modules. Send **from the command that causes
it, in its transaction**:

```dart
await ctx.push.send(
  recipientAccountIds,
  message: DwPushMessage(title: post.title, body: excerpt, data: NewsAlert(id: post.id), link: '/news'),
  category: AcmePushCategory.news,
  dedupKey: 'news:${post.id}',
);
```

- **A `dedupKey` naming the event**, so a retried command or job notifies once; `scheduledAt`,
  `lifetime` for timing. Recipients are account ids, never pre-filtered here.
- **Consent, preferences and quiet hours are the eligibility rule** —
  `Future<Map<int, DwPushDecision>> (ctx, notice, accountIds)`, one call per message per batch, one
  query; an account absent from the answer is sent to, `DwPushDecision.skip` or `.delayUntil(time)`
  otherwise. It reads only.
- Never from a request handler; never a provider call of your own.

## The app

`DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)])` in `plugins:`. Registration
is automatic per token and account; nothing on sign-out (a revoked key stops sending). `dw.init()` does
not wait for push — do not read `transport` or `token` right after it, no timeouts of your own. Ask
permission at a moment the user understands (`requestPermission()`); `DwPushPermission.unanswered` is
neither yes nor no — offer a retry. A settings toggle is `pause()` / `resume()` with
`DwPush(isEnabled:)`. Taps route in one listener under `MaterialApp.builder`,
`dw.plugins.push.opened` with `payloadAs<T>()` — the seam of `dartway-navigation`. Web: copy
`web/firebase-messaging-sw.js` from `dartway_push_firebase`, fill in only the config.

## Tests

Server: `DwFakePushService` (`package:dartway_push_server/testing.dart`), a device registered with
`DwRegisterPushToken` from a real client, then `dw_push_delivery.outcome` and the fake's sends — who was
notified, who skipped, the payload, nothing sent by a refused command. App: `DwFakePushTransport`
(`package:dartway_push_flutter/testing.dart`) — one registration, `transport.open(…)` reaches the screen,
a cold start with `initialOpen` lands there. Never real credentials.

## When a push does not arrive

Read `dw_push_delivery` (joined to `dw_push_message`) before the logs. `outcome`: `NULL` pending (a
future `run_at` is a retry or a delay) · `skipped` by eligibility · `noDevices` — never registered or
signed out · `expired` past its lifetime · `failed` — `last_error` has each provider's words (an
`UNREGISTERED` token is removed and re-registered on the next start) · `sent` — accepted by the provider.
