# How is a DartWay project deployed?

With four subcommands and one file, onto one Linux server running Docker. There are no deploy
scripts in a project and no reason to write any: provisioning, rendering, the secret store,
restarts and verification belong to the framework.

```bash
cd <project>_flutter
# deploy/config.yaml already describes "local"; add a deployment beside it

dart run dartway_cli:dartway deploy check --env staging --local            # the working copy only
dart run dartway_cli:dartway deploy setup --env staging                    # provision the server, render the stack
dartway secret set SMS_API_TOKEN --env staging        # what cannot be generated
dart run dartway_cli:dartway deploy check --env staging                    # DNS, the server, the deployed hosts
dart run dartway_cli:dartway deploy run   --env staging                    # update, build, start, verify
```

Every subcommand takes `--env <environment>` and refuses to guess without it, naming the
environments `deploy/config.yaml` declares. Every one that connects takes `--as <login>` (default:
`ssh_user` from the config) and `--identity <key file>` (default: your SSH agent). The code is
`packages/dartway_cli/lib/src/commands/deploy_*.dart`, `secret_commands.dart` and
`packages/dartway_cli/lib/src/deploy/`.

## One file describes an environment

`deploy/config.yaml` holds one environment per top-level key, plus two keys that belong to the
project rather than to one of its machines: `requires` (below) and `local`, which is what a
developer's own machine starts a server with and is not a deployment at all — see
[Secrets](#secrets). **The server has no configuration file of its own** — it is configured by its
environment, which the deploy derives from this file (database coordinates, storage, port) and from
the secret store on the server (passwords, keys). Nothing writes `config.yaml`; the deploy only
reads it.

| Key | Required | Meaning |
|---|---|---|
| `host` | yes | The server's address |
| `ssh_user` | yes | Login for provisioning — root, or a user with passwordless sudo |
| `deploy_user` | no | The unprivileged user that owns the checkout and runs the stack; defaults to `dw_admin` |
| `os` | yes | The server's operating system (`ubuntu`) |
| `repo`, `branch` | yes | The repository the server checks out, and the branch it deploys |
| `ssl_email` | yes | Where Let's Encrypt writes about expiring certificates |
| `api_domain` | yes | The server, for mobile apps and webhooks |
| `app_domain` | yes | The Flutter web app |
| `site` | no | `domain` and `source`: a directory of the repository served as static files, or `none` for a site that lives elsewhere |
| `database` | no | `bundled` or `external`; absent means `bundled` — a Postgres container in the stack |
| `storage` | no | `bundled` or `external`; absent means no file storage |
| `storage_domain` | with `bundled` | The public host of the bundled storage; refused without `storage: bundled` |
| `registry_mirror` | no | Pull the official Docker Hub images of the stack (`postgres`, `nginx`) through a mirror such as `mirror.gcr.io`; the bundled storage and certbot come from where they live |
| `firewall_ports` | no | TCP ports to open beyond SSH, 80 and 443 |
| `requires.secrets` | no | Secrets nobody can generate, as environment variable names |
| `requires.files` | no | Secret documents, by file name, mounted into the server |

`requires` is also read at the **top level** of the file, where it states what the project needs
wherever it runs; an environment's own `requires` adds to it. Declaring it once is the point: the
same list repeated per environment drifts in the one direction nobody notices, and the environment
that was forgotten is the one whose deploy stops.

The file is validated as it is read, **every problem at once**, and an unknown key is one of them: a
key the deploy does not read is a setting somebody believes is in force. Every domain must be a host
name, and each role needs a host of its own — Nginx routes by `server_name`, so two roles on one host
means one of them is never reached.

Names are derived, not configured. The project name is the last segment of `repo` without `.git`;
the checkout is `/home/<deploy_user>/<project>`. With `database: bundled`, the database and its role
are named after the server package without `_server`; with `database: external` they are a managed
provider's own, delivered as `DW_DATABASE_NAME`/`DW_DATABASE_USER` — there is nothing to derive them
from. The storage buckets are named after the same prefix with dashes.

A cloud image can already carry a system group named like `deploy_user` — DigitalOcean's Ubuntu
24.04 image ships an empty `admin` group, for instance (#328). Setup reuses that group when the
user does not exist yet, unless the group is one a sudoers rule already grants privileges to
(`%admin` on Ubuntu's stock sudoers; `%sudo` on both Debian's and Ubuntu's): joining one of those
would hand the "unprivileged" deploy user a path to root, so setup refuses instead and asks for a
`deploy_user` that does not collide with it. Setting `deploy_user: admin` explicitly still hits
this refusal on a host whose stock `admin` group exists — that guard is not what fixes #328. What
does is the default: `dw_admin` is fixed rather than derived from the project, because no stock
image or package ships a group under the `dw_` prefix, so an operator who does not set
`deploy_user` never meets this collision at all.

## Three hosts, one server process

```
app.example.com   →  the web image;  /dw/ (the live socket included) and /health → the server
api.example.com   →  everything → the server
example.com       →  the site directory, static            (optional)
files.example.com →  the bundled storage                    (with storage: bundled)
```

**The app calls its own origin.** On the app host the front Nginx serves the web image and
sends `/dw/`, `/dw/live` and `/health` to the server, so a browser makes same-origin calls: no CORS,
no preflight, and the server answers none. The web build is given that origin as
`DW_BACKEND_URL`. The api host proxies everything to the server — calls, the live socket, and the
project's own doors (`DwHttpRoute`) such as a webhook. The server serves no static files. Local
development has the same shape through `dart run dartway_cli:dartway dev` ([The CLI](cli.md)).

**Storage has a host of its own because a presigned URL signs its host.** Browsers upload to the
bundled storage directly (see [Uploads](../4-server/uploads.md)); a storage hidden behind the app's origin would be
a different host from the one the URL was signed for. Inside the stack's network that host is an
alias of the proxy, so the server reaches storage by the very URL a browser uses — no second address
to configure.

The rendered Nginx:

- port 80 answers only the ACME challenge and redirects everything else to HTTPS;
- **one certificate covers every served host**, named after `api_domain`;
- `Host` is passed through as `$http_host`, port included — the live socket admits a browser whose
  `Origin` is the host the upgrade was sent to;
- `/dw/live` gets `proxy_read_timeout 1h` and no buffering; the server pings every 20 seconds by
  default, so the timeout only ends a dead connection;
- request bodies on the app and api hosts are limited to `16m` — above the server's own default of
  1 MiB, so
  the server's refusal (which a client reads) comes first rather than an Nginx HTML page; the storage
  host has no limit and streams the body, since the presigned URL bounds the size;
- `deploy/nginx.d/{http,api,app}/*.conf` are included — at the `http` level, in the app host, and
  inside the api host's `location /`.

## The stack

`setup` renders `docker-compose.yml` into the checkout. The services:

| Service | What it is |
|---|---|
| `postgres` | With `database: bundled`: `postgres:17-alpine`, on the volume `postgres_data`, with a `pg_isready` healthcheck. Absent with `database: external` — no service, no volume, no `depends_on` on it |
| `server` | Built from `<project>_server/Dockerfile` with the project root as context. Secrets through `env_file: .env`; `PORT=8080` always, and with `database: bundled` (and, with the bundled storage, `DW_STORAGE_*`) `DW_DATABASE_*` in the compose file too — with `database: external` none of `DW_DATABASE_*` is rendered at all, all five (`HOST`, `PORT`, `NAME`, `USER`, `PASSWORD`) come from `.env` like any other secret. Exposed to the network only. `stop_grace_period: 45s`; healthcheck `GET /health` with a 600-second start period, because migrations run before the port opens |
| `web` | Built from `<project>_flutter/Dockerfile` with the build argument `DW_BACKEND_URL` = the app origin |
| `storage`, `storage-init` | With `storage: bundled`: RustFS, and a one-shot job (a generic S3 client) that creates and configures both buckets on every deploy |
| `nginx` | `nginx:1.30.5-alpine` (pinned, raised with the framework) on 80 and 443 |
| `certbot` | Renews the certificate every 12 hours |

**Data-bearing images are pinned** — Postgres to its major, the storage to an exact release — so a
deploy on a later day cannot move a data directory under a binary that refuses it. The stateless
proxy and certbot follow upstream. Values in the compose file that the deploy derives win over the
same names in `.env`, which is why the secret store refuses those names — and why it accepts
`DW_DATABASE_*` only with `database: external`, where the compose file no longer sets them.

`deploy/compose.override.yml` is where a project adds what a standard deployment does not have. It is
**never copied**: every Compose call the CLI issues names it from the checkout
(`docker compose -f docker-compose.yml -f deploy/compose.override.yml …`), so `git reset --hard` on a
deploy refreshes it. For the command a person types by hand on the server, the deploy writes
`docker-compose.override.yml` as a two-line `include:` of the committed override, marked
`dartway-bridge` — otherwise a bare `docker compose up -d` applies a strictly smaller stack and exits
0. A file under that name without the marker is moved to `docker-compose.override.yml.retired`; with
no override in the checkout and a foreign file in its place, the deploy refuses, because that file
may be the only place its services are declared.

## Database: bundled or someone else's

**`database: bundled`** (the default) is the `postgres` service above — a container on the stack's own
volume, reached over the private network, no TLS. **`database: external`** points at a managed
Postgres instead: DigitalOcean Managed Postgres, RDS, Cloud SQL, or any Postgres somebody else runs.
Nothing about it is rendered — no service, no volume, no `depends_on` — and the server reaches it
exactly as it would reach any database named by its own environment. Deliver with `dartway secret
set --env <environment>`:

| Secret | Required | Meaning |
|---|---|---|
| `DW_DATABASE_HOST` | yes | The provider's host |
| `DW_DATABASE_PORT` | yes | Its port — a managed provider rarely uses 5432 |
| `DW_DATABASE_NAME` | yes | The database name it assigned |
| `DW_DATABASE_USER` | yes | The role it assigned |
| `DW_DATABASE_PASSWORD` | yes | Its password — never generated here; it is the provider's credential |
| `DW_DATABASE_SSL` | no, default `true` | `false` only for a database that genuinely speaks no TLS |
| `DW_DATABASE_MAX_CONNECTIONS` | no, default 10 | The pool ceiling — managed plans often cap total connections in the tens, so raising this without checking the plan's limit starves every other client of the same database |

`deploy check` gains `database-reachable` (below): on the deployment host over SSH, because a
managed provider's firewall usually trusts that host's address and not the maintainer's — a
throwaway, pinned Postgres client (never built or run otherwise with `database: external`) attempts a
real connection with the same `sslmode` the server itself will use (`require` unless `DW_DATABASE_SSL`
is explicitly `false`, which asks for `disable`), and reports why when it fails (a malformed stored
value, DNS, refused, a timeout, authentication, or the server not offering TLS). A bare TCP probe
would pass while the password or the certificate is still wrong. `DW_DATABASE_PORT`, `_SSL` and
`_MAX_CONNECTIONS` are validated exactly as the server parses them — a positive integer, and `true`
or `false` — before anything connects, so a value that would crash the server at startup is a check
failure naming it, not a pass.

`sslmode=verify-full` with the provider's CA file — closing the one gap `require` leaves, a network
position presenting its own certificate unchallenged — is not built yet: dartway/dartway#342.

An existing config with no `database` key keeps deploying `bundled`, exactly as before.

### DigitalOcean Managed Postgres

- **Connect on the direct port, not the connection pooler.** DigitalOcean publishes two ports: the
  direct one (usually `25060`) and PgBouncer in transaction mode (usually `25061`). **Use the direct
  port** — `DW_DATABASE_PORT: 25060`. The framework needs a session, not a transaction: the server
  holds a session-scoped `LISTEN` for live updates (`DwPostgresDatabase`), takes a session
  `pg_advisory_lock` while migrating (`DwMigrationRunner`) so two servers never migrate at once, and
  caches prepared statements per connection. Behind a transaction-mode pooler `LISTEN` silently
  delivers nothing (no error, no update — a class of bug that surfaces as "the app doesn't refresh"
  weeks later), the migration lock does not hold across the pool's own transactions, and prepared
  statements are meaningless once a "connection" is a new backend on every transaction.
- The database name is usually `defaultdb` (`DW_DATABASE_NAME`), the default user `doadmin` or a role
  created for this project (`DW_DATABASE_USER`).
- Add the droplet's address as a **trusted source** in the database's firewall — that is what
  `database-reachable` needs already admitted before it can report anything but a timeout.

### Sizing connections

One server process holds `DW_DATABASE_MAX_CONNECTIONS` (default 10) plus one more for the session
`LISTEN` above — so a plan's usable connection count has to clear `MAX_CONNECTIONS + 1`, not just
`MAX_CONNECTIONS`. DigitalOcean's smallest Managed Postgres plan allows on the order of 22 usable
connections in total (the rest are the provider's own); size `DW_DATABASE_MAX_CONNECTIONS` to what the
plan actually grants this one server, with room for a second server during a deploy's brief overlap
and anything else that connects (a migration run, `psql` by hand).

### Switching an existing environment from bundled to external

Moves no data. The server that starts against the newly declared external database starts on an
empty one — its migrations create the schema, not the rows a bundled Postgres was holding. Move the
data yourself first (a `pg_dump`/`pg_restore` between the two, out of scope here) before pointing
`deploy/config.yaml` at the external one. A deploy's own rollback — starting the previous server image
again after a failure — uses whatever `.env` the store renders at the time, which after the switch is
the external database's, not the bundled one's: there is no bundled Postgres left running to fall back
to once the config has moved.

## Storage: bundled or someone else's

Two buckets, whatever the option (D-038b): a **public** one whose objects anyone reads and whose
listing nobody gets, and a **private** one that reads nothing unsigned. A rule's visibility picks
the bucket.

**`storage: bundled`** runs RustFS in the stack. `storage-init` (a generic, pinned S3 client) creates
`<prefix>-public` and `<prefix>-private` (keeping existing buckets and their objects), sets the public
bucket's policy to anonymous `s3:GetObject` only — never a canned ACL, which would also grant
listing — clears any policy on the private one, sets bucket CORS admitting the app origin on both
(what a browser's presigned `PUT` needs), and writes a probe object into both. The server receives
`DW_STORAGE_ENDPOINT` (the storage host), both bucket names,
`DW_STORAGE_PUBLIC_BASE_URL=https://<storage_domain>/<prefix>-public`, path-style addressing and
**`DW_STORAGE_VERIFY_BUCKETS=false`**: the server reaches the storage only through the proxy, and the
proxy starts after the server, so the bucket check a server normally runs at startup cannot run there.
The outside probe runs the same check once the stack is up. `DW_STORAGE_ACCESS_KEY` and
`DW_STORAGE_SECRET_KEY` are generated into the secret store.

**`storage: external`** is an S3-compatible storage somebody else runs. Deliver
`DW_STORAGE_ENDPOINT`, `DW_STORAGE_ACCESS_KEY`, `DW_STORAGE_SECRET_KEY` and the buckets your rules
need (`DW_STORAGE_PUBLIC_BUCKET` with `DW_STORAGE_PUBLIC_BASE_URL`, `DW_STORAGE_PRIVATE_BUCKET`) with
`secret set`. The bucket check stays on: the server refuses to start on a missing bucket, a private
bucket anyone can read, or a public one nobody can.

## `setup` — provision a server and render its stack

`setup` is the only subcommand that writes infrastructure. In order:

1. **Root privileges** — root, or passwordless sudo; an unreachable host is not reported as a
   privilege problem.
2. **Base packages and Docker**, installed only where Docker is missing.
3. **The deployment user**, created if absent and added to the `docker` group.
4. **The secret store**, with the secrets that are only random strings generated in place: with
   `database: bundled`, `DW_DATABASE_PASSWORD`; and with the bundled storage, the storage keys. An
   external database's `DW_DATABASE_*` are never generated — they are the provider's own credentials,
   delivered with `secret set`. Existing values are never replaced — regenerating the database
   password would lock the server out of a database initialised with the old one.
5. **A repository key**, for a `git@` repository: generated **on** the server, so the private half
   exists nowhere else. When the server cannot yet reach the repository, setup stops and prints the
   public key, asking for it to be registered as a **read-only** deploy key — the server only ever
   fetches, and a writable key turns access to the box into access to the repository.
6. **The checkout** of `branch`.
7. **`.env`** with the generated secrets — what the compose file itself interpolates.
8. **A data volume guard**: if the server already has a data volume of this project and an expected
   one is missing — a config change renamed or replaced what a volume held — setup refuses. Compose
   would otherwise create that volume empty and serve it beside the real data, silently. `run` runs
   the same guard (below) right before it starts anything, because a server is not always `setup`
   again after a config change.
9. **`docker-compose.yml`, `nginx.conf`**, the `nginx.d` directories, the override bridge and the
   project's Nginx snippets, then `docker compose config --quiet` over the result.
10. **The firewall**: `ufw` (installed when absent), OpenSSH, 80, 443 and `firewall_ports`.
11. **A one-day self-signed certificate**, so Nginx can start at all — the real one cannot be issued
    until Nginx answers the challenge, and the first `run` issues it.

It ends by naming the required secrets still to deliver. **Idempotent throughout**: every step finds
what it needs or creates it, so re-running `setup` against a live server is the supported way to pick
up a change to the rendered files. `--dry-run` prints the rendered `docker-compose.yml` and
`nginx.conf`, the snippets it would upload and the secrets it would generate, and touches nothing.

## `run` — deploy

First `run` evaluates the working-copy checks of `deploy check` and refuses on any error, pointing at
`dart run dartway_cli:dartway deploy check --local` for the detail. Then:

1. updates the checkout to `origin/<branch>` with `git reset --hard` — the server mirrors the
   repository, and a stray edit on the box must not block a deploy (skipped with `--skip-git-update`);
2. writes the override bridge;
3. **renders `docker-compose.yml` and `nginx.conf`** from `deploy/config.yaml` and this version of
   the CLI, and says of each whether it changed. Both are derived files, and a derived file written
   once goes stale in silence: a CLI that had learnt to pass a new build argument met a compose file
   rendered before that argument existed, and the deploy died inside `docker build` blaming the
   project's Dockerfile — while the file to fix was on the server and in no repository. The write
   goes through `cat >`, never a rename, because the proxy has its configuration bind-mounted;
4. renders `.env` from the secret store, refusing — by key name and line number, never by value —
   when the store is absent, a line is malformed, a key is declared twice, a key is one the compose
   file sets, or a required secret is missing or empty;
5. checks the merged Compose configuration;
6. **the same data volume guard `setup` runs** (above): refuses when an expected data volume of the
   rendered stack does not exist while another data volume of this project does — the shape of a
   config change (a rename, a different storage backend) about to serve fresh data next to the real
   one. One implementation, run from both commands;
7. builds the images;
8. with the bundled storage, starts it and runs `storage-init`, printing what it did; with `database:
   bundled`, starts Postgres — with `database: external` there is nothing of the database's to start,
   the server reaches it directly;
9. **replaces the server, one version at a time.** The serving server stops gracefully — calls in
   flight are answered, live sockets close with "server stopping" — and from then on the proxy
   answers `502`, which the app's client retries for up to 30 seconds (a command keeps its
   idempotency key, so a retry never runs it twice). The new image applies the migrations in a
   one-off run that serves nothing and takes no jobs (`DW_MIGRATE_ONLY=true`), then the new server
   starts and has to become healthy. The gap is the stop, the migrations and the start: seconds
   for a routine deploy, as long as a migration takes for a heavy one. **No two versions ever run
   at once**: old code never writes into a new schema, never claims a job only the new code
   declares. When the migrations fail (they roll back) or the new server does not become healthy,
   the image that was serving is started again and the step fails with the server's own log; after
   a failure past the migrations the previous code runs on the new schema, and the message says so;
10. replaces the web app, and converges the rest of the stack (`up -d --remove-orphans`);
11. **checks the Nginx upstreams against the applied stack** — `docker compose config --services` on
   the server — and runs `nginx -t` inside the running proxy. Nginx resolves an upstream once, when it
   starts, so a snippet naming a service the stack does not have fails at the next proxy restart; this
   stops the deploy before that restart;
12. issues the certificate for every served host under one name — only when certbot does not already
   manage it, or when a host was added to the configuration since (a storage domain, a site): then
   the lineage is extended with `--expand`. A routine deploy stays off the rate limit. A host added
   to a live server needs `setup` first, so that nginx answers the ACME challenge for it;
13. restarts Nginx and checks it is still running afterwards: `restart` exits 0 for a proxy that dies
    a second later on its configuration.

What keeps a push routine is not that the rendering is skipped but that it is idempotent and
reported: a run that changes nothing says "unchanged" for both files. Everything else infrastructural
— users, directories, the secret store, the firewall, the first certificate — is still `setup` alone.
`--dry-run` prints the plan and the probes, and executes nothing.


### A step outlives the connection that started it

Every step runs on the server **detached from the `ssh` session**: its script is written to
`~/.config/<project>/deploy-run/` of the deploy user and started in a session of its own
(`setsid`), streams to files, exit code written last. The call that starts a step waits for it, so a
routine deploy still makes one connection per step; when that connection breaks, fresh ones wait for
the same step for up to fifteen minutes, and past that `run` stops waiting and says the step is still
running. Nothing the invoking machine does — losing its network, or dying because it is a container
of the stack whose server step 7 replaces — stops a step midway.

That covers deploying from inside the stack being deployed (DartWay Studio deploying itself), but the
steps after the interruption still need someone to run them: **`dart run dartway_cli:dartway deploy run --env <env>
--resume`**. It reads the record of the last deployment on the server and, in that deployment's
plan, passes over the steps that finished, waits for a step still running instead of starting it a
second time, judges again from its output a finished step whose success is checked beyond its exit
code (the upstream check), and runs everything from the first step that actually runs — then the
services and the probes, as always. A step that ended badly in the deployment being resumed is **not** run again: the resume stops with
that step's reason and the output the server kept, because a self-deploy resumes after every
interruption and a failing step would otherwise be repeated until the attempts ran out — each time
stopping the server it had just started again. `--retry-failed` with `--resume` runs it once more
(against the checkout that deployment updated to); after fixing code, deploy anew rather than
resume.

A new `run` starts a new record, says where the previous deployment stopped if it did not finish,
and refuses while a step of it is still running — two deployments never interleave on one server.

### Progress for a program

`--progress json` writes one JSON object per line on stdout and moves the prose to stderr. A program
reads the events; the prose may change wording at any time, the events may not.

| `event` | Fields |
|---|---|
| `notice` | `message` — what the server said about the previous deployment |
| `plan` | `steps` (`id`, `title`) — `--dry-run` only |
| `run_started` | `environment`, `resume`, `steps` (`id`, `title`) |
| `revision` | `commit` (full hash), `subject` — after the checkout update, or before the steps when there is none |
| `step_skipped` | `index`, `count`, `id` — done by the deployment being resumed |
| `step_started` | `index`, `count`, `id`, `title`, `picked_up` — waiting for a step already on the server |
| `step_finished` | `index`, `count`, `id`, `exit_code`; `stdout`, `stderr` for a step whose output is its result |
| `step_failed` | `index`, `count`, `id`, `reason` (`exit`, `verdict`, `busy`); `exit_code`, `stdout`, `stderr` or `message`; `resumed: true` when the step failed in the deployment being resumed and was not run again |
| `services` | `services` (`name`, `status`) |
| `probe` | `title`, `passed`, `detail` |
| `run_finished` | `ok`, `exit_code`; `failed_step`, or `reason` (`checks`, `nothing-to-resume`, `unreachable`, `verification`) |

**Then it verifies from outside**, as a browser and an app would, retrying failed probes up to twelve
times five seconds apart:

- `GET /health` answers `200` `ok` through the api host and through the app host;
- `GET /` on the app host is the Flutter `index.html`, served with a revalidating cache policy, and
  the build's entry points are not served for reuse without revalidation;
- `/dw/live` upgrades through both hosts (from the app origin on the app host) and the server speaks
  on the socket;
- where declared: the site answers `200 text/html`; the storage preflight admits a `PUT` from the app
  origin with the headers a presigned upload is bound to; the probe object reads anonymously from the
  public bucket and not from the private one, and neither bucket lists its keys.

A deploy whose probes fail exits `1` and names what was observed.

## `check` — would a deployment work?

`check` changes nothing. It prints the environment it resolved, then asserts over the working copy
and over the network. Exit `1` on any error; warnings and skipped checks do not fail it. `--local`
skips DNS, the server and the deployed hosts — the form that needs no SSH key and no host yet.

| Id | Level | Asks |
|---|---|---|
| `secret-names` | error | `requires.secrets` names nothing the compose file sets itself |
| `stack-names` | error | The project prefix makes a valid database name and bucket names |
| `site-source` | error | The site directory holds an `index.html` committed to Git — the server has only what Git has |
| `docker-context` | warning | A `.dockerignore` exists at the build context root |
| `dockerfiles-present` | error | Both `<project>_server/Dockerfile` and `<project>_flutter/Dockerfile` exist |
| `docker-context-packages` | error | Each image copies every package it depends on, and `.dockerignore` admits it — a missing one fails as `pub get` exit code 66, three layers from the cause |
| `dependencies-inside-context` | error | No image resolves a package by a path outside the project — the context is the project root, so `pub get` in the image cannot find it though every checkout resolves. `pubspec_overrides.yaml` counts unless `.dockerignore` keeps it out. The usual cause is an unpublished framework taken from a local checkout: depend on it by git with a pinned ref instead |
| `server-signals` | error | The server image's `ENTRYPOINT` (or `CMD`) is in exec form, so the binary is PID 1 and receives the SIGTERM a deploy sends; under `/bin/sh -c` it is killed mid-call when the grace period runs out |
| `web-backend-url` | error | The web Dockerfile declares `ARG DW_BACKEND_URL` — Docker silently drops an undeclared build argument |
| `locked-dependencies` | error | Every image's `pub get` runs `--enforce-lockfile`, and the package has a committed `pubspec.lock` — otherwise pub may resolve a different set inside the container than the project was tested with, and a deploy has already failed that way |
| `web-flutter-version` | error | The web image builds on the Flutter `.fvmrc` names — it installs it from `.fvmrc`, or its Flutter image carries that tag. Flutter pins some packages an app resolves, so a lock written on one Flutter fails `--enforce-lockfile` on another |
| `web-file-modes` | warning | The web image grants everyone read on the files it serves (`chmod -R a+rX build/web`). `COPY` keeps modes, and under a deploy user's umask of `077` the files a commit adds are served as 403 while every page answers 200 |
| `web-cache-policy` | warning | The web image's Nginx configuration revalidates every Flutter entry point |
| `nginx-upstreams` | error | Every `proxy_pass` in the rendered Nginx and in `deploy/nginx.d/` names a service of the stack or the override |
| `override-web-build` | warning | `deploy/compose.override.yml` does not rebuild `web` — that would name the API address a second time, and nothing compares the copies |
| `local-secrets-untracked` | error | `deploy/secrets.yaml` is not tracked by Git |
| `local-secrets-cover-environment` | warning | `deploy/secrets.yaml` holds every required secret for the environment (reported by `check` only; `run` does not evaluate it) |
| `dns-public-hosts` | error | Every served host resolves to the deployment host — a mismatch otherwise burns the Let's Encrypt rate limit |
| `images-resolve` | error | Every pinned base image (nginx, certbot, Postgres with `database: bundled`, and with `storage: bundled` the storage and its init image), resolved through `registry_mirror` exactly as the renderer resolves them into the compose file — against its own registry, a manifest HEAD with the anonymous token the registry's challenge asks for, so a vanished tag is caught here rather than mid-`run`, at the step that starts it. A transient answer (no route, a timeout, a rate limit, a registry's own 5xx) is a skip, not a failure: this machine's network is not a fact about the image |
| `ssh-reachable` | error | Key-based SSH works; when it fails the other server checks are skipped |
| `deploy-user` | error | The deployment user exists |
| `docker-available` | error | Docker Compose is usable by the deployment user |
| `runtime-secrets` | error | Every required secret is in the server store with a value, and nothing reserved is |
| `secret-files` | error | Every `requires.files` entry is delivered **and** mounted into the server container, read from the configuration Compose will actually run |
| `database-reachable` | error | With `database: external`: `DW_DATABASE_PORT`/`_SSL`/`_MAX_CONNECTIONS` are validated exactly as the server parses them, then a throwaway, pinned Postgres client on the deployment host connects to the stored coordinates with the same `sslmode` the server will use and runs a query — a real authenticated, encrypted connection, not a bare TCP probe. A failure names why: a malformed stored value, DNS, refused, a timeout, authentication, or the server not offering TLS. Skipped with `database: bundled` |
| `secrets-match-local` | warning | The server store and `deploy/secrets.yaml` hold the same key names |
| `outside` | error | The same outside probes `run` ends with, against whatever is deployed now; runs even when SSH fails |

## Images

`dartway create` gives a project both Dockerfiles, the web image's `nginx.conf` and a
`.dockerignore`; `deploy check` holds them to the rules above.

- **The server image** builds from the project root (it needs the shared package beside the server),
  copies the shared and server packages by name, compiles `bin/server.dart` with `dart compile exe`,
  and runs the binary on Alpine with `ca-certificates` — without them every outbound HTTPS call from
  the server fails — and `ENTRYPOINT ["/app/server"]` in exec form.
- **The web image** builds with Flutter from the project root, takes `ARG DW_BACKEND_URL` (and refuses
  to build without it) and `ARG STUDIO_APP_ORIGIN` (the same address, for the Studio binding's access
  check; an app without the binding declares no such ARG and Docker drops it), runs `flutter build web --release --dart-define=DW_BACKEND_URL=…`, and serves
  the build with `nginx:1.30.5-alpine` and `<project>_flutter/nginx.conf`. It serves files only.
- **`.dockerignore` denies everything** and admits the packages by role suffix (`*_server/`,
  `*_flutter/`, `*_shared/`), minus build output and `.env` — so the working copy's history, build
  output and local secrets never reach the Docker daemon.

**What the web image lets a browser keep fails silently.** A Flutter web build hashes nothing:
`index.html`, `flutter_bootstrap.js`, `main.dart.js` and everything under `assets/` carry the same
names in every build. The familiar "cache for a year" rule lands on exactly the files that change on
every deploy, and a browser holding one under a long `max-age` keeps running the previous build with
nothing on either side to report it. So `nginx.conf` serves everything with `Cache-Control: no-cache`
and an `ETag` (a `304`, not a download) and keeps the long-lived, immutable rule for names that carry
a content hash. `web-cache-policy` reads that configuration; the outside probe asks the deployed site.
**Fixing it does not reach a browser that already holds a copy** — tell whoever you can reach to
hard-reload.

## Secrets

### `local`: this machine

`local` is an environment like any other in these two files, and the only one with no machine to
reach: `deploy/config.yaml > local` holds what the team shares — the coordinates of the development
containers — and `deploy/secrets.yaml > local` holds what is the developer's own. The project's
entry points read both through `DwLocalEnvironment` (`dartway_core_server`), in that order, and a
real environment variable beats them. A deployed server reads neither: `.dockerignore` admits only
the packages into a build context, so `deploy/` never enters an image, and the runtime stage holds
nothing but the compiled binary.

```bash
dartway secret list --env local             # both halves, each key marked with its file
dartway secret set SMS_API_TOKEN --env local
```

`init` has nothing to generate there (the coordinates are committed), `push` and `pull` have nowhere
to go (the file *is* the store), and `put-file` has nothing to mount — a document a local server
reads is a path on that machine, so a variable points at it. Each says so rather than doing
something surprising.

### On a server

**The store** is one file on the server, `/home/<deploy_user>/.config/<project>/secrets.env`, mode
600, outside the checkout so the `git reset --hard` of a deploy cannot touch it. Lines are
`KEY='value'`, single-quoted so nothing in a value is interpreted — which is why a value cannot hold a
single quote or a line break. Names are upper-case environment variable names, not starting with
`COMPOSE_` (Compose would read those as its own settings). Every deploy renders the checkout's `.env`
from the store, on the server, so no value makes a round trip through the maintainer's machine. **A
running server keeps the environment it started with**: a changed secret takes effect on the next
`run`.

| Subcommand | Does |
|---|---|
| `secret init` | Creates the store and generates the random-string secrets that are missing; never replaces a value. `setup` does this too |
| `secret set <KEY>` | Stores one value read from **stdin**, so it appears in neither shell history nor a process list. Refuses an empty value and the names the compose file sets |
| `secret list` | Names only — which are required, generated, empty or refused — plus the stored files. Values are never read |
| `secret put-file <path>` | Uploads a document (a service-account JSON) into the store with mode 600; `--name` stores it under another name. It reaches the server only when declared under `requires.files`, mounted read-only at `/run/secrets/<name>` — re-run `setup` after declaring one |
| `secret push` | Adds to the server store what it lacks from the environment's section of `deploy/secrets.yaml`; a key whose server value differs is refused by name, never replaced silently |
| `secret pull` | Copies keys the server has and the local file lacks into it; differing values are reported, never rewritten |

**`deploy/secrets.yaml`** is optional: the maintainer's copy of every environment's secrets, one
section per environment and no shared section, git-ignored by the skeleton's `deploy/.gitignore`.
Secrets can live on the servers alone.

**`push`'s default is additive, not a replace.** It sends a key the server lacks or holds empty,
leaves a key whose server value already matches alone, and — for a key whose server value differs —
refuses the whole push, sending nothing, naming every such key. That is what keeps it from being the
easy way to move an environment to a new host: `setup` generates a fresh `DW_DATABASE_PASSWORD`
(with `database: bundled`) and storage keys there, bound to that host's own data volume, and a `push`
that quietly overwrote them with an old host's values (still sitting in `deploy/secrets.yaml`) would
lock the server out of its own database on the next `run`.

`--overwrite KEY[,KEY…]` replaces exactly those named keys on purpose — there is no
`--overwrite-all`, since naming the key is the point. A key `dartway secret list` marks `generated`
is bound to the data already on the server on every path that touches it, not only a replace: naming
it in `--overwrite` is required for `--prune` to drop it or `--allow-emptying` to blank it too, on top
of whichever of those two flags would otherwise be enough on its own for an ordinary key — it is the
kind of value a swap, a drop or a blank all break the server over the same way. `push` refuses before
sending anything when a value cannot be stored at all, and keeps its two older guards against losing
information, each behind its own flag: `--prune` allows dropping keys the server has and the file
does not (usually the file is behind, not the server holding junk), and `--allow-emptying` allows
blanking a value the server has — unaffected by `--overwrite` for an ordinary key. Before sending
anything, `push` prints a per-key plan — `add`, `keep (same)`, `overwrite`, `differs — refused`,
`drop` — the same shape `--dry-run` prints, which sends nothing.

The comparison behind that plan runs on the server itself, over the local values sent on stdin — only
key names and a checksum of the store travel back, never a value, the same rule the store keeps
everywhere else. That checksum is checked again right before `push` writes, so a second push, or a
hand edit, landing in between the two is refused rather than silently undone; and a store that exists
but cannot be read fails the comparison outright, rather than being read as an absent one that every
key would then look new against. `pull` takes `--dry-run` too.
