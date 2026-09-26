# How do I get a DartWay app running?

> Goal: from an empty folder to a server answering on `:8080`, the app signed in, and the checks
> green — by hand, command by command, with the reason each step comes where it does.

Working with an AI assistant instead? It runs this same path for you — see
[start with an agent](start-with-an-agent.md).

## 1. Install the CLI and check the machine

```bash
dart pub global activate dartway_cli
dartway doctor
```

`doctor` checks Dart (`>=3.11`), Flutter (`>=3.44`), git with an identity, a reachable pub host, a
running Docker daemon, and whether globally activated executables are on `PATH`. Each failure prints
the command that fixes it.

Two of these fail in ways worth knowing in advance:

- **Docker.** Postgres and the object storage come from it, for development and for tests alike, and
  there is no second path.
- **The pub host.** Every step below begins with `pub get`, and pub sets no deadline on a connection
  that opens and then goes quiet. Where the route to pub.dev is filtered, you do not get an error —
  you get a resolve step that hangs. A mirror in `PUB_HOSTED_URL` is checked instead when you set one.

If `dartway` is not found right after activating it, every command also runs as
`dart pub global run dartway_cli:dartway <command>`.

## 2. Create the project

```bash
dartway create my_app      # a new folder my_app/
dartway create .           # or: this empty folder is the project, and names it
```

The name is `lower_snake_case`: it becomes the package names, the type names and the storage bucket
names. You get three packages — `my_app_shared`, `my_app_server`, `my_app_flutter` — the agent toolkit
in `.claude/`, and a git repository with an initial commit (which is why git needs an identity).

What is inside is a skeleton, not somebody's product: sign-in by a one-time code to a phone or an
e-mail with the terms accepted on sign-up, a profile with a photo, roles, an admin panel (live
counters, a members table, a card per member, settings), navigation with zone guards, a UI kit as
source you own, and tests on both sides. No domain models. What each folder is for:
[project layout](project-layout.md).

Until the framework family is published on pub.dev, build the project against a local DartWay
checkout: `dartway create my_app --framework-path <path to the checkout>`. Its pubspecs then get
`dependency_overrides` onto the checkout's packages, and the template and the toolkit come from the
same checkout.

## 3. Bring the server up

```bash
cd my_app/my_app_server
docker compose up -d
dart pub get
```

`docker compose up -d` starts Postgres on host port `8090` and RustFS — the object storage for uploads
— on `8100` (its web console on `8101`). There is no test database among them: `dart run dartway_cli:dartway test` starts
its own for each run. The first run pulls images and can take minutes.

The server is configured by its environment alone; there is no configuration file it reads. **There
is nothing to export**: `bin/server.dart`, `bin/seed_dev.dart` and `bin/migrate.dart` call
`DwLocalEnvironment.overlay`, which puts two sections into that environment before it is read —

| Section | In Git | What |
|---|---|---|
| `deploy/config.yaml` > `local` | yes | the development containers' own coordinates, the same for everyone on the team |
| `deploy/secrets.yaml` > `local` | no | the keys that are this developer's own |

— in that order, and a real environment variable beats both, so `DW_DATABASE_NAME=other dart run
bin/server.dart` still works. A deployed server has neither file: `.dockerignore` keeps `deploy/` out
of every image, and Compose hands it the environment the deploy rendered.

Your own administrator identifier is the commented `DW_ADMIN_IDENTIFIER` line of that `local`
section — see step 5. The full list the server reads — `PORT`,
`DW_ALLOWED_ORIGINS` and the rest of `DW_STORAGE_*` — is documented at the top of `bin/server.dart`.

A key that must not be committed goes beside them without opening an editor:

```bash
dartway secret list --env local             # what is set, what is missing
dartway secret set SMS_API_TOKEN --env local
```

Wait until Postgres accepts connections — a container reported as started is not yet a database
listening:

```bash
docker compose exec -T postgres pg_isready -U postgres
```

Then start the server, and leave it running:

```bash
dart run bin/server.dart
```

**It migrates the database as it starts** — the framework's own tables and yours — and exits
non-zero naming the migration when one fails, so there is no separate migration step to forget.
`DW_STORAGE_PROVISION=true` creates the two buckets on the development storage; the server then checks
that the public one reads anonymously and the private one does not, and refuses to start otherwise.
Without `DW_STORAGE_ENDPOINT` it starts without uploads and says so.

Once it has logged that it is listening, seed development data — once, in a second shell with the
same `DW_DATABASE_*`, because it needs the migrated database:

```bash
dart run bin/seed_dev.dart
```

It creates an administrator, two members who sign in with a fixed code, and enough members to page
through the admin table, in one transaction, and refuses to run twice. Never run it against
production: the fixed code is access to those accounts.

Verify before going further:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/health
```

`200` means the server is up and reaches its database.

In VS Code the **Server** launch configuration starts the same `bin/server.dart`, and carries no
environment of its own — it reads the same two sections, so pressing play and running it by hand are
the same run.

## 4. Run the app

On a phone, a simulator or the desktop:

```bash
cd my_app/my_app_flutter
flutter pub get
flutter run
```

The app calls `http://localhost:8080`, or `http://10.0.2.2:8080` on the Android emulator, where
`localhost` is the emulator itself. `lib/main.dart` picks between them; a deployed build is compiled
against a fixed address with `--dart-define=DW_BACKEND_URL=…`.

**In a browser the app calls its server on its own origin**, as a deployment serves it, so there is no
CORS to configure — locally either. The development proxy puts Flutter's web server and the API
behind one origin:

```bash
cd my_app/my_app_flutter
dart run dartway_cli:dartway dev web        # open http://localhost:8000
```

`dev web` starts `flutter run -d web-server` compiled against the proxy's origin and forwards `/dw/*`
(the live socket included) and `/health` to the server on `8080`. Open `http://localhost:8000`
exactly: to a browser, `127.0.0.1` is another origin.

The skeleton's Flutter package lists `dartway_cli` as a dev dependency, so `dart run dartway_cli:dartway`
runs the CLI version the project pinned. A globally activated `dartway` runs the project's commands
only when it is that version, and otherwise refuses and names the form above.

For a release build behind the same proxy:

```bash
cd my_app_flutter
flutter build web --dart-define=DW_BACKEND_URL=http://localhost:8000
dart run dartway_cli:dartway dev proxy --web-dir build/web
```

## 5. Sign in

Nothing is sent over SMS or e-mail in development: **the one-time code is printed in the server log**
as `Sign-in code for <identifier>: <code>`. Read it there. The code is checked, so "any code" does not
work.

The seeded accounts sign in with the code **`111111`**: the administrator `79990000001`, the members
`79990000002` and `boris@example.com`.

`DW_ADMIN_IDENTIFIER` makes the phone or e-mail it names an administrator on every start. The admin
role is granted by an admin, so the first one has to be declared somewhere, and it is declared per
environment rather than shipped: whoever receives the codes for that identifier is the admin, and a
default in a public template would hand every project that forgot to change it to a stranger. Unset,
the server starts anyway and warns that the admin panel is out of reach; a value that is neither a
phone nor an e-mail stops it from starting.

A real delivery replaces the log line in `deliverCode`, in `my_app_server/lib/src/core/auth.dart`.

A good first thing to try: sign in as the administrator in two browser windows, change a member's role
or an app setting in the admin panel, and watch the other window follow without a reload. That is the
whole stack — Postgres, a handler, a channel, a widget — the write end included.

## 6. The shape of a feature

1. **Contract**, in `my_app_shared/lib/src/`: a data object, the requests that read it with the
   channels they live on, the commands that change it.
2. **Server**, in `my_app_server/lib/src/`: a row class, and one handler per request and command with
   its access rule, publishing what a command changed.
3. `dart run dartway_cli:dartway generate` — codecs, the protocol registry, tables and the schema.
4. `dart run bin/migrate.dart create <name>` in the server package, with `DW_DATABASE_*` set — a
   migration drafted from the row classes. Review it: it is yours.
5. **App**: a widget reading `ref.watch(dw.request(MyRequest()))` and a button running
   `dw.action((_) => dw.command(MyCommand()))`, the texts in `lib/l10n/`.

A request or command without a handler stops the server from starting, deliberately. The steps in
full: [data objects and generation](../2-core/data-objects-and-generation.md),
[handlers and context](../4-server/handlers-and-context.md), [migrations](../4-server/migrations.md),
[the data layer](../3-flutter/data-layer.md).

## 7. The checks

From the project root:

```bash
(cd my_app_flutter && dart run dartway_cli:dartway generate --check) # generated code matches its sources
(cd my_app_server && dart run bin/migrate.dart check)     # migrations produce the schema (DW_DATABASE_*)
(cd my_app_flutter && dart run dartway_cli:dartway test)  # server tests on a real Postgres and storage
(cd my_app_shared && dart test)                           # the contract
(cd my_app_flutter && flutter test)                       # the app, on an in-memory server
(cd my_app_flutter && dart run dartway_cli:dartway check) # the conventions
```

- **`generate --check`** writes nothing and fails when a generated file is out of date. It runs the
  `dartway_generator` the server package resolved as a dev dependency, so the generator always
  matches the framework the project builds against.
- **`migrate.dart check`** replays the migrations into throwaway databases next to the one in
  `DW_DATABASE_*`, compares the result with the schema the row classes declare, and rolls them down
  and up again.
- **`dart run dartway_cli:dartway test`** starts a Postgres and a storage for the run, on ports Docker picks, passes them to
  the suite as `DW_DATABASE_*` and `DW_STORAGE_*`, and removes them when the run ends. Each test file
  creates its own database and buckets. Nothing is shared with the development containers or with
  another project — a fixed test port is how a suite ends up green against a neighbour's database.
  `--keep` leaves the containers up to inspect a failing run; arguments after `--` go to `dart test`.
- **`dart run dartway_cli:dartway check`** fails on error-level findings — the layout, features, the UI kit, stale
  generated code and, with `DW_DATABASE_*` set, the migrations check above. Warnings do not fail it.

## When it goes sideways

- **`pub get` prints one line and hangs.** The pub host is not answering; run `dartway doctor`.
- **The server exits at startup.** Read the output: it names the cause — a call without a handler
  (every such problem of the declaration is listed at once), a migration that failed, a bucket with
  the wrong access.
- **An empty list after sign-in.** Usually a correct access rule or channel rule, not a bug to loosen.
- **A local schema drifted beyond repair.** `docker compose down -v` recreates the database and
  destroys its data — a fair fix, and never one to run without deciding to lose the data.

## Where to go next

- [What DartWay is](what-is-dartway.md) — the ideas behind the steps above.
- [Project layout](project-layout.md) — the three packages and every folder in them.
- [The CLI](../5-tooling/cli.md) — every command and its options.
- [Testing](../5-tooling/testing.md) — the test tiers and what each proves.
- [Deploy](../5-tooling/deploy.md) — from `deploy/config.yaml` to a running stack.
