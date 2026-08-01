# What does the `dartway` command do?

Four commands: one creates a project, one installs the agent toolkit into an existing one, and two
read your code back to you — the conventions checker and a size report.

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
  overrides point at sibling folders that do not exist in your project;
- retargets git dependencies from `ref: master` to `ref: stable`, so a standalone project follows
  the verified channel and not the trunk.

The project name must be a lower_snake_case Dart identifier — it becomes three package names. The
target directory must not exist yet; `create` refuses rather than merging into it.

| Option | Meaning |
|---|---|
| `--channel` | Monorepo branch to create from. Default `stable`, or `DARTWAY_BRANCH` |
| `--local-repo` | Use a local monorepo checkout instead of cloning (framework development) |
| `--no-git` | Skip `git init` and the initial commit |

The last thing `create` prints is not a wall of commands. It says to `cd` in and run `claude`,
then ask for the project to come up in your own words. Every new project ships an AI toolkit that
knows this stack — telling people to type `docker compose up -d` by hand while installing that
toolkit was a contradiction. The manual sequence still exists, in the project's `README.md`, for
people without an agent at hand and for anyone who wants to see what actually happens.

## `dartway setup-ai` — the toolkit in a project you already have

```bash
dartway setup-ai --base-branch develop
```

Installs or updates `.claude/` in the current project: the methodology `CLAUDE.md`, the
`dartway-*` skills and the `commit` / `dartway-audit` commands. It replaces the old
`setup-claude.sh` / `.ps1` scripts.

It finds the project root through `git rev-parse --show-toplevel` (falling back to the current
directory), then detects the package layout by directory suffix: `*_server`, `*_client`,
`*_flutter` are required, `*_shared` is optional. Two packages with the same suffix, or none, and
the command stops with a layout error rather than guessing. The detected names are substituted
into the installed markdown, so the skills speak your package names, not placeholders.

`--language` records what the project writes its own texts in — feature specs, doc comments, its
journal — straight into the installed `CLAUDE.md`. It defaults to English and does not touch what
ships to other people: package APIs and error strings stay English either way.

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

`check` changes nothing and answers whether a deployment would work. Ten assertions on the working
copy, seven over the network — including that every `publicHost` resolves to the deployment host,
which is the mistake that otherwise burns a Let's Encrypt rate limit before anyone notices. With the
server unreachable it degrades: the SSH check fails, the rest report as skipped.

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
| `server_entrypoint` | only when the Dockerfile declares `ENTRYPOINT` in shell form — that form ignores the arguments `docker compose run` appends, so migrations would silently start an ordinary server instead |

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
