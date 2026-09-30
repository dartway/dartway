---
name: dartway-run
description: >-
  Bring a DartWay project up locally and prove it is alive: dartway doctor, Postgres and RustFS from
  docker compose (pg_isready polled), the environment from deploy/config.yaml > local
  (DW_ADMIN_IDENTIFIER asked from the human), the server in the background, the dev seed, /health 200
  reported as a fact, the sign-in code from the log, flutter run and dev web / dev proxy, and the
  typical startup failures. Use for "bring the project up", "run it", "why does it not start", after
  a fresh clone.
---

# DartWay — bring the project up locally (`dartway-run`)

Get to "the server answers, the app opened, the user can sign in" and **report facts**: the `/health`
status, the migrations `status` shows, the identifier to sign in with, the code read from the log.

`dartway doctor` first: it names what is missing (Dart, Flutter, git, the pub host, Docker) with the fix.
A failure there is the human's to fix — never work around a stopped Docker; an unreachable pub host makes
`pub get` hang, not fail.

```bash
cd __SERVER_PKG__
docker compose up -d
docker compose exec -T postgres pg_isready -U postgres   # poll until it succeeds; "Started" is not "listening"
dart pub get
dart run bin/server.dart     # in the background: it never exits; it migrates as it starts
dart run bin/seed_dev.dart   # once, after "listening": development accounts and their fixed code
cd ../__FLUTTER_PKG__ && flutter pub get && flutter run
```

**Export nothing.** The entry points overlay `deploy/config.yaml > local` (committed: the containers'
coordinates — Postgres `127.0.0.1:8090` with `DW_DATABASE_SSL=false`, RustFS `127.0.0.1:8100`,
`DW_STORAGE_PROVISION=true`) and `deploy/secrets.yaml > local` (git-ignored, never read by you); an
exported variable wins over both. `dartway secret list --env local` shows what is set and missing
(`localSecretMissing` warns on a declared secret with no local value; `devComposeDrifted` on compose
credentials that no longer match); `dartway secret set <KEY> --env local` reads a value from stdin —
ask the human before putting any real key anywhere.

**`DW_ADMIN_IDENTIFIER` is asked from the human, never invented**: whoever receives codes on it becomes
the administrator (`DwFirstAdministrator`, every start). Unset, the server starts and warns.

## Liveness — mandatory

`curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health` → `200` means up **and** reached
the database (`503` — the database went away, or stopping). Then report the log's lines: `listening on
port 8080`, the buckets verified (or storage not configured), the administrator ensured or not declared.

**Signing in**: no SMS or e-mail in development — the code is in the server log (`Sign-in code for
<identifier>: <code>`). Pass the real one on; never invent one. The admin identifier signs in as admin;
seeded accounts use the seed's fixed code.

**The app**: desktop and iOS simulator call `http://localhost:8080`, an Android emulator
`http://10.0.2.2:8080`; a phone needs `--dart-define=DW_BACKEND_URL=http://<LAN address>:8080` and
`DW_STORAGE_ENDPOINT` at that address too. **In a browser** the app calls its own origin:
`dart run dartway_cli:dartway dev web` (or a release build served by
`dart run dartway_cli:dartway dev proxy --web-dir build/web`), opened at exactly `http://localhost:8000`.

## When it does not start

The server prints every problem at once — read the whole list.

| Symptom | Action |
|---|---|
| Docker not running | ask the human |
| `DW_DATABASE_HOST is not set` | run from the project, where the overlay finds `deploy/config.yaml` |
| `Connection refused` on start | `pg_isready` until it succeeds |
| an SSL error against `127.0.0.1` | `DW_DATABASE_SSL=false` locally |
| `X is a registered request without a handler` | write the handler (`dartway-server`) |
| `answers X, which the protocol does not register` | `dart run dartway_cli:dartway generate` |
| `DwMigrationRefused` / `DwMigrationFailed` / `table "x" … missing` | `dartway-migrations`; never edit the ledger |
| a bucket missing, or readable when it should not be | locally `DW_STORAGE_PROVISION=true` and restart; elsewhere fix the policy, never the probe |
| storage `could not be checked` | `docker compose up -d`, or unset `DW_STORAGE_ENDPOINT` |
| port 8080 in use | a server already runs — `curl …/health` before starting another |
| `port is already allocated` on compose | another project's containers: `docker ps` |
| the app shows "update the app" (`426`) | regenerate and rebuild the app; one family version everywhere (`dartway-update`) |
| browser calls fail | open `http://localhost:8000` through `dev web`/`dev proxy` |
| uploads fail on a device | `DW_STORAGE_ENDPOINT` at an address the device reaches |
| no admin panel after sign-in | signed in with another identifier than `DW_ADMIN_IDENTIFIER` |

Never print a secret; never delete the database volume without asking; never fix an empty list by
loosening an access rule; never switch off a startup check to get the server up. After a DTO, row
class or handler change: generate and restart; before calling it done: `dartway-finish`.
