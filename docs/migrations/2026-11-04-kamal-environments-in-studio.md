---
title: Move Kamal environments out of the repository and into Studio
affects:
  dartway_cli: "0.27.0"
---

## Who is affected

Projects with a generated `deploy/studio.yml`: their `deploy/config.yaml` still
describes `staging` and `production`, and `deploy/kamal/` holds destination
files (`api.stage.yml`, `web.prod.yml`, …). `dartway deploy kamal` now refuses
deployment sections in such a project, and `deploy kamal --check` in CI fails
until the project regenerates. Projects that deploy with `dartway deploy run`
(Compose) and have no `deploy/studio.yml` change nothing.

## What to change

1. In `deploy/config.yaml`, replace the deployment sections with one `kamal:`
   section holding what every environment shares:

   ```yaml
   kamal:
     repo: git@github.com:your-org/your-project.git  # the repo: the sections had
     # project: your-project   # only if the sections set project:
     # deploy_user: dw_admin   # only if the sections set deploy_user:
     storage: true             # if the sections had storage: bundled or external
   ```

   `repo`, `project` and `deploy_user` must have been the same in every
   section; if `deploy_user` differed, settle on one before continuing, because
   it names the directory every host's `requires.files` are mounted from.

2. Move every environment's own `requires:` into the top-level `requires:`.
   The result is the union: a secret one section alone required is now
   required in every environment, so Studio must hold a value for it in each
   (for u90, `REVENUECAT_WEBHOOK_AUTHORIZATION`, until now production-only).
   Then remove from `requires.secrets` the names the contract already
   provides; generation refuses them there:
   - the database connection — `DW_DATABASE_HOST`, `DW_DATABASE_PORT`,
     `DW_DATABASE_NAME`, `DW_DATABASE_USER`: derived for a bundled database,
     and secrets of `components.database` for an external one;
   - the storage names that are non-secret values of an external storage —
     `DW_STORAGE_ENDPOINT`, `DW_STORAGE_PUBLIC_BUCKET`,
     `DW_STORAGE_PUBLIC_BASE_URL`, `DW_STORAGE_PRIVATE_BUCKET`,
     `DW_STORAGE_REGION`, `DW_STORAGE_PATH_STYLE`.

3. Delete the `staging:` and `production:` sections. Keep `local:`,
   `requires:` and `migrations:`.

4. From the Flutter package, run `dartway deploy kamal` and commit the result.
   It deletes the destination files, rewrites `deploy/kamal/<service>.yml` as
   one configuration per service, and rewrites `deploy/studio.yml` (no
   `environments` list) and `.github/workflows/images.yml`.

Nothing on the servers is renamed. Kamal's destination is still the
environment's name, so the existing destinations continue as environments
`stage` and `prod`: apps `<project>-<service>-stage`, containers and routes
`<project>-<service>-web-stage`, the volume `<project>-storage-data-stage`, the
accessory `<project>-api-postgres-stage` and the env files under
`~/.kamal/apps/<project>-<service>-stage/` keep their names. The server's
`DW_ENVIRONMENT` becomes the environment's name (`stage`, `prod`) instead of
the section's (`staging`, `production`); it labels alerts and nothing else.

Images now publishes every successful CI run started by a push or by hand,
whatever the branch: which branch an environment deploys is Studio's. The
branches CI's own `push:` trigger names are the ones that get images.

### Studio

Studio (STD-E22) takes each environment's host, SSH user, domains, storage and
database modes and `trusted_proxy_networks` from the old `deploy/config.yaml`
once, as environments `stage` and `prod`, and deploys an old manifest — one
with `environments` — the old way, with the committed destination files, until
the project regenerates. After that it deploys by variables:
`STUDIO_ENVIRONMENT`, `STUDIO_HOST`, `STUDIO_SSH_USER`, `STUDIO_DOMAIN_API`,
`STUDIO_DOMAIN_APP`, `STUDIO_DOMAIN_FILES` (bundled storage only),
`STUDIO_BUNDLED_STORAGE`, `STUDIO_BUNDLED_DATABASE`, the values the manifest
lists (`DW_TRUSTED_PROXY_NETWORKS`; `DW_STORAGE_ENDPOINT` and the buckets of an
external storage) and the secrets it names, and runs Kamal with
`-d $STUDIO_ENVIRONMENT` after writing `{}` to each
`deploy/kamal/<service>.<env>.yml` it lacks. A new environment is a new set of
variables in Studio and no commit.

u90 is the first project through this note: `stage` and `prod` are its
existing destinations, so its live apps, volumes and databases are kept.

## How to check

- `dartway deploy kamal --check` reports nothing, and `deploy/kamal/` holds no
  `*.stage.yml` or `*.prod.yml`.
- `deploy/studio.yml` has no `environments` key.
- With an environment's variables exported (as Studio sets them),
  `dartway deploy check --env stage --local` prints that environment's hosts and
  passes `kamal-generated` and `kamal-secrets`.
