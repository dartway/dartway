---
title: Proxy same-origin API paths through the Kamal web container
affects:
  dartway_cli: "0.25.0"
---

## Who is affected

A project that already generated and committed `deploy/kamal/` configuration.
The earlier API service combined TLS with path prefixes, which kamal-proxy
refuses, and its web image has no same-origin route to the API.

## What to change

Run `dartway deploy kamal` again and commit the refreshed destinations. Copy the
current template web Dockerfile, nginx configuration and
`docker-entrypoint.d/20-dartway-api-proxy.sh` integration into the project's web
package, preserving any project-specific additions. Rebuild and publish the web
image before deploying the generated destinations.

## How to check

Run `dartway deploy kamal --check`, deploy all generated services, then run
`dartway deploy check --env <environment>`. The app-host health request and live
WebSocket upgrade must both pass.
