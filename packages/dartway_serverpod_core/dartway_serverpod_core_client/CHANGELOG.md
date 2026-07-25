# Changelog

## 0.2.0

Regenerated against Serverpod 3.4.11 (from 3.4.8). No hand-written change and no change to the
protocol surface — the version moves because the four `dartway_serverpod_core_*` packages are
released in lockstep and are only ever installed as a set.

## 0.1.0

First public release — the generated Serverpod protocol client of the DartWay core module:
`DwModelWrapper`, `DwApiResponse`, `DwBackendFilter`, `DwAuthFailReason` and the endpoint callers.

You do not write against this package directly. It is a dependency of
[`dartway_serverpod_core_flutter`](https://pub.dev/packages/dartway_serverpod_core_flutter) — that is
the package your app uses.
