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
