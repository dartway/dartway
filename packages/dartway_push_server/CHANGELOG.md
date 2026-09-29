## 0.5.1

- **A delivery is due by the server's clock, the one its job runs by** (dartway/dartway#385).
  `ctx.push.send` schedules on `ctx.now` (a missing `scheduledAt` is `ctx.now`, not the database's
  `now()`), and the worker claims, leases, delays, retries and finishes deliveries against it; the
  `dw.push.cleanup` job ages finished deliveries and finds uncovered ones by it too. Before, the
  `dw.push.deliver` job became due by the server's clock while the deliveries it covers were due by
  the database's: with skew between the two, or a `DwTestClock`, a job could run before its
  delivery was due, claim nothing and leave it without a job, and a retry never ran under a clock
  that stood still. Needs `dartway_core_server` `0.21.0-dev.9` (`ctx.now`). Nothing to change in a
  project; a test on a `DwTestClock` moves the clock to send a scheduled push or run a retry.

## 0.5.0

- This package now targets the rewritten DartWay framework (`dartway_core_server` 0.20.0). The previously published `0.4.0` was built on the old, Serverpod-based stack.

- **An `http` image no longer fails the send.** `DwPushMessage.imageUrl` over `http` is accepted,
  logged as a warning when queued, and left out of the notification providers receive; only a
  value that is not an http or https URL at all is an `ArgumentError`. A development storage's
  public URL is `http`, so every command that queued a push with a picture rolled back locally and
  in tests (D-063).

- Ported to DartWay 1.0 as a server module (`DwPushModule`): migrations under
  the `push` namespace, delivery by the framework job queue with claims in
  short transactions and provider calls outside them, provider error text
  recorded, per-transport device registrations bound to session keys, an
  eligibility rule, `DwFakePushService` for tests.
