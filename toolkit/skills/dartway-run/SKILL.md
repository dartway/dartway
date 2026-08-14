---
name: dartway-run
description: >-
  Bring a DartWay project up locally and confirm it is alive (DartWay projects):
  dependencies, Postgres in docker, migrations, the first administrator, the server, the app.
  Knows the order of the steps (migrations before anything writes rows), the real ports
  (API 8080, development DB 8090, test DB 9090, object storage 8100 and its console 8101),
  where to find the sign-in code (printed in the server console) and how to fix the typical
  failures: docker not running, port already taken, schema drifted, model changed without
  serverpod generate, serverpod_cli version not matching the project, images not opening
  by link, upload failing on unconfigured storage.
  Use when asked to "bring the project up", "run it", "why does it not start",
  "check that it works", and also after a model change or a fresh git clone.
---

# DartWay — bring the project up locally (`dartway-run`)

Your job is to get the project to the state "the server responds, the app opened,
the user can sign in" and **report facts**, not assumptions: the API response code,
the applied migrations, the user name to sign in with.

Project packages: `__SERVER_PKG__` (backend), `__FLUTTER_PKG__` (app),
`__CLIENT_PKG__` (generated protocol — do not touch by hand).

---

## Before anything else

```bash
dartway doctor
```

It reports Dart, Flutter, a running Docker daemon, whether `serverpod_cli` matches this
project's pin, and whether globally activated executables are on PATH — with the exact fix
for each. Exit code 1 means something below will fail; relay what it names and ask the human
rather than working around it. Half the failure table further down is a problem doctor names
in a second.

## The order (it is not arbitrary)

```bash
cd __SERVER_PKG__
dart pub get                                              # ~12 s
docker compose up -d                                       # ~5 s
# wait until the DB is ready, do not sleep blindly:
#   docker exec <postgres-container> pg_isready -U postgres
dart bin/main.dart --apply-migrations --role maintenance    # ~18 s
# set bootstrapAdminIdentifier in config/passwords.yaml (see below)
dart bin/main.dart                                          # the server, does not exit
```

```bash
cd __FLUTTER_PKG__
flutter pub get     # ~18 s
flutter run
```

**Why exactly this way:**

- **The first administrator is declared, not seeded.** The database comes up empty and anyone can register from the app, but the admin role is granted by an admin — so the first one is named in `config/passwords.yaml` under `bootstrapAdminIdentifier`, and `bootstrapAdmin` in `lib/src/app/` brings that identifier to "profile exists, role is admin" on every boot. **Ask the user to fill that key in before the server starts, and never invent a value** — whoever receives the one-time code on that identifier becomes the administrator, so it is theirs to choose. You cannot do it for them: reading `config/passwords.yaml` is denied in this project's settings, and that denial is the point. Say which key, which run-mode block, and what the value means. Left empty the server starts anyway and says on boot that the admin panel is out of reach — so this never blocks bringing the project up, it only postpones the admin panel.
- **Migrations before anything writes rows**, and **after `docker compose up`** and **after the DB is ready.** A container that is "Started"
  ≠ Postgres accepting connections; there are seconds between them, and a migration in that window fails
  with connection refused. Wait for `pg_isready`, not for a `sleep`.
- **Storage comes up with the same `docker compose up`.** Alongside Postgres it brings up `minio` (S3 for uploads) and a one-shot `minio_init`, which creates the bucket and opens it for reading — without that, uploaded images will not open by link.
- **The server is a long-running process.** Start it in the background and do not wait for it to finish:
  waiting "until the command completes" will hang you forever.

## Liveness check (mandatory — do not report success without it)

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/     # expect 200
```

The server prints the applied migrations and one line about the administrator — created, promoted,
or "no administrator is declared". Read that line and report which of the three it was.

The database is empty on a fresh clone, so the user registers in the app rather than signing in to
something that already exists. **The one-time code is printed in the server console** — find it
there and pass it on; do not invent a code and do not suggest "enter anything". Registering with the
identifier from `bootstrapAdminIdentifier` yields the admin; any other number yields a regular user.

## Typical failures and what to do

| Symptom | Cause | Action |
|---|---|---|
| `docker: command not found` / `cannot connect to the Docker daemon` | Docker Desktop is not running | Ask to start Docker; do not try to bring Postgres up another way |
| The first `docker compose up` hangs for minutes | The `postgres:16` image is being pulled | This is normal, wait it out; next time `docker pull postgres:16` in advance |
| `connection refused` during migrations | The DB is not accepting connections yet | Wait for `pg_isready`, retry |
| `port is already allocated` (8090/9090/8100) | Taken by another project or a leftover container | `docker ps` → stop the conflicting container. **8090 is a frequent collision** between DartWay projects |
| Images do not load, the link returns 404 | The bucket was not created or is closed for reading | Check the `minio_init` logs (`docker compose logs minio_init`): they must say "Bucket created" and "set to `download`". A public link of the form `http://localhost:8100/uploads/<file>` must open in a browser |
| Upload fails with "Cloud storage is not configured" | No `dwCloudStorage*` keys for this run mode | Add them to `config/passwords.yaml` (in development they point at the `minio` service) |
| `Missing password for "database"` on a fresh clone | `config/passwords.yaml` is not in Git and never was — `dartway create` wrote it on the machine the project was created on | `cp __SERVER_PKG__/config/passwords.yaml.example __SERVER_PKG__/config/passwords.yaml`. The example carries working development values; ask a teammate only for keys a deployed environment needs |
| `Address already in use` on 8080 | The server is already running in another terminal | Do not start a second one; check `curl localhost:8080` |
| A migration does not apply, complaining about a schema mismatch | The DB survived a model change | For local development the simplest fix is to recreate it: `docker compose down -v` (**deletes the data**) → `up -d` → migrations → restart the server. Ask for confirmation before destroying the volume. Registered accounts go with the volume; the administrator comes back on the next boot, everyone else registers again |
| The admin panel is not in the navigation after signing in | The account is a regular user | `bootstrapAdminIdentifier` is unset, or it does not match the identifier that registered. The comparison is case-insensitive but otherwise exact — no country-code guessing. Fix the key and restart the server: the promotion happens on boot |
| The client does not see a new model field | Generation was not run after editing `.spy.yaml` | `serverpod generate`, then `serverpod create-migration`, then `dart format` over both generated paths, then apply the migrations ("After a model change" below) |
| Generation rewrote dozens of files the task never touched | The generator's `dart_style` is not the project's, and `create-migration` regenerates | Run `dart format` over both generated paths **after** `create-migration`, not before ("After a model change" below) |
| Strange generation/protocol errors | The `serverpod_cli` version drifted from the `serverpod` pin in the project's pubspec | Compare `dart pub global list` with the version in `__SERVER_PKG__/pubspec.yaml`; the generator must match the runtime |
| `Default Objects Repository doesn't contain a model of type X` | The new model has no registered default instance | Add `dw.repo.setupRepository(defaultModel: X(...))` in `__FLUTTER_PKG__/lib/core/default_models.dart` |
| The API answers `notConfigured` | The model has no `DwCrudConfig`, or it is not registered | Create the config and add it to `crudConfigurations` (skill `dartway-crud-config`) |

## What not to do

- **Do not print the contents of `config/passwords.yaml`** or other secrets into the chat — neither
  while diagnosing, nor "just to show". If you need a fact from it, say which key is missing.
- **Do not fix an "empty list" by loosening access.** An empty response from a read config is
  most often a correctly working `accessFilter`, not a bug. Access not configured ⇒
  forbidden — this is a deliberate rule of the framework.
- **Do not delete the data volume without confirmation** (`docker compose down -v`).
- Do not propose "reinstall the dependencies" as the first step — read the error first.

## After a model change

The full cycle if the user changed a `.spy.yaml`:

```bash
cd __SERVER_PKG__
serverpod generate           # ~24 s — updates the server's generated code and __CLIENT_PKG__
serverpod create-migration   # ~6 s  — a new migration in migrations/; regenerates as well
dart format lib/src/generated ../__CLIENT_PKG__/lib/src/protocol   # ~1 s — must come last
dart bin/main.dart --apply-migrations --role maintenance
```

**The formatting step is not optional, and its position is not free.** The generator formats its
output with the `dart_style` bundled with the Serverpod CLI, not with the `dart format` of the
project's SDK, so every generation rewrites files the change never touched — a single nullable field
has produced a 29-file, 1900-line diff. And `create-migration` runs the generation again to diff the
schema, so formatting placed before it is silently undone. Generate, migrate, then format — once, in
that order, over **both** packages. `git diff --stat` afterwards should name only the models you
touched; if it names more, one of the two rules above was broken.

Then: a `DwCrudConfig` for the new model + registration in `crudConfigurations`,
a default instance in `default_models.dart`, and only after that the screen.
