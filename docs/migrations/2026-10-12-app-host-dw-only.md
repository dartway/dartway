---
title: Forward only /dw/ on the app host
affects:
  dartway_cli: "0.25.0-dev.0"
  dartway_core_server: "0.22.0-dev.0"
---

## Who is affected

Projects with generated Kamal destinations or a copied web proxy entrypoint,
and projects with custom app-host proxy configuration.

## What to change

Update the server package to the matching framework version. Run
`dartway deploy kamal` again and commit the refreshed destinations. Replace
the project's `docker-entrypoint.d/20-dartway-api-proxy.sh` with the current
template version, preserving any project-specific additions. If the app host
has a custom proxy, forward only `/dw/` to the API; serve `/health` and server
route paths as Flutter pages. Keep `/health` and server routes on the API host.

## How to check

Run `dartway deploy kamal --check` and `dartway deploy check --env
<environment>`. The app-host probe uses `/dw/health`; a Flutter deep link
whose path matches a server route must load the app.
