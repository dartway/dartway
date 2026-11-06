---
title: Adopt the store contract baseline
affects:
  dartway_cli: "0.28.0"
  dartway_core_shared: "0.26.0-dev.1"
  dartway_generator: "0.26.0-dev.1"
---

## Who is affected

Projects that release a server before their mobile builds clear both stores.

## What to change

Applies when updating `dartway_cli` to `0.28.0` and the core family to
`0.26.0-dev.1`.

First open each server-sent enum and add only its `unknown` fallback. Generate
and ship that app build. This adoption step is compatible both before and after
a store baseline exists, so it does not raise the contract breaking line: a
current server never stores or sends `unknown`, and an installed strict client
therefore cannot meet it.

This includes the framework's `DwIdentifierKind`: exhaustive switches must add
`DwIdentifierKind.unknown`. A project's `normalize` callback must return `null`
for that value; the framework refuses `unknown` as client input before calling
the callback.

After that app build is live in both stores, run:

```bash
dartway contract baseline
```

Commit `<project>_shared/contract_baseline.json`. Add `dartway check --release`
to release CI. Ordinary pull requests continue to run `dartway check`; the
release form additionally requires contract members whose deprecation mark is
already in the store baseline to be removed.

Do not create the baseline from a build that is still under review in either
store. Until the file is committed, the existing Git contract gate remains in
effect.

Open every enum that appears in a `DwDataObject` field or a request/command
result, and add the fallback case to exhaustive switches:

```dart
enum DeliveryState with DwOpenEnum { pending, delivered, unknown }

final label = switch (state) {
  DeliveryState.pending => 'Pending',
  DeliveryState.delivered => 'Delivered',
  DeliveryState.unknown => 'Unknown',
};
```

Enums used only in fields sent by the client may remain strict. Do not add any
other enum value in the strict-to-open step: that combined change is breaking.
Only after the opened build reaches both stores and its baseline is committed
may a later server release add another value without raising the breaking line.

## How to check

Run `dartway check`, then run the release-only cleanup gate with
`dartway check --release`.
