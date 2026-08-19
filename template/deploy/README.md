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

## Secrets

`../dartway_starter_server/config/passwords.yaml` is **git-ignored** and holds
the secrets of every run mode. The committed record of which keys an
environment needs is `passwords.yaml.example`. Values for a deployed
environment live on the server, outside the checkout, so the `git reset --hard`
a deploy performs cannot touch them; `dartway deploy secret push/pull` moves
them between the two.

A credential that is a whole file — a service-account JSON, an `.env` for some
integration — goes to the server with `dartway deploy secret put-file` and is
named under `requires.files` in `config.yaml`. The deploy mounts each declared
file read-only at `/app/config/<name>` in the server container, so the
application reads it as `config/<name>`, and `dartway deploy check` asserts that
the mount is really there rather than only that the file reached the machine.

> `serviceSecret` is also the key other credentials are encrypted with, where a
> project encrypts any. Rotating it makes them unreadable. Rotate deliberately.
