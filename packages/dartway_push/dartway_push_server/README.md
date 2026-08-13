# dartway_push_server

The reliable half of push delivery, as a Serverpod module.

Sending one notification to one device is a single HTTP call. Sending to fifteen thousand people
when a post goes live is not: some devices are offline, the provider rate-limits you, a worker
crashes mid-run, the same campaign gets triggered twice, and someone deletes their account while a
send to them is in flight. The hard part of push is never the send — it is the queue, the retries
and the races around it. This module owns that part so an app does not hand-roll it again.

It is **optional**: an app that needs push adds the dependency and gets the `dw_push_*` tables; an
app that does not gets none of them.

## What it owns

- A durable queue over six tables — one stored message payload, compact membership rows per
  recipient, short pending delivery rows.
- A worker that claims batches with `FOR UPDATE ... SKIP LOCKED`, leases them, retries transient
  failures with backoff, deduplicates by a stable key, and reclaims the leases of a crashed worker.
  Terminal deliveries are deleted; hourly metric buckets and a periodic `cleanup()` keep storage
  bounded.
- Two built-in providers, both pure Dart: `DwFcmPushProvider` (FCM HTTP v1) and
  `DwRuStorePushProvider`. Provider outcomes are a classified enum rather than a raw response, and
  RuStore fallback fires only on an explicit "not this provider's token" signal — never on a
  timeout, a 429 or a 5xx. Raw tokens and response bodies are never logged, only a fingerprint.
- Delivery routed by the transport that issued the token, not guessed:
  `DwPushProviderTransport.routed` sends each target where it belongs, probes a token of unknown
  provenance once, and remembers the answer. A token is dropped only when every configured
  transport refuses the target itself.
- The device-token plumbing every push app needs — registration as a CRUD action rather than an
  endpoint you write, normalization, byte-length validation, a per-recipient cap with newest-N
  eviction, refresh windows, canonical-token dedup, and skipping enqueue for recipients with no
  usable token. Keyed on an opaque `recipientId`, with no app types in sight.
- `DwPushDispatcher` — the stretch between a domain event and `enqueue`: exclude the actor, drop
  recipients with no device, apply the app's audience filter, invent a deduplication key, pick a
  per-category lifetime, and chunk a large audience.
- Source-linked cancellation: map business `(sourceType, sourceId)` values to a queued message and
  cancel it when the source disappears, so an immutable payload never goes out stale.

## What your app owns

Who receives a message and when it is enqueued, user consent and categories, provider credentials —
and **authorization**. The module ships no endpoints and nothing routable: token registration comes
as a `DwDtoActionConfig` an app adds to its own CRUD configuration, so nothing is reachable until
the app says so, and deciding who may send a marketing blast, pause the worker or read metrics
belongs where the role model lives.

## Wiring

Push is not part of `DwCore` — the app constructs and owns a `DwPush`:

```dart
dwPush = DwPush(
  config: DwPushConfig(
    recipientResolver: DwDevicePushTokenResolver(isEligible: appConsentCheck),
    transport: DwPushProviderTransport.routed(
      providers: {DwPushProviders.fcm: fcm, DwPushProviders.ruStore: ruStore},
    ),
  ),
);
```

`DwPushConfig` is deliberately small: a `DwPushRecipientResolver` and a `DwPushTransport` are the
whole surface most apps ever write — and with `DwDevicePushTokenResolver` the first one is one
callback about consent. Every performance and retention knob lives on an optional
`fineTuning: DwPushFineTuning(...)`, where each field documents what it trades off.

The full guide — module registration, migrations, the domain seam, the tuning knobs and what
`maxConcurrentDeliveries` costs your connection pool — is at
[dartway.dev](https://dartway.dev) under Server → Push delivery.

## Part of DartWay

[DartWay](https://dartway.dev) is a fullstack Dart framework (Flutter + Serverpod). This module is
one of its optional pieces; the framework itself lives in the same
[repository](https://github.com/dartway/dartway).
