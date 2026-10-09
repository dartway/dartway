---
title: Run deploy setup before the first deploy with BBR
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

Every existing server before its first `deploy run` after updating to `dartway_cli` 0.24.0. The
server may have `tcp_bbr` on disk without having loaded it, so BBR is absent from
`tcp_allowed_congestion_control`.

## What to change

Run setup once for each server, before its first deploy on this version:

```bash
dart run dartway_cli:dartway deploy setup --env <env>
```

Setup is idempotent. If it has not run, the `deploy run` guard stops before replacing anything and
reports `bbr-unavailable` with the same setup command.

## How to check

Run `dart run dartway_cli:dartway deploy check --env <env>` and confirm that
`The front proxy uses BBR congestion control` passes. Inside the front proxy, `ss -ti` shows `bbr`.
