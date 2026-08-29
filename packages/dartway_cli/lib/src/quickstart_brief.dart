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
code, the phone number to sign in with — never assumptions, and never a sign-in code
you did not read from the server output.

If `dartway` is not on PATH, every command below also works as:

    dart pub global run dartway_cli:dartway <command>

## 1. Check the machine

    dartway doctor

It reports Dart, Flutter, git, a reachable pub host, a running Docker daemon and the
Serverpod CLI pin, and prints the exact fix for whatever is missing. Ask the human to
install or start what it names.

**Do not work around a stopped Docker** — the database comes from it, and there is no
second path. Docker Desktop cannot be installed unattended; that one is the human's job.

**A failing pub host check is also the human's job**, and it stops everything: every step
below begins with `pub get`, and pub sets no deadline on a connection that opens and then
goes quiet. If you skip past this one you will not get an error — you will get a resolve
step that prints one line and hangs until your session is killed.

## 2. Create the project

Skip this step if you are already inside a DartWay project — that is a folder holding
three packages whose names end in `_server`, `_client` and `_flutter`.

From the folder that should *contain* the project:

    dartway create my_app

Or, if the current folder is empty and is meant to *be* the project, name it with a dot
and the folder names the project — `dartway-demo/` becomes `dartway_demo`:

    dartway create .

The name must be lower_snake_case: it becomes three Dart package names. You get
`my_app_server` (backend), `my_app_client` (generated protocol — never edited by hand),
`my_app_flutter` (the app), an AI toolkit in `.claude/`, and a git repository with an
initial commit.

What is inside is a skeleton, not somebody's product: passwordless phone auth, a
`UserProfile` with roles, navigation with zone guards, an admin panel, a UI kit as source
the project owns — and zero domain models.

## 3. Bring it up

The order is not arbitrary; each line explains why it comes where it does.

    cd my_app/my_app_server
    dart pub get
    docker compose up -d
    dart bin/main.dart --apply-migrations --role maintenance
    # set bootstrapAdminIdentifier in config/passwords.yaml — see below
    dart bin/main.dart

- **`docker compose up -d`** starts Postgres for development (host port 8090) and object
  storage for uploads (8100, console 8101). The first run pulls images and can take minutes.
  There is no test database among them: `dartway test` creates one for the run, on a port
  Docker picks, and removes it at the end.
- **Wait for the database to accept connections before migrating.** A container reported as
  "Started" is not yet Postgres listening; migrating in that window fails with
  `connection refused`. Poll for readiness — `docker compose exec -T postgres pg_isready -U postgres`
  until it succeeds — rather than sleeping a fixed number of seconds.
- **`--role maintenance` is what makes the migration step finish.** Without it the process
  applies the schema and then keeps serving, and you wait forever for a command that will
  never return.
- **Ask the human to put the phone number they want to be the admin** into
  `bootstrapAdminIdentifier`, under `development:` in `config/passwords.yaml`, before the last
  line. Ask rather than choose, and never invent a value: whoever can *receive* the one-time
  code on that number becomes the administrator, so it is theirs to pick — and that file is
  one you must not read (see the end of this brief). Left empty, the server still starts and
  says on boot that the admin panel is out of reach, so this postpones the admin panel rather
  than blocking anything.
- **The last line is a long-running process.** Start it in the background. Waiting for it to
  exit will hang you until the session is killed.

Then the app, in a separate process:

    cd my_app/my_app_flutter
    flutter pub get
    flutter run          # add `-d chrome` to pin it to the browser

On an Android device or emulator, `localhost` is the phone rather than the host machine —
`lib/main.dart` carries a LAN address for that case. Web, desktop and the iOS simulator
need no change.

## 4. Verify before reporting success

The server must answer on port 8080:

    curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/

Expect `200`. Use whatever HTTP client your platform actually has — the point is the status
code, not this exact command line.

## 5. Hand over the sign-in

The database starts empty — there is no account until someone registers. Tell the human to
register in the app with the number you put in `bootstrapAdminIdentifier`; the server logs on
boot whether it created or promoted that administrator, or that the key is unset, so read that
line and report it. **The one-time code is printed in the server console** — read the real one
out of the server output and pass it on. Nothing is sent over SMS in development, and telling
the human to "enter anything" is wrong: the code is checked.

A good first thing to show: sign in as the admin, set the app name in the admin panel — it
starts empty, which is a legitimate state and not a missing step — and watch the home screen
of a second window update without a reload. That is the whole stack — Postgres, a CRUD config,
a typed live list, a widget — proving itself, the write end included.

## 6. What the project expects from you next

The conventions are not optional; DartWay is opinionated on purpose, and a feature written
against the grain costs more than it saves.

- `.claude/CLAUDE.md` in the created project states the laws: CRUD configs instead of
  endpoints, domain-first models, what a feature is, where a building block goes.
- `.claude/skills/dartway-*` are step-by-step playbooks: bringing the project up, models,
  CRUD configs, the data layer, navigation, the UI kit, finishing a task. They are markdown
  — readable by any assistant, not only the one that ships that folder format.
- `dartway check` grades the Flutter package against those conventions and fails on errors.

The shape of a feature, end to end: a Serverpod model in `.spy.yaml` → `serverpod generate`
→ a `DwCrudConfig` registered in `crudConfigurations` → a default instance in
`lib/core/default_models.dart` → a widget reading `ref.watch(dw.repo.modelList<T>())`.
No endpoint is written at any point. A model with no config is reachable by nobody: access
is closed until it is opened, deliberately.

## Two things never to do

- **Never print the contents of `config/passwords.yaml`** — not while diagnosing, not to
  show what is configured. Name the missing key instead.
- **Never delete the database volume without asking** (`docker compose down -v` destroys the
  data). It is a fair fix for a drifted local schema, but it is the human's call.

Docs: https://dartway.dev · Source: https://github.com/dartway/dartway
''';
