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

## What lives where

| File | Owns |
|---|---|
| `config.yaml` | every environment of this project: `local` — what your own machine starts a server with — and each deployment's machine, repository, `api` / `app` / optional `site` hosts and optional storage. Plus `requires`, what the project needs wherever it runs |
| `../dartway_starter_server/Dockerfile` | the server image: `dart compile exe`, the binary as PID 1 |
| `../dartway_starter_flutter/Dockerfile` | the web image; the deploy passes it the app's origin as `DW_BACKEND_URL` |
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
| `minio` + `minio-init` | with `storage: minio`: the storage and its two buckets — `<project>-public`, whose objects anyone reads (never its listing), and `<project>-private`, which reads nothing unsigned; `minio-init` sets both on every deploy |
| `nginx` | TLS for every host: **app** → the web image, with `/dw/` (the live socket upgrade included) and `/health` sent to the server; **api** → the server; **site** → the static directory |
| `certbot` | renews the one certificate every host shares |

The server receives `DW_DATABASE_*` (and, with MinIO, `DW_STORAGE_*`) and `PORT`
from the compose file, and every secret of the store through `.env`. It serves
no static files.

With MinIO the storage variables are `DW_STORAGE_PUBLIC_BUCKET`,
`DW_STORAGE_PRIVATE_BUCKET` and
`DW_STORAGE_PUBLIC_BASE_URL=https://<storage_domain>/<project>-public`, and
`DW_STORAGE_VERIFY_BUCKETS=false`: the server reaches MinIO through the
proxy's storage host, which starts after it, so the bucket check a server runs
at startup is made from outside once the stack is up (step 8). An external
storage keeps the check on — the server refuses to start on a missing bucket,
a private bucket anyone can read or a public one nobody can.

## What `run` does

1. updates the checkout to the tip of the branch;
2. renders `.env` from the secret store, refusing — by key name, never by value
   — when a required secret is missing or empty;
3. asks Compose whether the merged stack is valid, then builds the images;
4. starts storage and the database;
5. **starts the new server beside the running one**. It applies its migrations
   as it starts, and either answers `/health` or exits; on an exit its log is
   printed and the deploy stops with the previous version still serving. That
   log *is* the migration outcome, in the server's own words;
6. replaces the server and waits for it to be healthy, then the web image;
7. checks that every upstream of the proxy is a service of the applied stack and
   runs `nginx -t` inside the running proxy, issues the certificate once, and
   restarts the proxy — and checks that it is still running afterwards;
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
  and with MinIO `DW_STORAGE_ACCESS_KEY` / `DW_STORAGE_SECRET_KEY`. `setup` runs
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
- `DW_MIN_APP_BUILD` — the oldest app build still served; older builds are shown
  the "update the app" screen. Raise it with `secret set` and a `run`.

Sign-in codes are written to the server log until a delivery is wired into
`deliverCode` (`../dartway_starter_server/lib/src/auth.dart`); list the gateway's
keys under `requires.secrets` in `config.yaml` when it is.
