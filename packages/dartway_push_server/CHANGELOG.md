## 0.3.0-dev.1

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
