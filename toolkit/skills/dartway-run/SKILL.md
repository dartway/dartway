---
name: dartway-run
description: >-
  Bring a DartWay project up locally and confirm it is alive (DartWay projects): `dartway doctor`,
  Postgres (127.0.0.1:8090) and MinIO (8100, console 8101) from docker compose, `pg_isready` polled
  rather than slept on, the environment the server reads (DW_DATABASE_*, DW_STORAGE_*,
  DW_STORAGE_PROVISION, DW_ADMIN_IDENTIFIER asked from the human), `dart run bin/server.dart` in the
  background (it migrates as it starts), the dev seed, `/health` 200 reported as a fact, the sign-in
  code read from the server log, `flutter run`, and `dart run dartway_cli:dartway dev web` / `dart run dartway_cli:dartway dev proxy` for the
  browser. Diagnoses the typical failures: a startup exception listing problems, a request or
  command without a handler, a migration refusal or a schema check, the bucket probe, a busy port,
  SSL against local Postgres, 426 "update the app". Use when asked to "bring the project up", "run
  it", "why does it not start", "check that it works", and after a fresh clone.
---

# DartWay — bring the project up locally (`dartway-run`)

Your job is to get the project to "the server answers, the app opened, the user can sign in" and to
**report facts**, not assumptions: the `/health` status code, the migrations `status` shows applied,
the identifier to sign in with, the code you read from the server log.

Project packages: `__SHARED_PKG__` (the contract), `__SERVER_PKG__` (the server), `__FLUTTER_PKG__`
(the app). There is no configuration file: **the server is configured by its environment alone.**

---

## Before anything else

```bash
dartway doctor
```

It reports Dart, Flutter, git, a reachable pub host, a running Docker daemon and whether globally
activated executables are on PATH — with the exact fix for each. Exit code 1 means something below
will fail; relay what it names and ask the human rather than working around it.

- **Do not work around a stopped Docker.** Postgres and the object storage come from it, for
  development and for tests alike; there is no second path.
- **Take the pub host check seriously.** `pub get` has no deadline of its own: an unreachable host
  is not an error you can wait out, it is a command that prints one line and never returns.

## The order (it is not arbitrary)

```bash
cd __SERVER_PKG__
docker compose up -d
# poll until Postgres accepts connections — do not sleep a fixed time:
docker compose exec -T postgres pg_isready -U postgres
dart pub get
dart run bin/server.dart          # in the background; does not exit
dart run bin/seed_dev.dart        # once, after the server logged "listening"
```

```bash
cd __FLUTTER_PKG__
flutter pub get
flutter run                       # desktop, iOS simulator or Android emulator
```

### The environment

**Export nothing.** `bin/server.dart`, `bin/seed_dev.dart` and `bin/migrate.dart` call
`DwLocalEnvironment.overlay`, which reads `deploy/config.yaml > local` (committed: the coordinates
of the containers `docker compose up -d` started) and `deploy/secrets.yaml > local` (git-ignored:
what is this machine's own) into the environment before it is used. An exported variable still
beats both, which is how you override one value without editing a file.

Read what is set — and what the project declares it needs and is missing — with
`dartway secret list --env local`; add one with `dartway secret set <KEY> --env local`, which reads
the value from stdin. **Ask the human before putting any real key anywhere.**

The values that section holds, and what each is for:

| Variable | Local value | Why |
|---|---|---|
| `DW_DATABASE_HOST`, `DW_DATABASE_PORT` | `127.0.0.1`, `8090` | The compose Postgres |
| `DW_DATABASE_NAME`, `DW_DATABASE_USER`, `DW_DATABASE_PASSWORD` | from `docker-compose.yaml` (`postgres` user) | |
| `DW_DATABASE_SSL` | `false` | **SSL is on by default**; a local Postgres has none |
| `DW_STORAGE_ENDPOINT` | `http://127.0.0.1:8100` | The compose MinIO. Unset: the server runs without uploads |
| `DW_STORAGE_ACCESS_KEY`, `DW_STORAGE_SECRET_KEY` | the MinIO root user and password | |
| `DW_STORAGE_PROVISION` | `true` | Creates both buckets and sets their access before starting — for a storage the project owns, never for one somebody else administers |
| `DW_ADMIN_IDENTIFIER` | **ask the human** | A commented line in `local`, see below |
| `PORT` | `8080` (default) | |
| `DW_MIN_APP_BUILD`, `DW_ALLOWED_ORIGINS` | unset | See the failure table |

Everything else about storage (`dartway-uploads`) has development defaults in the skeleton.

### Why exactly this way

- **`docker compose up -d` starts Postgres and MinIO.** The first run pulls images and can take
  minutes; that is normal. There is no test database in compose: `dart run dartway_cli:dartway test` starts its own.
- **A container reported "Started" is not yet Postgres listening.** There are seconds between the
  two, and a server started in that window exits on "connection refused". Poll `pg_isready` until it
  succeeds.
- **The server migrates the database as it starts** — the framework's migrations, then the
  project's — and exits non-zero naming the problem when one fails or refuses. There is no separate
  migration step for bringing a project up; `dart run bin/migrate.dart status` (same `DW_DATABASE_*`)
  shows what is applied, and that is the fact to report. Changing the schema is `dartway-migrations`.
- **The first administrator is declared, not seeded.** The admin role is granted by an admin, so the
  very first one is named in `DW_ADMIN_IDENTIFIER` (a phone number or an e-mail) and made an admin on
  every start by the framework's `DwFirstAdministrator` startup step, before the port opens. **Ask the human which identifier to use, and never invent one**: whoever can receive
  the one-time code on it becomes the administrator. Left unset, the server still starts and warns
  that no administrator is declared — it postpones the admin panel, it blocks nothing. A value that
  is neither a phone nor an e-mail stops the server before it starts, on purpose.
- **The server is a long-running process.** Start it in the background and read its output; waiting
  "until the command completes" hangs the session until it is killed.
- **The seed runs once, after the first start** — it needs the migrated database, and refuses to run
  twice ("Already seeded."). It prints the accounts it made and the fixed code they sign in with.
  Development only: a fixed code is access to those accounts.

## Liveness check (mandatory — do not report success without it)

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health
```

Expect `200` (`ok`): the server is up **and** reached its database. `503` with
`database unavailable` means the process runs and Postgres went away; `503 stopping` — it is shutting
down. Use whatever HTTP client the platform has; the status code is the point.

Then read the server's own lines and report them:

- `DartWay server listening on port 8080`;
- `file storage buckets verified: …` when storage is configured, or the warning that
  `DW_STORAGE_ENDPOINT` is not set;
- one line about the administrator: ensured (created or promoted), already in place, or
  "No administrator is declared".

## Signing in

Nothing is sent over SMS or e-mail in development: **the one-time code is printed in the server
log**, as `Sign-in code for <identifier>: <code>`. Read the real one and pass it on — never invent a
code and never suggest "enter anything": the code is checked, and a wrong one counts against the
attempts. Signing in with the `DW_ADMIN_IDENTIFIER` identifier yields the administrator; any other
identifier signs up a regular member. Seeded accounts use the seed's fixed code.

A good first demonstration: the admin signed in in two windows, a change in the admin panel in one,
the other following without a reload — Postgres, a handler, a live channel and a widget, end to end.

## The app

- **Desktop and iOS simulator:** the app calls `http://localhost:8080`. **Android emulator:**
  `http://10.0.2.2:8080` — the skeleton's `main.dart` picks between the two unless
  `DW_BACKEND_URL` is defined. A **phone**
  reaches neither: build with `--dart-define=DW_BACKEND_URL=http://<the machine's LAN address>:8080`,
  and point `DW_STORAGE_ENDPOINT` at that address too, or uploads and photos will not reach storage
  (`dartway-uploads`).
- **In a browser the app calls its server on its own origin**, as the deployment serves it — there
  is no CORS to configure, and a browser app pointed straight at `:8080` from another origin fails.
  Serve both through the development proxy:

  ```bash
  cd __FLUTTER_PKG__
  dart run dartway_cli:dartway dev web                 # flutter's web server behind the proxy on http://localhost:8000; DW_BACKEND_URL set to it
  # or a release build:
  flutter build web --dart-define=DW_BACKEND_URL=http://localhost:8000
  dart run dartway_cli:dartway dev proxy --web-dir build/web
  ```

  Open `http://localhost:8000` exactly — to a browser `127.0.0.1` is another origin. A project door
  (`DwHttpRoute`) the browser must reach goes through with `--api-path /that-path`.

## Typical failures and what they mean

A server that refuses to start prints an unhandled exception and exits non-zero. **Read the whole
list it prints**: startup validation collects every problem at once, so the first line is rarely the
only one.

| Symptom | Cause | Action |
|---|---|---|
| `docker: command not found` / `Cannot connect to the Docker daemon` | Docker Desktop is not running | Ask the human to start it |
| `Invalid argument(s): database configuration: DW_DATABASE_HOST is not set; …` | The environment did not reach the process: the entry point was run from outside the project, or `deploy/config.yaml > local` has no such key | Run it from the project (the overlay looks for `deploy/config.yaml` above the working directory) and check `dartway secret list --env local` |
| `Connection refused` / `SocketException` on start | Postgres not accepting connections yet, or not on 8090 | `pg_isready` until it succeeds; `docker compose ps` |
| An SSL / TLS negotiation error against `127.0.0.1` | `DW_DATABASE_SSL` unset — SSL is on by default | `DW_DATABASE_SSL=false` locally |
| `DwStartupException: the server cannot start:` `- X is a registered request without a handler` (or `command`) | A request or command exists in the contract and no handler answers it | Write the handler and add it to the server's handler list (`dartway-server`). Deliberate: the alternative is a button that fails for the first user who presses it |
| `- the … handler answers X, which the protocol does not register` / `- X has more than one handler` | Generated registry stale, or a handler listed twice | `dart run dartway_cli:dartway generate`; remove the duplicate |
| `- channel kind "…" has more than one rule`, `- job "…" …`, `- route … is reserved by the framework`, `- upload purpose …` | The declaration is inconsistent | Fix what the line names |
| `DwMigrationRefused: refused to migrate:` `- … was edited after it was applied` / `is applied but no longer registered` / `is dirty` | The database's ledger and the code disagree — often a branch switch | `dartway-migrations`, "When the server refuses to start". Never "fix" it by editing the ledger without the human |
| `DwMigrationFailed: up of app/… failed: <postgres error>` | A migration ran and Postgres refused it | Read the SQL error; `dartway-migrations` |
| `- table "x" is declared in the schema and missing from the database: is its migration registered?` | A row class changed without a migration, or the migration is not in `migrations.dart` | `dart run bin/migrate.dart create <name>` (`dartway-migrations`) |
| `- file storage public bucket "…" does not exist at …` / `is not readable anonymously` / `is readable anonymously` / `lets anyone list its keys` | The bucket probe: the buckets are missing or not exactly as public as declared | Locally: `DW_STORAGE_PROVISION=true` and restart. On a storage someone else runs: fix its policy, never loosen the check |
| `- file storage … could not be checked at http://127.0.0.1:8100: …` | MinIO is not running, or unreachable | `docker compose up -d`; or unset `DW_STORAGE_ENDPOINT` to run without uploads |
| `SocketException: Failed to create server socket … Address already in use` (port 8080) | A server is already running — another terminal, a background run from earlier | Do not start a second one: `curl …/health`. Otherwise find the process holding the port |
| `port is already allocated` on `docker compose up` (8090 / 8100 / 8101) | Another project's containers or a leftover | `docker ps`; stop the conflicting container. DartWay projects share these development ports |
| `Invalid argument (DW_ADMIN_IDENTIFIER): is neither a phone number nor an e-mail address` | A mistyped administrator | Ask the human for the value again |
| The app shows "update the app" / calls answer `426` | `incompatible`: the build is below `DW_MIN_APP_BUILD` (`dw.updateRequired`), or the app and the server speak different protocol versions (`dw.protocolUnsupported`) — the app and the server resolve `dartway_core_*` versions that speak different protocols | Unset or lower `DW_MIN_APP_BUILD` locally; otherwise `dart pub get` in every package so the family resolves one version (`dartway-update`) |
| The browser app loads, and every call or the live socket fails | Opened on another origin than the proxy's, or `127.0.0.1` instead of `localhost` | `http://localhost:8000` through `dart run dartway_cli:dartway dev web` / `dev proxy`; `DW_ALLOWED_ORIGINS` only for a socket from a genuinely different origin |
| Uploads work on desktop and fail on an emulator or a phone; photos do not load there | The storage endpoint is `127.0.0.1`, which the device cannot reach, and it is signed into every URL | `DW_STORAGE_ENDPOINT` at an address the device reaches; restart the server |
| A widget or acceptance test fails to reach a database | Not a bring-up problem | `dartway-testing`: `dart run dartway_cli:dartway test` creates its own |
| The admin panel is not offered after signing in | Signed in with an identifier other than `DW_ADMIN_IDENTIFIER` | Fix the variable and restart: the promotion happens on start |

## What not to do

- **Never print secrets** — database passwords, storage keys, a delivered code meant for someone else,
  an upload URL — not while diagnosing, not to show what is configured. Name the variable instead.
- **Never delete the database volume without asking** (`docker compose down -v` destroys the data).
  It is a fair fix for a local database that drifted from its migrations; it is the human's call.
- **Do not fix an empty list by loosening an access rule.** An empty answer is most often a correctly
  working rule, and "who may read this" is a decision, not a bug.
- **Do not turn off a startup check to get the server up** (`DW_STORAGE_VERIFY_BUCKETS=false`, a
  handler removed from the contract) — each one refuses because serving would be worse.
- Do not propose "reinstall the dependencies" as the first step — read the error first.

## After a change

- **A DTO, a row class or a handler changed:** `dart run dartway_cli:dartway generate` in `__FLUTTER_PKG__`, then restart
  the server. A row class change also needs a migration — `dartway-migrations` — or the server refuses
  with the schema line above.
- **Before calling it done:** `dartway-finish`.
