# dartway_push_client

The client half of the DartWay push module — and it is deliberately almost empty.

A Serverpod module comes in two packages, and the generator writes a client one whether or not
there is anything to put in it. Here there is not: push models are server-only, so this package
carries the generated protocol and nothing else. It exists because an app that depends on
[`dartway_push_server`](https://pub.dev/packages/dartway_push_server) has a generated protocol that
imports it, not because anyone calls it directly.

Add it only alongside the server package; on its own it does nothing.

The module itself — the queue, the worker, the providers — is documented in
[`dartway_push_server`](https://pub.dev/packages/dartway_push_server) and at
[dartway.dev](https://dartway.dev) under Server → Push delivery.

## Part of DartWay

[DartWay](https://dartway.dev) is a fullstack Dart framework (Flutter + Serverpod). The framework
lives in one [repository](https://github.com/dartway/dartway).
