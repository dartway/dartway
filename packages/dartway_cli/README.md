# dartway_cli

Command-line tool for the [DartWay](https://dartway.dev) framework.

```bash
dart pub global activate dartway_cli
```

Or straight from the monorepo (the `stable` channel):

```bash
dart pub global activate --source git https://github.com/dartway/dartway.git --git-path packages/dartway_cli --git-ref stable
```

Note: `dartway create` fetches the project template from the monorepo git repository (`stable` channel) regardless of how the CLI itself was installed.

## Commands

### `dartway create <project_name>`

Creates a new project from the canonical DartWay template (the monorepo `example/` app): copies it, renames everything to your project name, strips monorepo-only `dependency_overrides`, retargets git dependencies to the `stable` channel, installs the AI toolkit into `.claude/` and initializes a git repository.

```bash
dartway create my_app
```

Options: `--channel` (monorepo branch, default `stable`), `--local-repo` (use a local monorepo checkout), `--no-git`.

### `dartway setup-ai`

Installs or updates the DartWay AI toolkit (Claude Code skills, commands and methodology) in the current project's `.claude/` directory. `.claude/` is a generated-but-committed artifact: only managed files (`CLAUDE.md`, `dartway-*` skills, `commit`/`dartway-audit` commands) are overwritten — your own skills and commands survive updates.

```bash
dartway setup-ai --base-branch develop
```

Options: `--base-branch` (this project's base branch for PR/commit skills, default `master`), `--channel`, `--local-repo`.

### `dartway check`

Runs the built-in DartWay convention checks on the project's Flutter package: ui_kit hygiene (part-of directives, no text constants, no raw styles outside ui_kit), feature structure (one entry point, only `widgets/`+`logic/` subfolders, no cross-feature widget/logic imports) and file length as a soft signal (>120 lines — info, >200 — warning). Only error-severity findings fail the run; warnings and infos are advisory.

```bash
dartway check
dartway check --type forbiddenUiUsage
dartway check --level error
```

### `dartway stats`

Prints code-size statistics (files, lines, avg/max/min) per feature folder of the Flutter package.

```bash
dartway stats
```

## Environment variables

| Variable | Meaning |
|---|---|
| `DARTWAY_MONOREPO_DIR` | Local monorepo checkout to use instead of cloning (framework development) |
| `DARTWAY_REPO_URL` | Override the monorepo git URL |
| `DARTWAY_BRANCH` | Default channel (branch) for `create` / `setup-ai` |

The monorepo clone is cached in `~/.dartway/monorepo`.
