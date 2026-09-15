# dartway_push_server

Push notifications for a DartWay server: `DwPushModule` in `DwAppServer(modules:)`.

- `ctx.push.send(accountIds, message:, category:, dedupKey:, scheduledAt:)` queues a message in the
  caller's transaction;
- the framework's job queue delivers it: claims `FOR UPDATE SKIP LOCKED` in short transactions,
  provider calls outside any, a run budget, retries with backoff, outcomes recorded with the
  provider's text;
- `DwFcmProvider` (service account → RS256 assertion → cached OAuth token → HTTP v1) and
  `DwRuStoreProvider`, routed by the transport each device registered with; an invalid token
  removes only that transport's registration;
- an eligibility rule (`DwPushDecision.send / skip / delayUntil`) run when deliveries fall due;
- devices registered by the app and bound to its session key, so a sign-out stops them.

`package:dartway_push_server/testing.dart` has `DwFakePushService`, a local FCM / Google OAuth /
RuStore service for tests without credentials.

Documentation: `docs/4-server/push-delivery.md`.
