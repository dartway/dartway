---
title: New data objects keep installed clients on their contract line
affects:
  dartway_generator: "0.21.0-dev.17"
  dartway_core_server: "0.21.0-dev.17"
---

## Who is affected

Projects with a generated shared contract descriptor, especially those adding data objects without
changing existing calls, channels or object shapes.

## What to change

No project code edit or installed-client update is required. On the next `dartway generate`,
`lib/generated/dw_contract.json` moves to format 2 automatically; format 1 trusted baselines still
validate. Generate and commit the descriptor and protocol together as usual.

For a new data object, raise the shared package's `version:` above the trusted base's version.
A patch bump is enough. The generator records that version as `since`, preserves existing objects'
introduction metadata, and the server keeps those updates and deletions from older builds.
A project that raised its line only for new data objects may stay on that line; nothing is undone.

## How to check

`dartway generate --check --contract-base <trusted-SHA>` passes when the generated files are current
and the new data object's shared version is above the baseline. Existing shape changes still require
a breaking-line raise.
