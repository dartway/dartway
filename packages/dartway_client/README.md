# dartway_client

The [DartWay](https://dartway.dev) client — HTTP calls, the live update socket, request state and
sessions. Pure Dart, on every side.

It carries calls, the live socket, the session, and the live state of every watched request.
`testing.dart` holds `DwFakeServer`, an in-memory server that speaks the real HTTP contract and
live socket, so an app's own tests do not need a real one.

## Where it sits

`dartway_client` is one of the six packages of the core family, versioned in lockstep, and it is
internal to the family: `dartway_core_flutter` re-exports it, so a Flutter app reaches it through
`dartway_core_flutter` rather than depending on it directly. A project's own test suites depend on
it directly only for `DwFakeServer` and the other `testing.dart` fixtures.

`dartway create` wires this up already — this package is not something you add by hand to a
project.

## Documentation

The full documentation lives in the framework's repository, at
[`docs/`](https://github.com/dartway/dartway/tree/master/docs) — start at
[`docs/3-flutter/`](https://github.com/dartway/dartway/tree/master/docs/3-flutter) for the app side
this package underpins.
