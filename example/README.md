# DartWay example — a fitness club

A complete application built on [DartWay](https://dartway.dev) (Flutter + Serverpod): sessions,
bookings, coaches, an admin panel, roles, uploads, real-time lists. Three packages:

- `dartway_example_server` — Serverpod backend (models, CRUD configs, logic)
- `dartway_example_flutter` — Flutter app (features, UI kit, navigation)
- `dartway_example_client` — generated API client (**do not edit by hand**)

**This is a reference to read and run, not a project to inherit.** Starting your own app from it
means deleting somebody else's fitness club before writing yours — `dartway create` exists for
that and hands you a skeleton with no domain in it. Read this one to see what a finished DartWay
app looks like: how a `DwCrudConfig` replaces an endpoint, how a feature declares its own spec, how
the UI kit stays the only source of styles.

## Running it

The three packages depend on the framework from pub.dev, so they run outside this monorepo. Copy
them somewhere, then **delete the `dependency_overrides:` block from each of the three
`pubspec.yaml` files** — inside the monorepo those overrides point at sibling folders so the
example builds against the framework's working copy, and in a standalone checkout they lead
nowhere.

```bash
# backend
cd dartway_example_server
dart pub get
docker compose up -d                                       # Postgres on 8090, MinIO on 8100
dart bin/main.dart --apply-migrations --role maintenance    # apply the schema
dart bin/seed_dev.dart --mode development                   # seed the club and its people
dart bin/main.dart                                          # run the server
```

```bash
# app — in another terminal
cd dartway_example_flutter
flutter pub get
flutter run
```

Sign in as **79990000003** (a client), **79990000002** (a coach) or **79990000001** (the admin).
There are no passwords: the one-time code is printed in the server console.

`dartway doctor` says whether this machine has what any of it needs — Dart, Flutter, git, a pub
host that answers, a responding Docker daemon, a `serverpod_cli` matching the pin.

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

The suites commit real transactions (`RollbackDatabase.disabled`) and wipe the
auth tables around themselves, which makes them stateful neighbours rather than
isolated units: run in parallel they wipe each other's rows mid-test. Files
therefore run one at a time — pinned in `dart_test.yaml`, not left to whoever
remembers a flag.
