# DartWay example — a fitness club

A complete application on DartWay 1.0 (fullstack Dart): a schedule with live
spots, bookings and reviews, club news, a staff chat, an admin panel with a
members table, roles and settings. Three packages:

- `dartway_example_shared` — the contract: data objects, requests, commands,
  channels and refusal codes, with their generated codecs and registry
- `dartway_example_server` — row classes, handlers, access and channel rules,
  migrations, the dev seed (`dartway_core_server`)
- `dartway_example_flutter` — the app: screens on `dw.request` / `dw.table` /
  `dw.window` / `dw.command`, the UI kit, navigation (`dartway_core_flutter`)

**This is a reference to read and run, not a project to inherit.** Starting
your own app from it means deleting somebody else's fitness club before
writing yours — `dartway create` exists for that.

## How it talks

Every request and command is `POST /dw/<Name>` with the DTO's JSON as the
body; the answer is an `ApiResponse` whose `updates` carry what the command
changed that this client listens to. A WebSocket (`/dw/live`) is opened only
while something on screen is live, and brings other people's changes. Booking
a spot therefore updates your own schedule and bookings from the answer, and
everyone else's schedule over their socket.

## Running it

Inside this monorepo the packages build against the framework's working copy
through `dependency_overrides`; copied out, delete those blocks.

```bash
# the database: any Postgres; the variables below point the server at it
export DW_DATABASE_HOST=127.0.0.1 DW_DATABASE_PORT=5432 DW_DATABASE_NAME=club \
       DW_DATABASE_USER=club DW_DATABASE_PASSWORD=club DW_DATABASE_SSL=false

cd dartway_example_server
dart pub get
dart run bin/server.dart          # applies the migrations, serves :8080
dart run bin/seed_dev.dart        # in another terminal, once
```

```bash
cd dartway_example_flutter
flutter pub get
flutter run                       # http://localhost:8080, or 10.0.2.2 on Android
```

Sign in as **79990000003** (a client), **79990000002** or **79990000004**
(staff) or **79990000001** (the admin), with the code **111111**. Other
phones get a code printed in the server log.

A browser app calls its server on the same origin (`/dw/` proxied next to the
web build, as the deploy does), so the web build names that origin:
`flutter build web --dart-define=DW_BACKEND_URL=https://app.example.com`.
The server's `DW_ALLOWED_ORIGINS` lists further hosts allowed to open the live
socket, and `DW_MIN_APP_BUILD` the oldest app build it still serves.

## Code generation and migrations

```bash
cd dartway_example_server
dart run dartway_generator --project ..       # codecs, registry, schema
dart run bin/migrate.dart create <name>       # a migration from the row classes
dart run bin/migrate.dart check               # migrations produce the schema
```

## Tests

```bash
cd dartway_example_shared && dart test        # the contract
cd dartway_example_server && dart test        # acceptance, real server + Postgres (DW_DATABASE_* names a maintenance database)
cd dartway_example_flutter && flutter test    # the app against the in-memory DwFakeServer
```
