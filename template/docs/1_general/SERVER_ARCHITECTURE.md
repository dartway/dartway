# Server architecture

`dartway_starter_server` follows the DartWay server model:

- **CRUD-first** — all logic goes through `DwCrudConfig` in `lib/src/crud/`, not
  ad-hoc endpoints.
- **Domain-first models** in `lib/src/models/` (`.spy.yaml` → `serverpod generate`).
- **Secure by default** — a model with no config is not reachable; access is
  granted via `accessFilter`, never forgotten.
- Phone auth on the app's own `UserProfile`; roles in `UserRole` (user / admin).

The full contract is in `.claude/CLAUDE.md` and the `dartway-crud-config` /
`dartway-models` skills. Record server decisions specific to this project here
as they arise.
