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

After the same app build is live in both stores, run:

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

## How to check

Run `dartway check`, then run the release-only cleanup gate with
`dartway check --release`.
