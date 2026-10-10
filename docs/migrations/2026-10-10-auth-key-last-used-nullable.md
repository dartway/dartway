---
title: A session key's lastUsedAt is null until its first use
affects:
  dartway_core_shared: "0.21.0-dev.17"
  dartway_core_server: "0.21.0-dev.17"
---

## Who is affected

A project that reads `DwSessionKeyInfo.lastUsedAt` — from `ctx.sessionKey`, `listKeys`, or a
`DwSessionKeyInfo` it sends to its own app — or builds a `DwSessionKeyInfo` itself. The field is now
`DateTime?`: `null` until the key's first use, which is always recorded. The framework migration
`20261009_000003_dw_auth_key_last_used` sets it to `NULL` on every key whose `last_used_at` still
equals its `created_at`, so a key used only within its first `keyTouchInterval` before the upgrade
reads as never used.

## What to change

1. Where the code compares `lastUsedAt` with `createdAt` to tell an unused key, ask the field:

       - final lastUsed = key.lastUsedAt.isAtSameMomentAs(key.createdAt) ? null : key.lastUsedAt;
       + final lastUsed = key.lastUsedAt;           // or key.isUsed

2. Every other read of `lastUsedAt` handles `null` — the compiler names each one.

3. A query of the project's own on `dw_auth_key.last_used_at` expects `NULL` for a key never used.

## How to check

The project compiles; a key issued and not yet used shows `lastUsedAt == null`, and after one call
with it a value.
