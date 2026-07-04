# dartway_cli

Command-line tool for the [DartWay](https://dartway.dev) framework.

```bash
dart pub global activate --source git https://github.com/dartway/dartway.git --git-path packages/dartway_cli --git-ref stable
```

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

Runs DartWay convention checks (`dartway_code_checker`) on the project's Flutter package. Extra arguments are passed through to the checker.

```bash
dartway check
dartway check --type featureStructure
```

## Environment variables

| Variable | Meaning |
|---|---|
| `DARTWAY_MONOREPO_DIR` | Local monorepo checkout to use instead of cloning (framework development) |
| `DARTWAY_REPO_URL` | Override the monorepo git URL |
| `DARTWAY_BRANCH` | Default channel (branch) for `create` / `setup-ai` |

The monorepo clone is cached in `~/.dartway/monorepo`.
