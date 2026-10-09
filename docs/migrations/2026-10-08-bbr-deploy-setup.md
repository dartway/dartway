---
title: Run deploy setup before the first deploy with BBR
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

Every existing server before its first `deploy run` with a CLI that carries the BBR guard (#470,
`dartway_cli` 0.24.0). The server may have `tcp_bbr` on disk without having loaded it, so BBR is
absent from `tcp_allowed_congestion_control`.

## What to change

Run setup once for each server, before its first deploy on this version:

```bash
dart run dartway_cli:dartway deploy setup --env <environment>
```

Setup is idempotent. If it has not run, the `deploy run` guard stops before replacing anything and
prints:

```text
BBR congestion control is not allowed on the server. Run `dart run dartway_cli:dartway deploy setup` once on this server, then deploy again.
```

With `--progress json`, the finished event instead carries `bbr-unavailable` as its reason.

## How to check

After the next `deploy run`, run
`dart run dartway_cli:dartway deploy check --env <environment>`. Confirm that
`[proxy-congestion-control] The front proxy uses BBR congestion control` passes and that the
`host-congestion-control` warning now passes too. In the app directory on the server, you can also
read the value checked in the running proxy directly:

```bash
docker compose exec -T nginx cat /proc/sys/net/ipv4/tcp_congestion_control
```

It prints `bbr`.
