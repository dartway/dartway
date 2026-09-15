# dartway_cli

Command-line tool for the [DartWay](https://dartway.dev) framework.

```bash
dart pub global activate dartway_cli
```

Or straight from the monorepo (the `stable` channel):

```bash
dart pub global activate --source git https://github.com/dartway/dartway.git --git-path packages/dartway_cli --git-ref stable
```

`create`, `setup-ai` and `update` take the template and the toolkit from a checkout you name (`--local-repo`, `--framework-path`), else from a channel you choose (`--channel`, `DARTWAY_BRANCH`), else from the monorepo the CLI itself was activated from (`--source path` or `--source git` — its own revision), else from the `stable` channel.

## Commands

### `dartway create <project_name>`

Creates a new project from the DartWay skeleton (the monorepo `template/`): copies it, names everything after your project — the `*_shared`, `*_server` and `*_flutter` packages, the types, the generated registry and schema, the storage bucket defaults — formats the result, strips monorepo-only `dependency_overrides`, installs the AI toolkit into `.claude/` and initializes a git repository.

```bash
dartway create my_app
dartway create .        # the current, empty folder names the project
```

Options: `--channel` (monorepo branch; default: the checkout the CLI runs from, else `stable`), `--local-repo` (use a local monorepo checkout), `--framework-path <monorepo>` (resolve the framework packages from a local checkout by path instead of pub.dev — for framework development and unpublished versions; takes the template from the same checkout), `--language`, `--notes-tracker`, `--no-git`.

### `dartway generate`

Runs the project's `dartway_generator` (a dev dependency of the server package): DTO codecs and the protocol registry in `*_shared`, row tables and the schema in `*_server`. `--check` writes nothing and fails when a generated file is out of date or stale.

### `dartway test`

Runs the server package's tests against a Postgres and a MinIO started for the run on ports Docker picks, passing `DW_DATABASE_*` and `DW_STORAGE_*`, and removes both afterwards. `--no-storage` for a server without uploads, `--keep` to inspect what a failing run left behind, `--image` / `--storage-image` to pick the images.

### `dartway dev proxy` · `dartway dev web`

Local web development on one origin, shaped like the deployment: `/dw/*` (the live socket included) and `/health` go to the server, everything else to a Flutter web build (`--web-dir`) or to `flutter run -d web-server` (`dev web`). No CORS.

### `dartway setup-ai`

Installs or updates the DartWay AI toolkit (Claude Code skills, commands and methodology) in the current project's `.claude/` directory. `.claude/` is a generated-but-committed artifact: only managed files (`CLAUDE.md`, `dartway-*` skills, `commit`/`dartway-checkup` commands) are overwritten — your own skills and commands survive updates.

```bash
dartway setup-ai --base-branch develop
```

Options: `--base-branch` (this project's base branch for PR/commit skills, default `master`), `--channel`, `--local-repo`.

### `dartway check`

Runs the built-in DartWay convention checks: the project layout, the app's localization wiring, ui_kit hygiene (part-of directives, no text constants, no raw styles outside ui_kit), feature structure (one entry point, only `widgets/`+`logic/` subfolders, no cross-feature widget/logic imports, a `DwFeatureSpec` per feature), file length as a soft signal, framework git refs locked to one commit, generated code up to date (`generatedCodeStale`, via `dartway_generator --check`) and — when `DW_DATABASE_*` names a Postgres — migrations that produce the row classes' schema (`migrationsDrift`, via `bin/migrate.dart check`). Only error-severity findings fail the run; warnings and infos are advisory. `--dir <folder>` limits the run to one folder of the Flutter package, `--type <check>` to a single check.

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
| `DARTWAY_BRANCH` | Channel (branch) for `create` / `setup-ai` / `update` when `--channel` is not given; wins over the checkout the CLI runs from |

The monorepo clone is cached in `~/.dartway/monorepo`.
