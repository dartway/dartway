# DartwayStarter

A fullstack app built with [DartWay](https://dartway.dev) (Flutter + Serverpod):

- `dartway_starter_server` — Serverpod backend (models, CRUD configs, logic)
- `dartway_starter_flutter` — Flutter app (features, UI kit, navigation)
- `dartway_starter_client` — generated API client (**do not edit by hand**)

## Getting started

Open the project in VS Code and press **F5** — launch **Server**, then **Seed dev
data**, then **Flutter (web)** (configured in `.vscode/launch.json`).

Or from the terminal:

```bash
# backend
cd dartway_starter_server
dart pub get
docker compose up -d                               # Postgres
dart bin/main.dart --apply-migrations --role maintenance   # apply the schema
dart bin/seed_dev.dart --mode development           # seed an admin + a user
dart bin/main.dart                                  # run the server
```

```bash
# app — in another terminal
cd dartway_starter_flutter
flutter pub get
flutter run
```

Sign in as the seeded user **79990000003** — the one-time code is printed in the
server console. (The admin is **79990000001**.)

## Build a feature

Everything an app needs — auth, roles, an admin panel, a live list from the
database — is already here. Add your domain on top: a model (`.spy.yaml`) →
`serverpod generate` → a `DwCrudConfig` → a screen with `ref.watchModelList`.
No endpoints to write. The `.claude/` toolkit guides an AI assistant through it.

## Tests

The server carries DartWay's integration suites: the auth limits — attempt caps,
code expiry, request rate limiting, single-use access tokens — and password
hashing, including the migration of a legacy hash on the user's next sign-in.
They run against a real database, because that is the only place the guarantees
hold: the limits are enforced with database locks, a race cannot be observed in
a rolled-back transaction, and neither can a hash that must actually be written.

```bash
cd dartway_starter_server
docker compose up -d          # dev database on 8090, test database on 9090
dart test
```

The suites commit real transactions (`RollbackDatabase.disabled`) and wipe the
auth tables around themselves, which makes them stateful neighbours rather than
isolated units: run in parallel they wipe each other's rows mid-test. Files
therefore run one at a time — pinned in `dart_test.yaml`, not left to whoever
remembers a flag.
