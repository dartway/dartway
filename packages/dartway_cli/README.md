# dartway_cli

Command-line tool for the [DartWay](https://dartway.dev) framework.

```bash
dart pub global activate dartway_cli
```

Or straight from the monorepo (the `stable` channel):

```bash
dart pub global activate --source git https://github.com/dartway/dartway.git --git-path packages/dartway_cli --git-ref stable
```

`create`, `setup-ai` and `update` take the template and the toolkit from a checkout you name
(`--local-repo`, `--framework-path`), else from a channel you choose (`--channel`,
`DARTWAY_BRANCH`), else from the monorepo the CLI itself was activated from (`--source path` or
`--source git` — its own revision), else from the `stable` channel.

## Commands

| Command | What it does |
|---|---|
| `dartway quickstart` | Prints the path from nothing to a running app, for a person or an agent |
| `dartway doctor` | Checks the machine: Dart, Flutter, git, a reachable pub host, Docker |
| `dartway create <name>` | A new project from the skeleton — three packages, the toolkit, a git repo |
| `dartway setup-ai` | Installs or updates the AI toolkit in a project's `.claude/` |
| `dartway update` | Carries a project onto a newer framework version, migration notes and all |
| `dartway generate` | Runs the project's generator: DTO codecs, the protocol registry, row tables and schema |
| `dartway check` | The conventions, enforced: layout, generated code, migrations |
| `dartway dev` | The web app and the server on one origin, shaped like the deployment |
| `dartway test` | Server acceptance tests against a Postgres and storage started for the run |
| `dartway deploy` | The server to a host, from `deploy/config.yaml` — no folder of shell scripts |
| `dartway secret` | The values that live outside Git |
| `dartway stats` | Code-size statistics per feature folder |

Every command's flags, environment variables and what it actually does:
[the CLI](https://dartway.dev/5-tooling/cli).
