---
title: Deploys start the new server beside the old one
affects:
  dartway_cli: "0.26.0-dev.1"
---

## Who is affected

Every project deployed with `dartway deploy run` (the Compose stack). Nothing in the project's code
changes; the next deploy changes the server, and two kinds of project files can stand in its way.

**What the first deploy with this CLI does on the server, once:**

- recreates the Postgres container, because it now starts with `pg_stat_statements` preloaded —
  a database restart of a few seconds while the previous server is still serving; then creates the
  extension and sets the slow-statement log (`slow_query_ms`, 500 ms by default);
- recreates the nginx container, because its log is now bounded (ten files of 50 MB) — the
  previous proxy log is dropped with it;
- still has the short gap of the old deploy at the server step: the proxy that is running then
  was started with the previous configuration, which resolved the server once. From the deploy
  after it, nothing is refused.

Plan the first deploy for a quiet moment. Every deploy after it replaces the server and the web app
beside the serving ones and reloads the proxy instead of restarting it.

## What to change

- **`deploy/compose.override.yml`** must not give `server` or `web` a `container_name` or
  published `ports`: two containers of the service run side by side during a deploy, and they
  cannot share either. `dartway deploy check --env <environment> --local`
  fails `override-side-by-side` when one is there. Remove it; the proxy reaches both services by
  name, and a route to the server belongs in `deploy/nginx.d`.
- **A snippet under `deploy/nginx.d/`** that proxies to a stack service by a literal name
  (`proxy_pass http://server:8080;`) keeps working, but resolves that name once per reload and so
  answers 502 for a few seconds of every deploy. Name it through a variable, as the rendered
  configuration does, so it follows the replacement:

  ```nginx
  set $dw_upstream server:8080;
  proxy_pass http://$dw_upstream;
  proxy_connect_timeout 1s;
  ```

- **Migrations** now run while the previous server still serves, so the previous code runs on the
  new schema for a few seconds of every deploy. This is the rule the migrations skill already
  holds a release to (expand, then contract; D-143); a release that drops, renames or tightens
  what the serving code still uses waits for the next one.

## How to check

After the second deploy with this CLI, run a request loop against the API host during a third,
and `dartway deploy stats --env <environment>`: every call counted, no 5xx
from the deploy's window, and the statements of `pg_stat_statements` listed.
