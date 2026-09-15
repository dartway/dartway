## 0.3.0-dev.1

- Ported to DartWay 1.0 as a server module (`DwPushModule`): migrations under
  the `push` namespace, delivery by the framework job queue with claims in
  short transactions and provider calls outside them, provider error text
  recorded, per-transport device registrations bound to session keys, an
  eligibility rule, `DwFakePushService` for tests.
