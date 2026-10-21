---
name: dartway-server
description: "Change server feature layout, rows, queries, handlers, jobs, routes, auth hooks, startup and services."
---

# DartWay — the server (`__SERVER_PKG__`)

A `DwAppServer`: the contract's calls, each answered by one handler that says who may make it and what
it does; no endpoints, no generic CRUD. Access rules — `dartway-access`; what to publish — 
`dartway-realtime`; schema changes — `dartway-migrations`; files — `dartway-uploads`.

New generated data objects are additive when `__SHARED_PKG__/pubspec.yaml`'s `version:` is above
the trusted contract base (a patch is enough). Generate records their introduction as `since`;
the server filters their publications and deletions from response and live updates to older builds.
Publishing remains dynamic server code; no channel list or manual filtering is needed. Existing
shape changes still require a breaking-line raise (`dartway-contract`).

Open only the reference needed for the edit:

- [layout.md](references/layout.md) — feature files and cross-feature boundaries.
- [rows-and-queries.md](references/rows-and-queries.md) — row declarations, lifecycle state columns and typed queries; open `dartway-migrations` when rows change.
- [handlers.md](references/handlers.md) — handlers, transactions, batch mapping and call context.
- [jobs-and-routes.md](references/jobs-and-routes.md) — jobs and external doors.
- [accounts.md](references/accounts.md) — sign-in hooks, accounts and identities.
- [startup-and-services.md](references/startup-and-services.md) — startup, settings, environment, outbound HTTP and ingress quotas.

Open related references when the change reaches them, not all before the first edit.
