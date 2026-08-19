# Deployment

There are no deploy scripts in this project, and there is no reason to write
any: provisioning, rendering, migrations and restarts belong to the framework.

```sh
cp deploy/config.yaml.example deploy/config.yaml   # then fill it in

dartway deploy check --env staging          # judge the config, change nothing
dartway deploy check --env staging --local  # skip DNS and the server
dartway deploy setup --env staging          # provision + render infrastructure
dartway deploy run   --env staging          # update, rebuild, migrate, restart
dartway deploy secret --help                # runtime secrets on the server
```

## What lives where

| File | Owns |
|---|---|
| `config.yaml` | the **machine**: host, users, repo, branch, SSL contact, the web-app domain |
| `../dartway_starter_server/config/<env>.yaml` | the **application**: domains, ports, database, Redis — read by the deploy, never written |
| `../dartway_starter_server/Dockerfile` | the server image, built from the project root |
| `../dartway_starter_flutter/Dockerfile` | the web image; the deploy passes it `DW_BACKEND_URL` |
| `../dartway_starter_flutter/nginx.conf` | how that image serves the build, and above all **what a browser may keep** — see "Caching" |
| `compose.override.yml` | anything this project adds to a standard deployment — create it when that happens. Read from the checkout on every deploy, so a committed change to it takes effect on the next `run` |
| `nginx.d/{http,api,app}/*.conf` | extra Nginx directives, if any are ever needed |

A domain appears in exactly one of the first two, and `dartway deploy check`
fails when they disagree. One thing does not belong in the override: a `build`
block for the `web` service. The deploy builds that image itself and passes it
the API address from the Serverpod configuration, so building it here writes the
domain down a second time, and `check` warns about it.

`docker-compose.yml` and `nginx.conf` are rendered by `setup` on the server and
are not part of this repository — a deploy that re-renders infrastructure on
every push turns a routine change into an infrastructure one. `compose.override.yml`
is the opposite: it is never copied to the server, only named on every Compose
call, so the file the deploy merges is the committed one.

## Caching — why a redeploy might not reach the browser

**A Flutter web build hashes nothing.** `index.html`, `flutter_bootstrap.js`,
`flutter.js`, `main.dart.js`, `main.dart.wasm` and every file under `assets/`
carry the same name in every build. The familiar rule — "fingerprinted assets
are immutable, cache them for a year" — is correct for a bundler that puts a
content hash in the name, and here it lands on exactly the files that change on
every deploy. A browser that took one under a long `max-age` will not ask again:
it goes on running the previous build while the server serves the new one, and
nothing anywhere reports it.

So `../dartway_starter_flutter/nginx.conf` serves everything a build emits with
`Cache-Control: no-cache` — the copy is kept, it just may not be reused before
the server has confirmed it, which with an ETag costs a 304 rather than a
download — and keeps the long-lived, immutable rule for names that genuinely
carry a content hash. `dartway deploy check` reads that file and, separately,
asks the deployed site what it actually answers.

**Fixing the configuration does not un-poison the browsers already out there.**
A response taken under `max-age=2592000` stays fresh in that browser for the
rest of the thirty days, and it will not ask. Tell whoever you can reach to
hard-reload (Ctrl+Shift+R) or clear site data; for the rest, either wait the
window out or move the app to a URL that was never poisoned — a URL a browser
has not seen is the only thing that gets through.

## Secrets

`../dartway_starter_server/config/passwords.yaml` is **git-ignored** and holds
the secrets of every run mode. The committed record of which keys an
environment needs is `passwords.yaml.example`. Values for a deployed
environment live on the server, outside the checkout, so the `git reset --hard`
a deploy performs cannot touch them; `dartway deploy secret push/pull` moves
them between the two.

**The split is by shape.** A short value — a token, an identifier, a password —
is a key in `passwords.yaml`. A credential that is a whole document — a
service-account JSON, an `.env` for some integration — goes to the server with
`dartway deploy secret put-file` and is named under `requires.files` in
`config.yaml`. The deploy mounts each declared file read-only at
`/app/config/<name>` in the server container, so the application reads it as
`config/<name>` — the same path it reads locally — and `dartway deploy check`
asserts that the mount is really there rather than only that the file reached
the machine.

A document does not belong in `passwords.yaml` even when it fits: that file is
the master copy of every environment's secrets, and a value beginning with `{`
is parsed by unquoted YAML as a mapping rather than as text, so what the
application receives is not what was written.

> `serviceSecret` is also the key other credentials are encrypted with, where a
> project encrypts any. Rotating it makes them unreadable. Rotate deliberately.
