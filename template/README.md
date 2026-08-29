# DartwayStarter

A fullstack app built with [DartWay](https://dartway.dev) (Flutter + Serverpod):

- `dartway_starter_server` — Serverpod backend (models, CRUD configs, logic)
- `dartway_starter_flutter` — Flutter app (features, UI kit, navigation)
- `dartway_starter_client` — generated API client (**do not edit by hand**)
- `dartway_starter_shared` — rules that must hold identically on both sides; pure Dart, no dependencies

## Getting started

Open the project in whatever AI assistant you use and ask it to bring the project
up. `dartway quickstart` prints everything it needs to know — the order of the
steps, the ports, the verification, how to hand you the sign-in — and
`dartway doctor` says whether this machine is ready for any of it.

Or press **F5** in VS Code — launch **Server**, then **Flutter (web)**
(configured in `.vscode/launch.json`).

Or do it by hand, from the terminal:

```bash
# backend
cd dartway_starter_server
dart pub get
docker compose up -d                               # Postgres
dart bin/main.dart --apply-migrations --role maintenance   # apply the schema
dart bin/main.dart                                  # run the server
```

```bash
# app — in another terminal
cd dartway_starter_flutter
flutter pub get
flutter run
```

The database starts empty: register from the app with any phone number, and the
one-time code is printed in the server console — in development nothing is sent
over SMS.

**To reach the admin panel**, put your own identifier in
`bootstrapAdminIdentifier` in `dartway_starter_server/config/passwords.yaml`
before starting the server. The role is granted by an admin, so the first one is
declared per environment instead of coming from nowhere; the server prints what
it did on boot, and says so when the key is empty. Register with that same
identifier and you are in.

## Build a feature

Everything an app needs — auth, roles, an admin panel, a live list from the
database — is already here. Add your domain on top: a model (`.spy.yaml`) →
`serverpod generate` → a `DwCrudConfig` → a screen with `ref.watch(dw.repo.modelList())`.
No endpoints to write. The `.claude/` toolkit guides an AI assistant through it.

## Tests

The server carries DartWay's integration suites: the auth limits — attempt caps,
code expiry, request rate limiting, single-use access tokens — and password
hashing, including the migration of a legacy hash on the user's next sign-in.
They run against a real database, because that is the only place the guarantees
hold: the limits are enforced with database locks, a race cannot be observed in
a rolled-back transaction, and neither can a hash that must actually be written.

```bash
dartway test                  # from the project root
```

`dartway test` creates the database this run needs, on a port Docker picks, and
removes it when the run ends. Nothing is shared and nothing survives, so two
projects — or two runs of this one — cannot reach each other's rows, and a row
written by yesterday's run cannot turn up in today's assertions. The coordinates
reach the suite as `SERVERPOD_DATABASE_*`, which Serverpod reads over
`config/test.yaml`. `docker compose up -d` is still what the development
database and object storage need; it no longer has anything to do with tests.

The app has widget tests of its own, and those need nothing running:

```bash
cd dartway_starter_flutter
flutter test
```

The suites commit real transactions (`RollbackDatabase.disabled`) and wipe the
auth tables around themselves, which makes them stateful neighbours rather than
isolated units: run in parallel they wipe each other's rows mid-test. Files
therefore run one at a time — pinned in `dart_test.yaml`, not left to whoever
remembers a flag.

## Continuous integration

`.github/workflows/claude-review.yml` runs a Claude review on every pull request
and posts findings as inline comments. It needs one repository secret,
`CLAUDE_CODE_OAUTH_TOKEN` (generate it with `claude setup-token`); without it the
job fails. Delete the file to turn PR review off.
