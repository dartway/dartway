# What does the `dartway` command do?

It is the front door and the toolbox: one command prints the whole setup instruction, one checks
whether the machine can run any of it, one creates a project, one installs the agent toolkit into
an existing one, two read your code back to you, and one deploys the server.

```bash
dart pub global activate dartway_cli
```

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
`dartway-*` skills and the `commit` / `dartway-audit` commands. It replaced the old
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

Two things land outside `.claude/`. `dartway_notes.md` is created at the project root (and added to
`.gitignore`) unless it is already there — the journal of what the *framework* got wrong, which the
project cannot fix in place because the harness is overwritten on update. And leftovers of the old
shell installer (`tools/dw_claude_setup/`) are reported with the commands to remove them, never
removed: that folder is usually a gitlink, and taking it out means editing the git index.

Only managed files are overwritten — see [The agent toolkit](agent-toolkit.md) for what that means
and how to customize without losing your changes. Commit `.claude/` afterwards: it is a
generated-but-committed artifact, like the Serverpod client.

| Option | Meaning |
|---|---|
| `--base-branch` | Base branch of **this** project, used by the PR/commit skills. Default `master` |
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

`check` changes nothing and answers whether a deployment would work. Twelve assertions on the
working copy, seven over the network — including that every `publicHost` resolves to the deployment
host, which is the mistake that otherwise burns a Let's Encrypt rate limit before anyone notices.
With the server unreachable it degrades: the SSH check fails, the rest report as skipped.

Two of the local assertions are about the images. The rendered compose file builds both of them
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

`run` updates the checkout, rebuilds, applies migrations and restarts, then polls every public URL.
It does not render `docker-compose.yml` or `nginx.conf` — a deploy that re-renders infrastructure on
every push turns a routine change into an infrastructure one.

`secret` moves credentials between the maintainer's `passwords.yaml` and a server, one environment
at a time: `push` sends `shared` plus that environment, `pull` brings back what the server has and
the file lacks, `list` shows names only. Values travel on stdin, never as arguments, so they appear
in neither shell history nor a remote process list. Two guards refuse a push that would lose
information — one for keys the server has and the file does not, one for values the file would
blank. Both are overridable, neither is silent.

| Key in `deploy/config.yaml` | When you need it |
|---|---|
| `host`, `ssh_user`, `deploy_user`, `os` | always |
| `repo`, `branch` | always |
| `ssl_email`, `web_app_domain` | always |
| `requires.secrets`, `requires.files` | to have `check` catch a credential nobody delivered |
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
