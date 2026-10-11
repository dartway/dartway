# Deployment

There are no deploy scripts in this project, and there is no reason to write
any: provisioning, rendering, the secret store, restarts and verification belong
to the framework.

```sh
# deploy/config.yaml already describes "local"; uncomment a deployment in it

dartway deploy check --env staging --local  # the working copy only
dartway deploy setup --env staging          # provision + render the stack
dartway secret set SMS_API_TOKEN --env staging   # what cannot be generated
dartway deploy check --env staging          # DNS, the server, the site
dartway deploy run   --env staging          # update, build, start, verify
```

## Kamal

After configuring `staging` and/or `production` in `deploy/config.yaml` and
resolving the packages, generate and commit the deployment contract:

```sh
cd dartway_starter_flutter
dart run dartway_cli:dartway deploy kamal
dart run dartway_cli:dartway deploy kamal --check
```

The template includes none of these generated files. This creates or refreshes
`deploy/kamal/*`, `deploy/studio.yml` and
`.github/workflows/images.yml`. Images runs after the required `CI` workflow
succeeds. Image publication follows each deployment's `branch:`; enable CI
pushes on those branches. CI defaults to `master` and `release`. The generated
workflow must first be merged into the default branch for `workflow_run` to
trigger it. Unconfigured projects skip image builds. Fork PRs skip this privileged workflow;
other PR builds do not push or write shared caches.
Successful branch CI
builds each image once for `linux/amd64` and pushes its commit SHA to GHCR;
existing tags are skipped, and GHA caches keep unchanged Flutter SDK layers.

Destinations are `stage` and `prod`. Kamal 2.12 runs kamal-proxy v0.10.2; the API
routes `/dw`, `/health` and literal project HTTP-route prefixes on both hosts.
Web release builds use `Uri.base.origin`, so the same image serves both
destinations without build arguments. The Studio binding validates tokens for
the same app origin. A non-literal route or the root path (`/`)
refuses generation with its file and line. A project name that cannot be used
as a service name is refused with its value and the `project:` key to configure.
Regenerate after changing routes or deployment config;
`--check` names any stale generated file.

Bundled RustFS is a service with its own TLS host; Postgres is an API accessory
with no published host port.
Studio supplies SSH keys, secret values and registry credentials, runs Kamal in
manifest order, then runs the check image against a read-only checkout at
`/project`. The check image tag follows the CLI lock: Git resolved SHA, path
checkout HEAD, or pub.dev version. Server preparation and moving existing data
belong to Studio and the project's migration. The existing `deploy run` flow
below remains available until this project moves.

## What lives where

| File | Owns |
|---|---|
| `config.yaml` | every environment of this project: `local` — what your own machine starts a server with — and each deployment's machine, repository, `api` / `app` / optional `site` hosts and optional storage. Plus `requires`, what the project needs wherever it runs |
| `../dartway_starter_server/Dockerfile` | the server image: `dart compile exe`, the binary as PID 1 |
| `../dartway_starter_flutter/Dockerfile` | the web image; a release calls `Uri.base.origin` |
| `../dartway_starter_flutter/nginx.conf` | how that image serves the build — files only — and above all **what a browser may keep** |
| `compose.override.yml` | anything this project adds to a standard deployment — create it when that happens. Read from the checkout on every deploy |
| `nginx.d/{http,api,app}/*.conf` | extra directives for the front proxy, if ever needed. A `proxy_pass` here must name a service the stack declares — `deploy check` and the deploy both refuse otherwise |
| `secrets.yaml` | **git-ignored**: the half of every environment that cannot be committed — your own `local` keys, and the maintainer's copy of each server's, moved with `secret push` / `secret pull` |

`docker-compose.yml`, `nginx.conf` and `.env` are rendered on the server and are
not part of this repository.

## The stack

One server process behind one front proxy:

| Service | What it is |
|---|---|
| `postgres` | Postgres 17, on a named volume |
| `server` | the project's server image, configured by environment only; healthcheck on `/health` |
| `web` | the Flutter web build served by nginx, files only |
| `storage` + `storage-init` | with `storage: bundled`: RustFS and its two buckets — `<project>-public`, whose objects anyone reads (never its listing), and `<project>-private`, which reads nothing unsigned; `storage-init` sets both on every deploy |
| `nginx` | TLS for every host: **app** → the web image, with `/dw/` (the live socket upgrade included) and `/health` sent to the server; **api** → the server; **site** → the static directory |
| `certbot` | renews the one certificate every host shares |

The server receives `DW_DATABASE_*` (and, with the bundled storage, `DW_STORAGE_*`) and `PORT`
from the compose file, and every secret of the store through `.env`. It serves
no static files.

With the bundled storage the storage variables are `DW_STORAGE_PUBLIC_BUCKET`,
`DW_STORAGE_PRIVATE_BUCKET` and
`DW_STORAGE_PUBLIC_BASE_URL=https://<storage_domain>/<project>-public`, and
`DW_STORAGE_VERIFY_BUCKETS=false`: the server reaches the storage through the
proxy's storage host, which starts after it, so the bucket check a server runs
at startup is made from outside once the stack is up (step 8). An external
storage keeps the check on — the server refuses to start on a missing bucket,
a private bucket anyone can read or a public one nobody can.

## What `run` does

1. updates the checkout to the tip of the branch;
2. renders `.env` from the secret store, refusing — by key name, never by value
   — when a required secret is missing or empty;
3. asks Compose whether the merged stack is valid, makes the TLS certificate
   cover every host through the proxy still serving — before anything is
   replaced, so a Let's Encrypt failure leaves the previous version serving —
   then builds the images;
4. starts storage and the database;
5. **starts the new server beside the running one**. It applies its migrations
   as it starts, and either answers `/health` or exits; on an exit its log is
   printed and the deploy stops with the previous version still serving. That
   log *is* the migration outcome, in the server's own words;
6. replaces the server and waits for it to be healthy, then the web image;
7. checks that every upstream of the proxy is a service of the applied stack and
   runs `nginx -t` inside the running proxy, issues the certificate if no proxy
   was running to ask through before (a first deploy), and restarts the proxy —
   and checks that it is still running afterwards;
8. verifies from outside, as a browser and an app would: `/health` answers 200
   through both hosts, the app host serves the Flutter `index.html` with a
   revalidating cache policy, `/dw/live` upgrades through both hosts and the
   server answers on the socket, and — where declared — the site answers and
   the storage preflight admits a PUT from the app's origin, the public
   bucket's probe object reads without credentials, the private bucket's does
   not, and neither bucket lists its keys.

## Caching — why a redeploy might not reach the browser

**A Flutter web build hashes nothing.** `index.html`, `flutter_bootstrap.js`,
`main.dart.js` and every file under `assets/` carry the same name in every
build, so the familiar "cache for a year" rule lands on exactly the files that
change on every deploy: a browser that took one under a long `max-age` keeps
running the previous build and nothing anywhere reports it. So
`../dartway_starter_flutter/nginx.conf` serves everything with
`Cache-Control: no-cache` (a 304 with an ETag, not a download) and keeps the
long-lived rule for names that really carry a content hash. `deploy check`
reads that file, and `run` asks the deployed site what it actually answers.

Fixing the configuration does not un-poison a browser that already holds a
copy; tell whoever you can reach to hard-reload.

## Secrets

### On this machine

`local` is an environment like any other, and its two halves are the two files
above: `config.yaml` > `local` for what the team shares, `secrets.yaml` >
`local` for what is yours. The server, the seed and `migrate` read both through
`DwLocalEnvironment`; a real environment variable beats them, and a deployed
server has neither file — `.dockerignore` keeps `deploy/` out of every image.

```sh
dartway secret list --env local            # both halves, each key marked
dartway secret set SMS_API_TOKEN --env local
```

There is nothing to `init` (the coordinates are committed), nothing to `push`
or `pull` (this *is* the file), and no `put-file`: a document a local server
reads is a path on this machine, so point a variable at it.

### On a server

The store is one file on the server, `~/.config/<project>/secrets.env`,
outside the checkout so the `git reset --hard` of a deploy cannot touch it:

- `secret init` generates what is only a random string — `DW_DATABASE_PASSWORD`,
  and with the bundled storage `DW_STORAGE_ACCESS_KEY` / `DW_STORAGE_SECRET_KEY`. `setup` runs
  it too. Existing values are never replaced;
- `secret set <KEY>` reads the value from stdin, so it never appears in shell
  history or a process list;
- `secret list` shows names — which are required, generated or empty — never
  values;
- `secret put-file` delivers a document declared under `requires.files`;
- `secret push` / `secret pull` move one environment between the server and
  `deploy/secrets.yaml`.

Names are environment variables in upper case. A value cannot contain a single
quote or a line break — the store keeps values single-quoted so nothing in them
is interpreted — and the store refuses the names the compose file sets itself
(`DW_DATABASE_HOST` and the like), because that value would silently win.
A running server keeps the environment it started with; a changed secret takes
effect on the next `run`.

## What this server reads besides the framework

`../dartway_starter_server/bin/server.dart` lists every variable. Two of them
are the project's to deliver:

- `DW_ADMIN_IDENTIFIER` — the phone or e-mail made an administrator on every
  start by the framework's `DwFirstAdministrator` step:
  `dartway secret set DW_ADMIN_IDENTIFIER --env staging`. Whoever
  receives its codes is the admin, so it has no default; unset, the admin panel
  is out of reach and the server says so in its log.

Sign-in codes are written to the server log until a delivery is wired into
`deliverCode` (`../dartway_starter_server/lib/src/account/logic/auth.dart`); list the gateway's
keys under `requires.secrets` in `config.yaml` when it is.
