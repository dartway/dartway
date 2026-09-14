# DartwayStarter

A fullstack app on [DartWay](https://dartway.dev): a Dart server and a Flutter
app that speak one contract.

- `dartway_starter_shared` — the contract: data objects, requests, commands,
  live channels, refusal codes, and the rules both sides apply identically
  (pure Dart, generated codecs in `*.dw.dart`)
- `dartway_starter_server` — row classes, handlers, access and channel rules,
  upload rules, migrations, the dev seed
- `dartway_starter_flutter` — the app: screens on `dw.request` / `dw.table` /
  `dw.command`, navigation, the UI kit

What is already here: sign-in by a one-time code to a phone number **or** an
e-mail, with the terms accepted on sign-up; a profile with a name, a photo
(uploaded straight to object storage) and the sign-in identifiers, each added
or changed by a code; roles; an admin panel with live counters, a members
table (search, role filter, pages), a card per member with a live role change,
and app settings; the "update the app" screen; widget tests on an in-memory
server and acceptance tests on a real one. Zero domain models — yours go next.

## Getting started

Open the project in whatever AI assistant you use and ask it to bring the
project up: `dartway quickstart` prints everything it needs to know, and
`dartway doctor` says whether this machine is ready for it. By hand:

```bash
cd dartway_starter_server
docker compose up -d          # Postgres on 8090, MinIO on 8100 (console 8101)

export DW_DATABASE_HOST=127.0.0.1 DW_DATABASE_PORT=8090 \
       DW_DATABASE_NAME=dartway_starter DW_DATABASE_USER=postgres \
       DW_DATABASE_PASSWORD=dartway_dev_pw DW_DATABASE_SSL=false \
       DW_STORAGE_ENDPOINT=http://127.0.0.1:8100 \
       DW_STORAGE_ACCESS_KEY=dartway_dev DW_STORAGE_SECRET_KEY=dartway_dev_storage_pw \
       DW_STORAGE_PROVISION=true \
       APP_BOOTSTRAP_ADMIN=you@example.com

dart pub get
dart run bin/server.dart      # applies the migrations, serves :8080
dart run bin/seed_dev.dart    # once, in another terminal with the same DW_DATABASE_*
```

`DW_STORAGE_PROVISION=true` creates the two buckets and sets their access on
the first start. Without `DW_STORAGE_*` the server runs without uploads.

The app, in another terminal:

```bash
cd dartway_starter_flutter
flutter pub get
flutter run                   # mobile or desktop: http://localhost:8080 (10.0.2.2 on Android)
```

In a browser the app calls its server on its own origin, as the deployment
serves it — no CORS anywhere. Build it for that origin and serve both through
the development proxy:

```bash
cd dartway_starter_flutter
flutter build web --dart-define=DW_BACKEND_URL=http://localhost:8000
dart run dartway_cli:dartway dev proxy --web-dir build/web   # open http://localhost:8000
# or, with hot restart: dart run dartway_cli:dartway dev web
```

**Signing in.** Nothing is sent over SMS or e-mail in development: the code is
printed in the server log (`Sign-in code for …`). The seeded accounts sign in
with the code **111111**: the admin **79990000001**, the members
**79990000002** and **boris@example.com**. `APP_BOOTSTRAP_ADMIN` makes the
phone or e-mail it names an administrator on every start — whoever receives
its codes is the admin, so there is no default. A real delivery goes into
`deliverCode` in `dartway_starter_server/lib/src/auth.dart`.

## Build a feature

1. **Contract** — in `dartway_starter_shared/lib/src/`, a data object
   (`extends DwDataObject`), the requests that read it (`DwSingleRequest`,
   `DwListRequest`, `DwTableRequest`, …) with the channels they live on, and
   the commands that change it (`DwActionCommand`, `DwSelfValidating` for
   field rules both sides check).
2. **Server** — a row class in `lib/src/entities/` (`@DwSqlTable`), a handler
   per request and command in `lib/src/handlers/` with its access rule,
   publishing what a command changed to the channels that show it.
3. `dartway generate` — codecs, the protocol registry, tables and the schema.
4. `dart run bin/migrate.dart create <name>` (with `DW_DATABASE_*` set) — a
   migration from the row classes; review it, it is yours.
5. **App** — a screen with `ref.watch(dw.request(MyRequest()))`, a button with
   `dw.action((_) => dw.command(MyCommand()))`, the texts in `lib/l10n/`.

The `.claude/` toolkit guides an AI assistant through the same steps.

## Checks and tests

```bash
dartway generate --check                                  # generated code is up to date
(cd dartway_starter_server && dart run bin/migrate.dart check)   # migrations produce the schema (DW_DATABASE_*)
dartway test                                              # server acceptance, real Postgres and MinIO
(cd dartway_starter_shared && dart test)                  # the contract
(cd dartway_starter_flutter && flutter test)              # the app on an in-memory server
dartway check                                             # the conventions
```

`dartway test` starts a Postgres and a MinIO for the run, on ports Docker
picks, and removes them when it ends: nothing is shared with the development
containers or with another project, and nothing survives. Each test file
creates its own database and its own buckets.

## Deploy

`deploy/README.md`: one server process configured by its environment, the web
app on its own host with `/dw/` proxied to the server, Postgres and optional
MinIO — `dartway deploy setup`, then `dartway deploy`.

## Continuous integration

`.github/workflows/claude-review.yml` runs a Claude review on every pull request
and posts findings as inline comments. It needs one repository secret,
`CLAUDE_CODE_OAUTH_TOKEN` (generate it with `claude setup-token`); without it the
job fails. Delete the file to turn PR review off.
