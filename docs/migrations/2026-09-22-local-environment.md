---
title: The local environment lives in deploy/config.yaml, and `dartway deploy secret` is now `dartway secret`
affects:
  dartway_cli: "0.11.0"
  dartway_core_server: "0.20.0-dev.2"
---

## Who is affected

Every project. Two of the three edits are required whatever you do; the third is what the change
is for.

## 1. `dartway deploy secret` no longer exists — required

The subcommand moved up, because `local` is now an environment like any other and
"`dartway deploy secret --env local`" would be a lie. Change every script, alias and note:

    - dartway deploy secret set SMS_API_TOKEN --env staging
    + dartway secret set SMS_API_TOKEN --env staging

    - dartway deploy secret list --env staging
    + dartway secret list --env staging

`init`, `set`, `list`, `put-file`, `push` and `pull` are unchanged in everything but the prefix.
Nothing on a server changes: the store, its path and its contents stay as they were.

## 2. The first administrator's variable is renamed — required if you adopt step 4 of the other note

If you keep your own bootstrap code, nothing forces your hand: it reads whatever variable name you
wrote. If you move to `DwFirstAdministrator` (see
`2026-09-22-startup-steps-and-the-first-administrator.md`), the name is the framework's:

    dartway secret set DW_ADMIN_IDENTIFIER --env staging   # the same value as APP_BOOTSTRAP_ADMIN
    dartway secret list --env staging                      # confirm both are listed
    # then, after a deploy that proves the new name works:
    # remove APP_BOOTSTRAP_ADMIN from deploy/secrets.yaml and push

**Do not rename it on the server first and deploy afterwards.** A server started with neither name
set comes up without an administrator and only warns.

## 3. Declare `local` in `deploy/config.yaml` — this is the point of the change

Your entry points can now read the development coordinates from the repository instead of every
developer exporting them by hand. Two files, split along the one line Git forces.

**`deploy/config.yaml`** — add a `local` section, and hoist `requires` out of the environments that
repeat it:

```yaml
requires:                        # what the project needs wherever it runs, declared once
  secrets: [SMS_API_TOKEN]

local:                           # committed: the coordinates of your dev containers
  DW_DATABASE_HOST: 127.0.0.1
  DW_DATABASE_PORT: 8090
  DW_DATABASE_NAME: my_app
  DW_DATABASE_USER: postgres
  DW_DATABASE_PASSWORD: dev_pw
  DW_DATABASE_SSL: false
  DW_STORAGE_ENDPOINT: http://127.0.0.1:8100
  DW_STORAGE_ACCESS_KEY: dev
  DW_STORAGE_SECRET_KEY: dev_storage_pw
  DW_STORAGE_PROVISION: true

staging:
  host: …
```

Take the values from your `<project>_server/docker-compose.yaml` and from your `.vscode/launch.json`
— they are the same ones, which is the problem being fixed. An environment's own `requires` still
works and adds to the project-level one.

**`deploy/secrets.yaml`** — the git-ignored half gets a `local` section for the keys that are yours
alone. Write it with the command rather than by hand:

    dartway secret set SMS_API_TOKEN --env local

**Entry points** — one line each, in `bin/server.dart`, `bin/seed_dev.dart` and `bin/migrate.dart`:

```dart
// bin/server.dart
- final env = Platform.environment;
+ final env = DwLocalEnvironment.overlay(Platform.environment);

// bin/migrate.dart
  exitCode = await DwMigrationCli(
    …
+   environment: DwLocalEnvironment.overlay(Platform.environment),
  ).run(args);
```

**`.vscode/launch.json`** — delete the whole `"env"` block of the server configuration. It is now a
copy of `deploy/config.yaml > local` that nothing keeps in step, and a real key written there is a
key committed to Git.

A real environment variable still beats both files, so `DW_DATABASE_NAME=other dart run
bin/server.dart` keeps working and nothing you export today stops working.

## How to check

    dartway secret list --env local      # both halves, each key marked with its file
    dartway check                        # localSecretMissing, devComposeDrifted

Then start the server with nothing exported: its first line says
`Local environment: N key(s) from deploy/config.yaml, M from deploy/secrets.yaml`.
