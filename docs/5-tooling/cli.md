# What does the `dartway` command do?

It is the front door and the toolbox: one command prints the whole setup instruction, one checks
whether the machine can run any of it, one creates a project, one installs the agent toolkit into
an existing one, two read your code back to you, and one deploys the server.

```bash
dart pub global activate dartway_cli
```

**The complete, current option list of any command is `dartway help <command>`** — and for the nested
ones, `dartway help deploy secret push`. That output is generated from the parser, so it cannot drift
from the code; `dartway --help` on its own lists commands only, which is what sends people looking for
a reference that does not need to exist. This page therefore does not restate every flag. It names the
ones whose *meaning* is not obvious from a one-line help string — what they protect, and what happens
if you reach for them without knowing.

Or straight from the monorepo, pinned to the verified channel:

```bash
dart pub global activate --source git https://github.com/dartway/dartway.git \
  --git-path packages/dartway_cli --git-ref stable
```

The CLI does not carry the framework inside itself. `create` and `setup-ai` read the DartWay
monorepo — a shallow clone cached in `~/.dartway/monorepo`, on the `stable` branch by default.
`stable` is the last state that was verified end to end; `master` is the development trunk and may
be mid-refactor. That is why the version of the CLI you installed does not decide what your
project gets — the channel does.

**The harness channel follows the framework channel, and the default is only right for a project on
the default.** A project that takes the `dartway_*` packages from `master` and installs its harness
from `stable` gets an agent instructed in the rules of a framework it is not running — and the
mismatch is silent, because both halves are internally consistent. It happened: a project on
`master` carried a `stable` harness five commits behind and was told to put code in `data/` and
`domain/`, the two folders the current layout check rejects. Take the harness from wherever the
packages come from:

```bash
dartway setup-ai --channel master   # a project whose pubspec points at master
```

## `dartway quickstart` — the instruction, printed

```bash
dartway quickstart
```

Prints the full setup brief to stdout: what the machine needs, how to create a project, the order
the bring-up steps come in and why, how to verify the server is actually answering, and how to hand
over the sign-in. It writes nothing and asks nothing.

This is the framework's entry point, and the reason it is a printed text rather than an extension
for one assistant: **whatever agent you use, its way in is two commands** —

```bash
dart pub global activate dartway_cli
dartway quickstart
```

— after which the instruction is in that agent's context and it proceeds on its own. A plugin for
one vendor would have made the front door of an open framework depend on a format we do not
control, and would have left everyone else with prose to copy. The brief is deliberately shell-
neutral: it states the step and the reason, and lets the agent phrase the command the way its own
platform wants.

It is equally readable by a human, and it is the same text an agent gets — there is no second,
friendlier version to drift from it.

## `dartway doctor` — is this machine ready?

```bash
dartway doctor
```

Checks the five things that break a first run, and prints the exact fix for each:

| Check | Why it is here |
|---|---|
| Dart `>=3.11` | The SDK running the CLI is the one that will run the project |
| Flutter `>=3.41` | |
| A responding Docker daemon | Postgres comes from it, and there is no second path. Installed-but-stopped is reported separately from missing |
| `serverpod_cli` matching the project's pin | The generator writes code for its own version; a drifted CLI produces a protocol that compiles and then misbehaves at runtime. Inside a project the expected version is read from the server package rather than assumed |
| The pub global bin directory on PATH | The cause of `dartway: command not found` right after a successful install. A warning, not a failure — the fallback is `dart pub global run dartway_cli:dartway` |

Exit code 1 if anything is blocking, 0 otherwise, so an agent or a CI step can branch on it. Run it
before `create` and again inside a project — the Serverpod check gets sharper once there is a pin
to read.

## `dartway create <project_name>` — a project that already runs

```bash
dartway create my_app
```

You get three packages — `my_app_server`, `my_app_client` (generated), `my_app_flutter` — plus the
agent toolkit in `.claude/`, and a git repository with an initial commit.

The source is `template/` in the monorepo: a **skeleton, not somebody's product**. Phone auth with
one-time codes, a `UserProfile` with roles, navigation with zone guards, an admin panel, a UI kit
as source you own — and zero domain models, because the domain is the part you write. The full
application built on the same framework lives in `example/`, and is a reference to read, not a
project to inherit. `create` has never handed you `example/`, and deliberately so: inheriting
somebody's fitness club means deleting their domain before writing yours.

What the copy does beyond copying:

- renames `dartway_starter` → your name and `DartwayStarter` → `MyApp` in every path and every
  text file (binaries are copied verbatim);
- skips build residue — `.dart_tool`, `build`, `.git`, `.idea`, `.fvm`, `ephemeral`,
  `node_modules`, `pubspec.lock`;
- strips the monorepo-only `dependency_overrides` block from every package pubspec — those
  overrides point at sibling folders that do not exist in your project, and what is left resolves
  from pub.dev like any other dependency.

Stripping that block is also the moment the framework constraints are read for the first time,
because **an overridden package has its constraints skipped entirely** — see
[what `create` changes](../1-getting-started/project-layout.md#what-create-changes-on-the-way-in).
Your project is where they finally have to hold, so if a `dartway create` fails to resolve, the
version line it names is the answer rather than a mystery.

The project name must be a lower_snake_case Dart identifier — it becomes three package names. The
target directory must not exist yet; `create` refuses rather than merging into it.

```bash
dartway create .
```

A dot covers the shape people actually start in — an empty folder already opened in an editor or an
agent — and uses that folder as the project root instead of nesting one inside it. The folder then
names the project, the way `flutter create .` does: `dartway-demo/` becomes `dartway_demo`, since a
folder may carry dashes and a Dart package may not. A name that cannot be converted is refused with
the reason rather than mangled.

The folder has to be empty; an initialized-but-empty git repository is allowed through, since that is
how such a folder often arrives, and the initial commit then lands in it rather than in a new one.

| Option | Meaning |
|---|---|
| `--channel` | Monorepo branch to create from. Default `stable`, or `DARTWAY_BRANCH` |
| `--local-repo` | Use a local monorepo checkout instead of cloning (framework development) |
| `--language` | The language the project writes its own texts in. Default English |
| `--notes-tracker` | `owner/repo` where framework findings are filed as issues. Defaults to the framework's own tracker; `none` keeps the journal local |
| `--no-git` | Skip `git init` and the initial commit |

The last thing `create` prints is not a wall of commands: it points at `dartway doctor` and
`dartway quickstart`, and says to ask whatever assistant you use to bring the project up. Every new
project ships a toolkit that knows this stack — telling people to type `docker compose up -d` by
hand while installing that toolkit was a contradiction. The manual sequence still exists, in the
project's `README.md`, for anyone who wants to see what actually happens.

## `dartway setup-ai` — the toolkit in a project you already have

```bash
dartway setup-ai --base-branch develop
```

Installs or updates `.claude/` in the current project: the methodology `CLAUDE.md`, the
`dartway-*` skills and the `commit` / `dartway-checkup` commands. It replaced the old
`setup-claude.sh` / `.ps1` scripts, which are gone.

It finds the project root through `git rev-parse --show-toplevel` (falling back to the current
directory), then detects the package layout by directory suffix: `*_server`, `*_client`,
`*_flutter` are required, `*_shared` is optional. Two packages with the same suffix, or none, and
the command stops with a layout error rather than guessing. The detected names are substituted
into the installed markdown, so the skills speak your package names, not placeholders.

`--language` records what the project writes its own texts in — feature specs, doc comments, its
journal — straight into the installed `CLAUDE.md`. It defaults to English and does not touch what
ships to other people: package APIs and error strings stay English either way.

`.claude/settings.json` is written only when the project has none, and never touched again: it
pre-approves this stack's build commands so a first run is not a queue of permission prompts, and
denies reading `config/passwords.yaml`. A project extends it; an update will not take those edits
away, at the price of an old default staying put until someone deletes the file.

Three things land outside `.claude/`. Two journals are created at the project root and added to
`.gitignore` unless they are already there: `dartway_notes.md` for what the *framework* got wrong —
which the project cannot fix in place, because the harness is overwritten on update — and
`dev_notes.md` for what this project itself carries and nobody else can fix. An existing journal is
never overwritten; its content is the project's. And leftovers of the old shell installer
(`tools/dw_claude_setup/`) are reported with the commands to remove them, never removed: that folder
is usually a gitlink, and taking it out means editing the git index.

That first journal is one end of a loop rather than a local file, and `--notes-tracker` is what names
the other end. A filed entry records `**Issue:** owner/repo#123` **instead of a status**, and the state
is then read from the tracker rather than restated in the file — a status written in both places is a
status that goes stale in one of them silently.

**It defaults to the framework's own tracker, and that default is the point.** Opting in would have
meant every project deciding a question it has no particular reason to think about, and the projects
that never got around to deciding are exactly the ones whose findings never left the laptop — which is
the failure this mechanism exists to end. `--notes-tracker owner/repo` sends them somewhere else
instead, for an installation that wants its developers' findings triaged internally first, and
`--notes-tracker none` keeps the journal purely local, at which point no command reaches the network.

Because the default now points at a public repository, the guard rails are not optional. What the
installed `CLAUDE.md` requires before an issue is created — the finding restated without this codebase
in it, English, a duplicate search, and an explicit yes from a human — is in
[The agent toolkit](agent-toolkit.md). Nothing files on its own.

Only managed files are overwritten — see [The agent toolkit](agent-toolkit.md) for what that means
and how to customize without losing your changes. Commit `.claude/` afterwards: it is a
generated-but-committed artifact, like the Serverpod client.

| Option | Meaning |
|---|---|
| `--base-branch` | Base branch of **this** project, used by the PR/commit skills. Default `master` |
| `--language` | The language the project writes its own texts in. Default English |
| `--notes-tracker` | `owner/repo` where framework findings are filed as issues. Defaults to the framework's own tracker; `none` keeps the journal local |
| `--channel` | Monorepo branch to take the toolkit from. Default `stable`, or `DARTWAY_BRANCH` |
| `--local-repo` | Use a local monorepo checkout instead of cloning |

## `dartway check` — the conventions, enforced

```bash
dartway check
dartway check --type forbiddenUiUsage
dartway check --level error
dartway check --dir lib/app/booking
```

Runs the built-in convention checks over the Flutter package and prints a per-feature report with
a grade for every feature. Errors fail the run (exit 1); warnings and infos are advisory. Run it
from the project root or from inside the `*_flutter` package — both work.

What it checks, and why those checks exist, is a page of its own:
[The conventions checker](conventions-checker.md).

## `dartway deploy` — the server, without a folder of shell scripts

```bash
dartway deploy setup --env staging          # once per server, and again for a template change
dartway deploy check --env staging
dartway deploy run --env staging
dartway deploy secret push --env production
```

Deployment is described by two files, and they do not overlap. `<project>_server/config/<env>.yaml`
is the Serverpod configuration you already maintain — domains, ports, database. `deploy/config.yaml`
adds only what Serverpod has no concept of: the host, the login, the repository and branch, the
certificate contact, and the domain serving the Flutter build. The CLI **reads** the Serverpod file;
it never rewrites it. That is the whole reason the pair stays honest — there is no second copy of a
domain to drift.

`setup` is what turns a bare server into one this project can be deployed to, and it is the only
subcommand that writes infrastructure: base packages and Docker, the unprivileged deployment user, the
secret store with the random-string credentials generated in place, the repository checkout, the
rendered `docker-compose.yml` and `nginx.conf`, the `.env` Compose reads, the firewall, and a
one-day self-signed certificate so Nginx can start at all — the real one cannot be issued until Nginx
is answering the challenge, and the first `run` replaces it.

**Idempotent throughout, and that is a feature rather than a disclaimer:** every step either finds
what it needs or creates it, and none replaces a value that already exists, so re-running it against a
live server is the supported way to pick up a change to the rendered templates. Two things stop it
rather than proceeding. A private repository over SSH needs a key the server owns — generated *on* the
server, so the private half never exists anywhere else — and setup halts with the public half printed,
asking for it to be registered as a **read-only** deploy key: the server only ever fetches, and a
writable key turns access to the box into access to the repository. And if the server already carries a
data volume under a different name than the rendered configuration would use, it refuses outright
instead of starting the stack — Compose would otherwise create an empty database beside the real one
and serve it, which looks like a successful deploy of an application that has lost everything.

`check` changes nothing and answers whether a deployment would work. Fourteen assertions on the
working copy, eight over the network — including that every `publicHost` resolves to the deployment
host, which is the mistake that otherwise burns a Let's Encrypt rate limit before anyone notices.
With the server unreachable it degrades: the SSH check fails, the rest report as skipped.

Two of the local assertions are about whether the images build at all. The rendered compose file builds both of them
from the project root — `<project>_server/Dockerfile` and `<project>_flutter/Dockerfile`, named by
convention rather than configured — so a project that never wrote one fails on the server, after the
checkout has already moved. The other is the shape of the server image's `ENTRYPOINT`: migrations
run as `docker compose run backend … --apply-migrations`, and shell form ignores appended arguments,
so an unnoticed shell form turns every migration into an ordinary server start that reports success.
The template ships the canonical pair; `server_entrypoint` remains the escape for an image you did
not write.

The web image gets one build argument, `DW_BACKEND_URL`, and it comes from `publicHost` in the
Serverpod configuration. A web build compiles the API address into itself, so something has to
supply it — having the deploy do it is what keeps the domain written down once. The template's
`main.dart` reads it through `String.fromEnvironment` and falls back to localhost for a local run.

**What the web image is allowed to let a browser keep is the other half of that image, and it fails
silently.** A Flutter web build hashes nothing: `index.html`, `flutter_bootstrap.js`, `flutter.js`,
`main.dart.js`, `main.dart.wasm` and everything under `assets/` are named identically in every
build. The rule everyone reaches for — "fingerprinted assets are immutable, cache them for a year"
— is correct for a bundler that puts a content hash in the name, and lands here on precisely the
files that change on every deploy. A browser that took one under a long `max-age` does not ask
again: it keeps running the previous build while the server serves the new one, with nothing to
see on either side. It is the shape of failure a deploy cannot report, because from the deploy's
point of view everything worked.

So the template ships the serving configuration rather than leaving each project to invent one —
`<project>_flutter/nginx.conf`, copied into the image by the Dockerfile beside it. It serves
everything a build emits with `Cache-Control: no-cache` (the copy is kept and merely has to be
confirmed, which with an ETag is a 304 rather than a download) and reserves the long-lived,
immutable rule for names that genuinely carry a content hash.

Two assertions guard it, and they ask different questions. `web-cache-policy` reads the
configuration the web image is built with — the file it copies, or a heredoc written straight into
the Dockerfile — resolves each Flutter entry point through Nginx's own `location` precedence, and
warns when one of them would be served for reuse without revalidation. It warns rather than
blocks: reading configuration text can miss an include outside the build context or a header some
front proxy adds. `web-cache-headers` asks the deployed site itself, over HTTPS, exactly as a
browser would, and errors on what it actually receives — there is nothing left to interpret in a
response header. A path that answers 404 is not part of that build and says nothing about caching.

**Fixing the configuration does not reach a browser that already holds a copy.** A response taken
under `max-age=2592000` stays fresh there for the rest of the thirty days and the browser will not
ask; no server-side change is capable of reaching it. Tell whoever you can reach to hard-reload or
clear site data, and for the rest either wait the window out or move the app to a URL that was
never poisoned. That asymmetry — cheap to prevent, impossible to revoke — is why these two
assertions exist at all.

`deploy/compose.override.yml` is where a project adds what a standard deployment does not have, and
a third local assertion guards the one thing that does not belong in it: a `build` block for the
`web` service. Overriding `web` for a label or a limit is fine, but building it there means naming
the API address a second time, and nothing compares the two copies — the image keeps building
successfully against yesterday's API, which is the failure mode with no error message. A warning
rather than an error, because only the build block reintroduces the duplicate.

The override is **never copied to the server**. Every Compose call the CLI issues names it explicitly
— `docker compose -f docker-compose.yml -f deploy/compose.override.yml …` — so the file being merged
is the one in the checkout, which `git reset --hard` refreshes on every deploy. It used to be copied
to `docker-compose.override.yml` beside the rendered file, the name Compose loads on its own, on the
grounds that nothing then has to remember the flag; but there is nobody to forget it, since every
invocation is built in one place, and the price was a second copy that a deploy silently preferred
over the committed one for as long as `setup` was not re-run. A server carrying that copy has it
moved to `docker-compose.override.yml.retired` on the next `setup` or `run` — renamed rather than
deleted, in case somebody edited it on the box while debugging.

`run` retires that copy, updates the checkout, rebuilds, applies migrations and restarts, then polls
every public URL. It does not render `docker-compose.yml` or `nginx.conf` — a deploy that re-renders
infrastructure on every push turns a routine change into an infrastructure one.

**The migration step prints what the container said, and fails on it.** It used to print its title
and nothing else, because a step's output was shown only when its exit code was non-zero — and this
particular exit code cannot be asked. Serverpod wraps the whole apply in a `try`/`catch`: a failure
sets `verified = false`, and `verified` aborts the process **only in development**. Outside it the
failure is swallowed, the maintenance role ends with the exit code it started with, and a container
that applied nothing exits 0 exactly like one that applied everything. So "we deployed" stopped
implying "the schema caught up": the application went on running new code against an old schema, the
deploy log said nothing, and re-running it produced the same green step and the same broken schema.

The outcome is only ever stated in the text, so the text is now read and shown. `Applied database
migration:` with the versions, or `Latest database migration already applied.`, passes. Any of
`Failed to apply migration <version>.`, `Failed to apply database migrations.` or Serverpod's own
`The database does not match the target database:` fails the step — the last of those being the case
where nothing threw and the schema still did not catch up. So does silence: a container that exits 0
without mentioning the schema never reached the migration code, which usually means an `ENTRYPOINT`
in shell form (see `server_entrypoint`). A failed step stops the deploy before `up`, so the previous
version keeps serving while you read the reason, which is quoted in the log along with what to run
next.

There is deliberately no separate schema assertion in `deploy check`. The authoritative comparison
already runs inside the migration container — Serverpod checks the live schema against the target
definition table by table on every maintenance start — and the fix was to stop discarding its
verdict, not to add a second one. A `check` that compared `migration_registry.txt` against the
`serverpod_migrations` table would compare two version strings rather than a schema, go green on a
database whose row says the right version while a table is missing, and answer before the deploy has
run at all: green exactly where the deploy is red.

`secret` moves credentials between the maintainer's `passwords.yaml` and a server, one environment
at a time: `push` sends `shared` plus that environment, `pull` brings back what the server has and
the file lacks, `list` shows names only. `set` stores one value, `put-file` uploads a whole file — a
service-account JSON and the like, which reaches the container only once it is also named under
`requires.files` — and `init` creates the store and fills in the keys that are just
random strings, which `setup` has already done by the time you would think to run it. Values travel on
stdin, never as arguments, so they appear in neither shell history nor a remote process list. Two
guards refuse a push that would lose information — one for keys the server has and the file does not,
one for values the file would blank. Both are overridable by the flags below, neither is silent.

Every subcommand takes `--env <environment>` and refuses to guess when it is missing — it answers with
the environments `deploy/config.yaml` actually declares. All of them also accept `--as <login>` and
`--identity <key>` for the SSH connection, defaulting to `ssh_user` from the config and to your agent.
The rest are the flags worth knowing before you need them:

| Subcommand | Flag | What it is for |
|---|---|---|
| `setup` | `--dry-run` | Print the rendered `docker-compose.yml` and `nginx.conf`, and what would be uploaded beside them, without touching the server. The way to review a template change |
| `check` | `--local` | Skip DNS and the server; assert over the working copy only. The form that needs no SSH key and no host yet — the fourteen working-copy assertions still run, the eight network ones report as skipped |
| `run` | `--dry-run` | Print the plan and change nothing |
| `run` | `--skip-git-update` | Deploy what is already checked out on the server, without fetching. For a rebuild of the same commit — and the flag to suspect when a deploy "did not pick up" a push |
| `secret push` | `--dry-run` | Report what would be sent, send nothing |
| `secret push` | `--prune` | Allow dropping keys the server has and `passwords.yaml` does not. Off by default: the usual cause of that difference is a local file that is behind, not a server holding junk |
| `secret push` | `--allow-emptying` | Allow replacing a value the server has with an empty one. Off by default, for the same reason from the other direction |
| `secret pull` | `--dry-run` | Report what would change locally, write nothing |
| `secret set` | `--section` | Which `passwords.yaml` section to write to. Defaults to the environment; `shared` is for values common to every run mode |
| `secret put-file` | `--name` | Name to store the file under, if not its basename |

| Key in `deploy/config.yaml` | When you need it |
|---|---|
| `host`, `ssh_user`, `deploy_user`, `os` | always |
| `repo`, `branch` | always |
| `ssl_email`, `web_app_domain` | always |
| `requires.secrets` | to have `check` catch a credential nobody delivered. Short values only — a token, an identifier, a password |
| `requires.files` | a credential that is a whole document — a service-account JSON, an `.env` for an integration. It belongs here rather than in `passwords.yaml` whatever its length: that file is the master copy of every environment's secrets, and an unquoted value starting with `{` is read by YAML as a mapping rather than as text. Each entry is delivered with `secret put-file` and **mounted read-only at `/app/config/<name>`** in the server container, beside `passwords.yaml` — the application reads it as `config/<name>`, the same path it reads locally. `check` asserts the mount, not the delivery: it asks the server for the configuration Compose will actually run and looks for the file in it, because "the file is on the machine" is green exactly where the deploy is red. An entry is a file name, not a pattern or a path — a mount names one path on each side |
| `registry_mirror` | pulling base images through a mirror |
| `firewall_ports` | a port beyond SSH, 80 and 443 |
| `server_entrypoint` | only when the Dockerfile declares `ENTRYPOINT` in shell form — that form ignores the arguments `docker compose run` appends, so migrations would silently start an ordinary server instead. Setting it is also what tells `check` the shell form is deliberate |

## `dartway stats` — what actually grew this week

```bash
dartway stats
```

Files, total lines, average, max and min per top-level area of the Flutter package (`app*`,
`auth*`, `common*`, `admin*`), plus a total. No grades, no opinions — it is the counter you check
before and after a refactor, or on Friday, to see where the code went.

## Environment variables

| Variable | Meaning |
|---|---|
| `DARTWAY_BRANCH` | Default channel for `create` / `setup-ai` |
| `DARTWAY_MONOREPO_DIR` | Local monorepo checkout to use instead of cloning |
| `DARTWAY_REPO_URL` | Override the monorepo git URL |

The clone is cached in `~/.dartway/monorepo` and refreshed with a shallow fetch on every run, so
the second `create` on a machine costs a fetch rather than a clone.
