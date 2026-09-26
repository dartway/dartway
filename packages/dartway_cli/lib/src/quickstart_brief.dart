/// The agent-facing brief printed by `dartway quickstart`.
///
/// This is the single source of truth for "how do I get a DartWay project
/// running". It is deliberately plain markdown on stdout and mentions no
/// particular assistant: the entry point to DartWay must not be one vendor's
/// plugin format. A human pastes two commands — activate the CLI, run
/// `quickstart` — and whatever agent is at hand reads the rest and decides how
/// to execute it on its own platform.
///
/// Keep it executable, not inspirational: every step is a command, a reason it
/// comes in that order, or a fact to verify. Anything the reader cannot act on
/// belongs in the docs, not here.
const String quickstartBrief = r'''
# DartWay — from an empty folder to a running fullstack app

You are most likely an AI coding assistant, and this text is the whole instruction.
Read it, then carry it out. **Report facts** — the applied migrations, the HTTP status
code, the identifier to sign in with — never assumptions, and never a sign-in code you
did not read from the server output.

If `dartway` is not on PATH, every command below also works as:

    dart pub global run dartway_cli:dartway <command>

## 1. Check the machine

    dartway doctor

It reports Dart, Flutter, git, a reachable pub host, a running Docker daemon and whether
globally activated executables are on PATH, and prints the exact fix for whatever is
missing. Ask the human to install or start what it names.

**Do not work around a stopped Docker** — Postgres and the object storage come from it,
for development and for tests alike, and there is no second path. Docker Desktop cannot
be installed unattended; that one is the human's job.

**A failing pub host check is also the human's job**, and it stops everything: every step
below begins with `pub get`, and pub sets no deadline on a connection that opens and then
goes quiet. If you skip past this one you will not get an error — you will get a resolve
step that prints one line and hangs until your session is killed.

## 2. Create the project

Skip this step if you are already inside a DartWay project — a folder holding packages
whose names end in `_shared`, `_server` and `_flutter`.

From the folder that should *contain* the project:

    dartway create my_app

Or, if the current folder is empty and is meant to *be* the project, name it with a dot
and the folder names the project — `dartway-demo/` becomes `dartway_demo`:

    dartway create .

The name must be lower_snake_case: it becomes the package names, the type names and the
storage bucket names. You get `my_app_shared` (the contract: data objects, requests,
commands, channels, refusal codes), `my_app_server` (handlers, rows, migrations),
`my_app_flutter` (the app), an AI toolkit in `.claude/`, and a git repository with an
initial commit.

What is inside is a skeleton, not somebody's product: sign-in by a one-time code to a
phone or an e-mail with the terms accepted on sign-up, a profile with a photo and its
sign-in identifiers, roles, an admin panel (live counters, a members table, a card per
member, settings), navigation with zone guards, a UI kit as source the project owns, and
tests on both sides — and zero domain models.

## 3. Bring it up

The order is not arbitrary; each line explains why it comes where it does.

    cd my_app/my_app_server
    docker compose up -d
    dart pub get
    dart run bin/server.dart
    dart run bin/seed_dev.dart     # once, in a second shell

The server is configured by its environment alone — there is no configuration file
it reads. **Nothing has to be exported**: `bin/server.dart`, the seed and `migrate`
put `deploy/config.yaml > local` — the coordinates of those two containers, committed
— into that environment through `DwLocalEnvironment`, together with the git-ignored
`deploy/secrets.yaml > local`. An exported variable beats both files.

    dartway secret list --env local            # what is set, what is missing
    dartway secret set <KEY> --env local       # a value that is yours alone

- **`docker compose up -d`** starts Postgres (host port 8090) and RustFS, the object
  storage for uploads (8100, console 8101). The first run pulls images and can take
  minutes. There is no test database among them: `dartway test` starts its own.
- **Wait for the database to accept connections before starting the server.** A
  container reported as "Started" is not yet Postgres listening. Poll —
  `docker compose exec -T postgres pg_isready -U postgres` until it succeeds — rather
  than sleeping a fixed number of seconds.
- **The server migrates the database as it starts**, and exits non-zero naming the
  migration when one fails. `DW_STORAGE_PROVISION=true` creates the two buckets on the
  development storage; the server then checks that the public one reads anonymously and
  the private one does not, and refuses to start otherwise.
- **Ask the human which phone number or e-mail should be the administrator** and put it
  in `DW_ADMIN_IDENTIFIER` — the commented line in `deploy/config.yaml > local`. Ask rather than choose, and never invent a value: whoever can
  *receive* the one-time code on that identifier becomes the administrator. Unset, the
  server still starts and says on boot that the admin panel is out of reach.
- **`bin/server.dart` is a long-running process.** Start it in the background. Waiting
  for it to exit will hang you until the session is killed. Run the seed once the server
  has logged `listening`: it needs the migrated database.

Then the app, in a separate process:

    cd my_app/my_app_flutter
    flutter pub get
    flutter run          # desktop, iOS simulator or Android emulator

In a browser the app calls its server **on its own origin**, as the deployment serves it
— there is no CORS to configure. Serve both through the development proxy:

    cd my_app/my_app_flutter
    dart run dartway_cli:dartway dev web            # flutter's web server + the API on http://localhost:8000
    # or a release build:
    flutter build web --dart-define=DW_BACKEND_URL=http://localhost:8000
    dart run dartway_cli:dartway dev proxy --web-dir build/web

Open `http://localhost:8000` exactly — to a browser `127.0.0.1` is another origin.

## 4. Verify before reporting success

The server must answer on port 8080:

    curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health

Expect `200`. Use whatever HTTP client your platform actually has — the point is the status
code, not this exact command line.

## 5. Hand over the sign-in

Nothing is sent over SMS or e-mail in development: **the one-time code is printed in the
server log** (`Sign-in code for <identifier>: <code>`). Read the real one out of the
server output and pass it on — telling the human to "enter anything" is wrong: the code
is checked. The seeded accounts sign in with the code `111111` (the seed prints them).
Tell the human to sign in with the identifier in `DW_ADMIN_IDENTIFIER`; the server logs
on boot whether it created or promoted that administrator.

A good first thing to show: sign in as the admin in two browser windows, change a
member's role or the app name in the admin panel, and watch the other window follow
without a reload. That is the whole stack — Postgres, a handler, a live channel, a
widget — proving itself, the write end included.

## 6. What the project expects from you next

The conventions are not optional; DartWay is opinionated on purpose, and a feature written
against the grain costs more than it saves.

- `README.md` in the created project walks through a feature end to end.
- `.claude/` holds the toolkit: the laws, and step-by-step skills.
- `dartway check` grades the project against the conventions and fails on errors —
  including generated code that is out of date and, with `DW_DATABASE_*` set,
  migrations that do not produce the schema.

The shape of a feature, end to end: a data object, the requests that read it and the
commands that change it in `*_shared` → a row class and one handler per request and
command, each with its access rule, in `*_server` → `dartway generate` →
`dart run bin/migrate.dart create <name>` → a widget reading
`ref.watch(dw.request(MyRequest()))` and a button running
`dw.action((_) => dw.command(MyCommand()))`. A request or command without a handler stops
the server from starting, deliberately.

Before reporting a change done:

    dartway generate --check
    dartway test                   # server acceptance: a Postgres and a storage of its own
    (cd my_app_shared && dart test)
    (cd my_app_flutter && flutter test)
    dartway check

## Two things never to do

- **Never print secrets** — database passwords, storage keys, tokens, a delivered code
  meant for someone else — not while diagnosing, not to show what is configured. Name
  the variable instead.
- **Never delete the database volume without asking** (`docker compose down -v` destroys
  the data). It is a fair fix for a drifted local schema, but it is the human's call.

Docs: https://dartway.dev · Source: https://github.com/dartway/dartway
''';
