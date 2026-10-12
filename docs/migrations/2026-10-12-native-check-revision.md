---
title: Verify the selected native deployment revision
affects:
  dartway_cli: "0.25.0-dev.0"
---

## Who is affected

Projects using the native Kamal/Studio deployment contract. Compose-only projects
may record this note as not applicable. Optional call quotas require no adoption
by themselves.

## What to change

Wire the framework environment in the server entry point's `DwServerSettings`:

```dart
trustedProxyNetworks: env.server.trustedProxyNetworks,
behindProxy: env.server.httpBehindProxy,
deploymentVersion: env.server.deploymentVersion,
```

Declare `trusted_proxy_networks` with the actual `kamal` Docker network subnets in
each destination of `deploy/config.yaml`. Move any per-call nginx quota to
`callRateLimits`; native generation refuses remaining `deploy/nginx.d/*.conf`,
so review every policy before removing a snippet.

Run `dartway deploy kamal`, commit regenerated configurations and `deploy/studio.yml`.
The check runner must substitute `{version}` with the selected full commit SHA.
When invoking the check image directly, pass `--version <full SHA>` alongside
`--project` and `--env`. The worker remains outside-only and needs no SSH or Git.
Native Kamal supplies `KAMAL_VERSION` to the running API.

## How to check

Run `dartway deploy kamal --check`, then
`dartway deploy check --env <environment> --version <full SHA>`. Confirm native
identity, routing, ingress trust and outside checks pass. GET/HEAD API `/health`
and app `/dw/health` must report `ETag: "<full SHA>"`. Selecting a different SHA
must fail even while the old service returns 200. Data mount checks do not prove
data contents: a move from Compose still needs a backup restore proof.
