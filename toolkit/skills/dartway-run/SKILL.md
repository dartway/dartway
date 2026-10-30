---
name: dartway-run
description: "Bring up the local project or deploy it; verify services, ports, credentials and health."
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
dart run bin/seed_dev.dart   # once, after "listening" (a second run refuses): dev accounts, their fixed code
cd ../__FLUTTER_PKG__ && flutter pub get && flutter run
```

**Export nothing.** The entry points overlay `deploy/config.yaml > local` (committed: the containers'
coordinates — Postgres `127.0.0.1:8090` with `DW_DATABASE_SSL=false`, RustFS `127.0.0.1:8100`,
`DW_STORAGE_PROVISION=true`) and `deploy/secrets.yaml > local` (git-ignored, never read by you); an
exported variable wins over both. `dartway secret list --env local` shows what is set and missing
(`localSecretMissing` warns on a declared secret with no local value; `devComposeDrifted` on compose
credentials that no longer match); `dartway secret set <KEY> --env local` reads a value from stdin —
ask the human before putting any real key anywhere. With `interactive: false` in
`.agents/dartway-toolkit.json`, report the required key/setup decision and stop that step.
The same applies to an invalid identifier or Docker not running; continue independent checks.

**`DW_ADMIN_IDENTIFIER` is asked from the human, never invented**: whoever receives codes on it becomes
the administrator (`DwFirstAdministrator`, every start). Unset, the server starts and warns; a value
that is neither a phone nor an e-mail stops it — ask the human again.

## Liveness — mandatory

`curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health` → `200` means up **and** reached
the database (`503` — the database went away, or stopping). Then report the log's lines: `listening on
port 8080`, the buckets verified (or storage not configured), the administrator ensured or not declared.

**Signing in**: no SMS or e-mail in development — the code is in the server log (`Sign-in code for
<identifier>: <code>`). Pass the real one on; never invent one. The admin identifier signs in as admin;
seeded accounts use the seed's fixed code.

**The app**: desktop and iOS simulator call `http://localhost:8080`, an Android emulator
`http://10.0.2.2:8080`; a phone needs `--dart-define=DW_BACKEND_URL=http://<LAN address>:8080`, and
storage an address the device reaches (`dartway-uploads` §4). **In a browser** the app calls its own
origin: `dartway dev web` (or a release build served by
`dartway dev proxy --web-dir build/web`), opened at exactly `http://localhost:8000`;
a `DwHttpRoute` the browser must reach goes through with `--api-path /that-path`. `DW_ALLOWED_ORIGINS`
only for a socket from a genuinely different origin.

## When it does not start

The server prints every problem at once — read the whole list.

| Symptom | Action |
|---|---|
| Docker not running | ask the human |
| `DW_DATABASE_HOST is not set` | run from the project, where the overlay finds `deploy/config.yaml` |
| `Connection refused` on start | `pg_isready` until it succeeds |
| an SSL error against `127.0.0.1` | `DW_DATABASE_SSL=false` locally |
| `X is a registered request without a handler` | write the handler (`dartway-server`) |
| `answers X, which the protocol does not register` | `dartway generate` |
| `X has more than one handler` | remove the duplicate |
| `DwMigrationRefused` / `DwMigrationFailed` / `table "x" … missing` | `dartway-migrations`; never edit the ledger |
| a bucket missing or wrongly readable; storage `could not be checked` | `dartway-uploads` §4 |
| port 8080 in use | a server already runs — `curl …/health` before starting another |
| `port is already allocated` on compose | another project's containers: `docker ps` |
| the app shows "update the app" (`426`) | regenerate and rebuild the app; one family version everywhere (`dartway-update`) |
| browser calls fail | open `http://localhost:8000` through `dev web`/`dev proxy` |
| no admin panel after sign-in | signed in with another identifier than `DW_ADMIN_IDENTIFIER` |

Read the error before proposing to reinstall dependencies. Never print a secret, a code delivered for
someone else or a signed upload URL; never delete the database volume without asking; never fix an empty list by
loosening an access rule; never switch off a startup check to get the server up. After a DTO, row
class or handler change: generate and restart; before calling it done: `dartway-finish`.

## Kamal deployment files

For a project moving to Studio's Kamal deploy contract, configure `staging` and/or
`production` in `deploy/config.yaml`, resolve `__FLUTTER_PKG__` and run
`dartway deploy kamal` there. Commit the generated configs,
Studio manifest and Images workflow; publication follows the configured
deployments' `branch:` values after successful `CI` (PR builds do not push).
Enable CI pushes on those branches. Install the workflow on the default branch
before its `workflow_run` trigger can run. CI checks `deploy kamal --check` next
to generation whenever a Studio manifest is present. The template ships no
pre-generated deployment files or Images workflow. The manifest declares
`__SERVER_PKG__/lib/src/migrations/**` and `__SERVER_PKG__/pubspec.lock` as migration
paths relative to the repository root. Images supplies the workflow run number
as Docker's `BUILD_NUMBER` argument; Compose deploys use the checked-out
commit's Unix timestamp, fixed per revision.
The web Dockerfile passes it to Flutter's `--build-number` and defaults to `0`
only for direct local Docker builds. Existing SHA images are
skipped and keep their first build number. For an existing project, regenerate
the deployment files and add the argument to its project-owned web Dockerfile
as described in the framework repository's
[migration note](https://github.com/dartway/dartway/blob/master/docs/migrations/2026-10-18-studio-migrations-and-build-number.md).
Project HTTP routes are reached on the API host. The app host forwards only
`/dw/`, so route changes do not affect generated Kamal web configuration or
reserve Flutter page paths. Routes match exact paths, with no `:id` parameters.
`requires.files` mounts individually delivered files read-only into the API at
`/run/secrets/<name>`. Use `dartway secret put-file <path> --name <name> --env
<environment>` before the first boot and for rotation. Commit the generated
executable `deploy/kamal/hooks/api/pre-app-boot`; its check uses Kamal's SSH
settings and refuses missing, empty, symlinked or insecurely permissioned files
before every boot group. Do not pass `--skip_hooks`. The store directory is mode
700, files 400 or 600 with the same owner. A serving container keeps its old file;
the next boot, including image rollback, reads the currently delivered file.
Generation and CI never deliver secret contents; Studio must deliver files and
preserve these hooks. A deployed `site:` is still refused; use `deploy run`.
Invalid project names are refused
with the value and the `project:` key to configure. Web release builds without a define call
`Uri.base.origin`; they need no backend build argument. The Studio binding uses
`STUDIO_APP_ORIGIN` when defined and otherwise the app's own origin in a web
release; debug/profile preview without the define stays open. Studio owns running
Kamal, SSH keys, registry credentials and secrets. Existing Compose deployments
continue using `deploy run` until their project's separate move.

`deploy run` starts the new server and web app beside the serving ones and
stops the old ones after their replacement is healthy, so a deploy answers no
request with an error; migrations run first, while the previous version serves,
so they only expand (`dartway-migrations`). An override never gives `server` or
`web` a `container_name` or published `ports` (`override-side-by-side`). A
`deploy/nginx.d` snippet proxying to a stack service names it through a
variable so it follows the replacement too:
`set $dw_upstream server:8080; proxy_pass http://$dw_upstream;`.
How fast a deployed environment answers:
`dartway deploy stats --env <environment> [--hours 24] [--top 10]`
— p50/p95 per call from the proxy log,
the costliest statements of `pg_stat_statements`, slow statements over
`slow_query_ms` (`deploy/config.yaml`, 500 by default). A call slower than
`DwServerSettings.slowCallThreshold` (1 s) is a server warning with its name.
