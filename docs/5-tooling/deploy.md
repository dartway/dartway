# How is a DartWay project deployed?

With four subcommands and one file, onto one Linux server running Docker. There are no deploy
scripts in a project and no reason to write any: provisioning, rendering, the secret store,
restarts and verification belong to the framework.

```bash
cp deploy/config.yaml.example deploy/config.yaml     # then fill it in

dartway deploy check --env staging --local            # the working copy only
dartway deploy setup --env staging                    # provision the server, render the stack
dartway deploy secret set SMS_API_TOKEN --env staging # what cannot be generated
dartway deploy check --env staging                    # DNS, the server, the deployed hosts
dartway deploy run   --env staging                    # update, build, start, verify
```

Every subcommand takes `--env <environment>` and refuses to guess without it, naming the
environments `deploy/config.yaml` declares. Every one that connects takes `--as <login>` (default:
`ssh_user` from the config) and `--identity <key file>` (default: your SSH agent). The code is
`packages/dartway_cli/lib/src/commands/deploy_*.dart`, `secret_commands.dart` and
`packages/dartway_cli/lib/src/deploy/`.

## One file describes an environment

`deploy/config.yaml` holds one environment per top-level key. **The server has no configuration
file of its own** — it is configured by its environment, which the deploy derives from this file
(database coordinates, storage, port) and from the secret store on the server (passwords, keys).
Nothing writes `config.yaml`; the deploy only reads it.

| Key | Required | Meaning |
|---|---|---|
| `host` | yes | The server's address |
| `ssh_user` | yes | Login for provisioning — root, or a user with passwordless sudo |
| `deploy_user` | yes | The unprivileged user that owns the checkout and runs the stack |
| `os` | yes | The server's operating system (`ubuntu`) |
| `repo`, `branch` | yes | The repository the server checks out, and the branch it deploys |
| `ssl_email` | yes | Where Let's Encrypt writes about expiring certificates |
| `api_domain` | yes | The server, for mobile apps and webhooks |
| `app_domain` | yes | The Flutter web app |
| `site` | no | `domain` and `source`: a directory of the repository served as static files, or `none` for a site that lives elsewhere |
| `storage` | no | `minio` or `external`; absent means no file storage |
| `storage_domain` | with `minio` | The public host of MinIO; refused without `storage: minio` |
| `registry_mirror` | no | Pull the stack's base images through a mirror |
| `firewall_ports` | no | TCP ports to open beyond SSH, 80 and 443 |
| `requires.secrets` | no | Secrets nobody can generate, as environment variable names |
| `requires.files` | no | Secret documents, by file name, mounted into the server |

The file is validated as it is read, **every problem at once**, and an unknown key is one of them: a
key the deploy does not read is a setting somebody believes is in force. Every domain must be a host
name, and each role needs a host of its own — Nginx routes by `server_name`, so two roles on one host
means one of them is never reached.

Names are derived, not configured. The project name is the last segment of `repo` without `.git`;
the checkout is `/home/<deploy_user>/<project>`. The database and its role are named after the
server package without `_server`, and the MinIO buckets after the same prefix with dashes.

## Three hosts, one server process

```
app.example.com   →  the web image;  /dw/ (the live socket included) and /health → the server
api.example.com   →  everything → the server
example.com       →  the site directory, static            (optional)
files.example.com →  MinIO                                  (with storage: minio)
```

**The app calls its own origin** (R2.7). On the app host the front Nginx serves the web image and
sends `/dw/`, `/dw/live` and `/health` to the server, so a browser makes same-origin calls: no CORS,
no preflight, and the server answers none. The web build is given that origin as
`DW_BACKEND_URL`. The api host proxies everything to the server — calls, the live socket, and the
project's own doors (`DwRoute`) such as a webhook. The server serves no static files. Local
development has the same shape through `dartway dev` ([The CLI](cli.md)).

**Storage has a host of its own because a presigned URL signs its host.** Browsers upload to MinIO
directly (see [Uploads](../4-server/uploads.md)); a storage hidden behind the app's origin would be
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
| `postgres` | `postgres:17-alpine`, on the volume `postgres_data`, with a `pg_isready` healthcheck |
| `server` | Built from `<project>_server/Dockerfile` with the project root as context. Secrets through `env_file: .env`; `PORT=8080`, `DW_DATABASE_*` (and, with MinIO, `DW_STORAGE_*`) in the compose file. Exposed to the network only. `stop_grace_period: 45s`; healthcheck `GET /health` with a 600-second start period, because migrations run before the port opens |
| `web` | Built from `<project>_flutter/Dockerfile` with the build argument `DW_BACKEND_URL` = the app origin |
| `minio`, `minio-init` | With `storage: minio`: the storage, and a one-shot job that creates and configures both buckets on every deploy |
| `nginx` | `nginx:alpine` on 80 and 443 |
| `certbot` | Renews the certificate every 12 hours |

**Data-bearing images are pinned** — Postgres to its major, MinIO to its last community release — so a
deploy on a later day cannot move a data directory under a binary that refuses it. The stateless
proxy and certbot follow upstream. Values in the compose file that the deploy derives win over the
same names in `.env`, which is why the secret store refuses those names.

`deploy/compose.override.yml` is where a project adds what a standard deployment does not have. It is
**never copied**: every Compose call the CLI issues names it from the checkout
(`docker compose -f docker-compose.yml -f deploy/compose.override.yml …`), so `git reset --hard` on a
deploy refreshes it. For the command a person types by hand on the server, the deploy writes
`docker-compose.override.yml` as a two-line `include:` of the committed override, marked
`dartway-bridge` — otherwise a bare `docker compose up -d` applies a strictly smaller stack and exits
0. A file under that name without the marker is moved to `docker-compose.override.yml.retired`; with
no override in the checkout and a foreign file in its place, the deploy refuses, because that file
may be the only place its services are declared.

## Storage: MinIO or someone else's

Two buckets, whatever the option (D-038b): a **public** one whose objects anyone reads and whose
listing nobody gets, and a **private** one that reads nothing unsigned. A rule's visibility picks
the bucket.

**`storage: minio`** runs the storage in the stack. `minio-init` creates `<prefix>-public` and
`<prefix>-private` (keeping existing buckets and their objects), sets the public bucket's policy to
anonymous `s3:GetObject` only — not `mc anonymous set download`, which also grants listing — sets the
private one to nothing, and writes a probe object into both. MinIO's CORS rule admits the app origin,
which is what a browser's presigned `PUT` needs. The server receives `DW_STORAGE_ENDPOINT` (the
storage host), both bucket names, `DW_STORAGE_PUBLIC_BASE_URL=https://<storage_domain>/<prefix>-public`,
path-style addressing and **`DW_STORAGE_VERIFY_BUCKETS=false`**: the server reaches MinIO only
through the proxy, and the proxy starts after the server, so the bucket check a server normally runs
at startup cannot run there. The outside probe runs the same check once the stack is up.
`DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` are generated into the secret store.

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
4. **The secret store**, with the secrets that are only random strings generated in place:
   `DW_DATABASE_PASSWORD`, and with MinIO the storage keys. Existing values are never replaced —
   regenerating the database password would lock the server out of a database initialised with the
   old one.
5. **A repository key**, for a `git@` repository: generated **on** the server, so the private half
   exists nowhere else. When the server cannot yet reach the repository, setup stops and prints the
   public key, asking for it to be registered as a **read-only** deploy key — the server only ever
   fetches, and a writable key turns access to the box into access to the repository.
6. **The checkout** of `branch`.
7. **`.env`** with the generated secrets — what the compose file itself interpolates.
8. **A data volume guard**: if the server carries a `<project>_…data` volume under another name than
   the rendered stack uses, setup refuses. Compose would otherwise create an empty database beside
   the real one and serve it.
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
`dartway deploy check --local` for the detail. Then:

1. updates the checkout to `origin/<branch>` with `git reset --hard` — the server mirrors the
   repository, and a stray edit on the box must not block a deploy (skipped with `--skip-git-update`);
2. writes the override bridge;
3. renders `.env` from the secret store, refusing — by key name and line number, never by value —
   when the store is absent, a line is malformed, a key is declared twice, a key is one the compose
   file sets, or a required secret is missing or empty;
4. checks the merged Compose configuration, then builds the images;
5. with MinIO, starts it and runs `minio-init`, printing what it did; starts Postgres;
6. **starts the new server beside the running one.** It applies its migrations as it starts and
   either becomes healthy or exits; on an exit its log is printed and the deploy stops with the
   previous version still serving. That log *is* the migration outcome, in the server's own words.
   The candidate has no network alias, so the proxy never routes to it;
7. replaces the server and waits until it is healthy, replaces the web app, and converges the rest of
   the stack (`up -d --remove-orphans`);
8. **checks the Nginx upstreams against the applied stack** — `docker compose config --services` on
   the server — and runs `nginx -t` inside the running proxy. Nginx resolves an upstream once, when it
   starts, so a snippet naming a service the stack does not have fails at the next proxy restart; this
   stops the deploy before that restart;
9. issues the certificate **once** — only when certbot does not already manage it, so a routine
   deploy stays off the rate limit — for every served host;
10. restarts Nginx and checks it is still running afterwards: `restart` exits 0 for a proxy that dies
    a second later on its configuration.

`run` does not render `docker-compose.yml` or `nginx.conf`: a deploy that re-renders infrastructure on
every push turns a routine change into an infrastructure one. `--dry-run` prints the plan and the
probes, and executes nothing.

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
| `server-signals` | error | The server image's `ENTRYPOINT` (or `CMD`) is in exec form, so the binary is PID 1 and receives the SIGTERM a deploy sends; under `/bin/sh -c` it is killed mid-call when the grace period runs out |
| `web-backend-url` | error | The web Dockerfile declares `ARG DW_BACKEND_URL` — Docker silently drops an undeclared build argument |
| `web-cache-policy` | warning | The web image's Nginx configuration revalidates every Flutter entry point |
| `nginx-upstreams` | error | Every `proxy_pass` in the rendered Nginx and in `deploy/nginx.d/` names a service of the stack or the override |
| `override-web-build` | warning | `deploy/compose.override.yml` does not rebuild `web` — that would name the API address a second time, and nothing compares the copies |
| `local-secrets-untracked` | error | `deploy/secrets.yaml` is not tracked by Git |
| `local-secrets-cover-environment` | warning | `deploy/secrets.yaml` holds every required secret for the environment (reported by `check` only; `run` does not evaluate it) |
| `dns-public-hosts` | error | Every served host resolves to the deployment host — a mismatch otherwise burns the Let's Encrypt rate limit |
| `ssh-reachable` | error | Key-based SSH works; when it fails the other server checks are skipped |
| `deploy-user` | error | The deployment user exists |
| `docker-available` | error | Docker Compose is usable by the deployment user |
| `runtime-secrets` | error | Every required secret is in the server store with a value, and nothing reserved is |
| `secret-files` | error | Every `requires.files` entry is delivered **and** mounted into the server container, read from the configuration Compose will actually run |
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
  to build without it), runs `flutter build web --release --dart-define=DW_BACKEND_URL=…`, and serves
  the build with `nginx:alpine` and `<project>_flutter/nginx.conf`. It serves files only.
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
| `secret push` | Replaces the server store with the environment's section of `deploy/secrets.yaml` |
| `secret pull` | Copies keys the server has and the local file lacks into it; differing values are reported, never rewritten |

**`deploy/secrets.yaml`** is optional: the maintainer's copy of every environment's secrets, one
section per environment and no shared section, git-ignored by the skeleton's `deploy/.gitignore`.
Secrets can live on the servers alone. `push` refuses before sending anything when a value cannot be
stored, and has two guards against losing information, each with its flag: `--prune` allows dropping
keys the server has and the file does not (usually the file is behind, not the server holding junk),
and `--allow-emptying` allows blanking a value the server has. `push` and `pull` both take
`--dry-run`.
