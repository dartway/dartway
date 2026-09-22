# What does the `dartway` command do?

It is the front door and the toolbox of a project: one command prints the whole setup instruction,
one checks the machine, one creates a project, two install and update the agent toolkit, one runs
the generator, one checks the conventions, one serves the web app and the server on one origin, one
runs the server tests on a database of their own, one deploys, and one counts lines.

```bash
dart pub global activate dartway_cli
```

**Inside a project, run the CLI the project pins.** Every DartWay project carries `dartway_cli` as a
dev dependency of its Flutter package, at the same version as the rest of the framework it pins:

```bash
dart run dartway_cli:dartway generate       # the project's own CLI, whatever is on PATH
```

A globally activated `dartway` is a second copy with a life of its own, and the two drift — a global
CLI from before a release has no `generate` at all, while the skills of the project it is standing
in name `dartway generate` as the only way to write `*.dw.dart`. What that looks like is "unknown
command", three steps from the cause. So `generate`, `check`, `test`, `deploy`, `dev` and `stats`
refuse to run when the CLI that started them is not the one the project pins, and say which command
would have worked. `create` and `quickstart` (there is no project yet), `update` and `setup-ai`
(they repair the pins) and `doctor` (it touches nothing) run either way.

**The complete, current option list of any command is `dartway help <command>`** — and for the
nested ones, `dartway help secret push`. That output is generated from the parser, so it
cannot drift from the code. This page does not restate every flag. It names the ones whose
*meaning* is not obvious from a one-line help string, and states the defaults a reader has to know
before relying on them.

The commands, as `packages/dartway_cli/bin/dartway.dart` registers them: `quickstart`, `doctor`,
`create`, `setup-ai`, `update`, `generate`, `check`, `dev`, `deploy`, `secret`, `stats`, `test`. A
usage error
exits `64`; a refusal the command explains exits `1`.

**There is no `migrate` command.** Migrations belong to the project: `dart run bin/migrate.dart
<apply | rollback | status | create <name> | check | rehash>` in the server package, against the
database named by `DW_DATABASE_*`. The server also applies them as it starts. See
[Migrations](../4-server/migrations.md).

## Where the CLI takes the framework from

The CLI does not carry the framework inside itself. `create`, `setup-ai` and `update` read the
DartWay monorepo — `template/` and `toolkit/` — from the first of these that applies:

1. a local checkout named by `--local-repo`, `--framework-path` (`create`) or `DARTWAY_MONOREPO_DIR`;
2. a **channel** that was chosen — `--channel`, `DARTWAY_BRANCH`, or for `update` the channel the
   project recorded: a shallow clone of that branch, cached in `~/.dartway/monorepo` and refreshed
   with a shallow fetch on every run;
3. **the checkout the CLI runs from**, when it runs from one — activated with `--source path` from a
   checkout, or with `--source git` (pub keeps a clone of the repository at the ref), or run with
   `dart run` inside the monorepo;
4. otherwise the channel `stable`.

So a CLI that has the framework beside it hands out the template and the toolkit of its own
revision: activated from the rewrite's branch, `dartway create` makes a project of the rewrite
rather than of whatever `stable` holds. A CLI with nothing beside it — installed from pub.dev —
takes the channel. The install prints which source it used and records it in
`.claude/dartway-toolkit.json`.

| Variable | Meaning |
|---|---|
| `DARTWAY_BRANCH` | The channel for `create`, `setup-ai` and `update` when `--channel` is not given; chosen, so it wins over the checkout the CLI runs from |
| `DARTWAY_MONOREPO_DIR` | A local monorepo checkout to use instead of cloning |
| `DARTWAY_REPO_URL` | Another monorepo git URL (default `https://github.com/dartway/dartway.git`) |

## `dartway quickstart` — the instruction, printed

Prints the full setup brief to stdout: what the machine needs, how to create a project, the order
of the bring-up steps and why, how to verify the server answers, how to hand over the sign-in, and
the checks to run before calling a change done. It writes nothing and asks nothing.

It is a printed text rather than an extension for one assistant on purpose: **whatever agent you
use, its way in is two commands** — `dart pub global activate dartway_cli` and `dartway
quickstart` — after which the instruction is in that agent's context. A plugin for one vendor would
make the front door of an open framework depend on a format nobody here controls. A human reads the
same text; there is no second, friendlier version to drift from it. The source is
`packages/dartway_cli/lib/src/quickstart_brief.dart`.

## `dartway doctor` — is this machine ready?

Six checks, each with the exact fix when it fails:

| Check | Why it is here |
|---|---|
| Dart `>=3.11.0` | The SDK running the CLI is the one that runs the project |
| Flutter `>=3.41.0` | |
| git, with `user.name` and `user.email` | `create` commits the new project. A missing binary fails; a missing identity warns — the project is complete, but has no initial commit |
| A pub host that answers | `pub get` sets no deadline on a connection that opens and goes quiet, so a filtered route surfaces as a resolve step that hangs without a word. The probe asks for bytes rather than a socket (a TCP connect succeeds even when the TLS handshake after it is filtered), waits 10 seconds, and honours `PUB_HOSTED_URL` |
| A responding Docker daemon | Postgres and MinIO come from it, for development and for `dartway test`. Not installed and not running are reported apart |
| The pub global bin directory on `PATH` | The cause of `dartway: command not found` right after a successful install. A warning: `dart pub global run dartway_cli:dartway` works regardless |

Exit code `1` when anything fails, `0` otherwise (warnings included), so an agent or a CI step can
branch on it.

## `dartway create <name>` — a project that already runs

```bash
dartway create my_app
dartway create .          # the current, empty folder becomes the project
```

The source is `template/` in the monorepo: a **skeleton, not somebody's product** — sign-in by a
one-time code, profiles and roles, navigation with zone guards, an admin panel, a UI kit as source,
tests on both sides, and no domain models. The full application on the same framework lives in
`example/` and is a reference to read, not a project to inherit.

You get `my_app_shared`, `my_app_server` and `my_app_flutter`, the agent toolkit in `.claude/`
and `docs/dev_notes/`, and a git repository with an initial commit.

What the copy does beyond copying:

- renames `dartway_starter` → `my_app`, `DartwayStarter` → `MyApp`, `dartwayStarter` → `myApp` and
  `dartway-starter` → `my-app` (the storage bucket names) in every path and every text file;
  binary files are copied verbatim;
- skips `.dart_tool`, `build`, `.git`, `.idea`, `.fvm`, `ephemeral`, `node_modules` and
  `pubspec.lock`;
- runs `dart format` over `bin/`, `lib/` and `test/` of every package — a rename changes the length
  of names, and without this the first commit would not be formatted and `dartway generate
  --check` would depend on where lines happened to break;
- strips the monorepo-only `dependency_overrides` block (with the comments above it) from every
  package pubspec. Those overrides point at sibling folders of the monorepo; in a project they lead
  nowhere, and what is left resolves from pub.dev;
- installs the toolkit with base branch `master` and the given `--language` and `--notes-tracker`
  (see `setup-ai` below);
- unless `--no-git`: `git init` (skipped when the folder is already a repository), `git add -A`,
  and an initial commit.

The name must be a lower_snake_case Dart identifier without leading, trailing or doubled
underscores, at most 55 characters — it becomes package names, and `<name>-private` has to fit the
63 characters S3 allows a bucket. `dartway_starter` itself is refused. The target directory must not
exist; `create` refuses rather than merging into it.

With `.` the folder names the project, the way `flutter create .` does: `dartway-demo/` becomes
`dartway_demo`. The folder has to be empty; a `.git` in it is allowed, and the initial commit then
lands in that repository.

| Option | Default | Meaning |
|---|---|---|
| `--channel` | `DARTWAY_BRANCH`, else the checkout the CLI runs from, else `stable` | Monorepo branch to take the template and the toolkit from |
| `--local-repo` | `DARTWAY_MONOREPO_DIR` | A local monorepo checkout instead of a clone |
| `--framework-path` | — | Resolve the framework packages from a local monorepo checkout by path: each pubspec gets `dependency_overrides` onto `<monorepo>/packages` for exactly the `dartway_*` packages it reaches. The template and the toolkit come from the same checkout unless `--local-repo` names another |
| `--language` | `English` | The app's one UI language — `en`, `ru`, or `English`, `Russian`: the project keeps only that `.arb`, makes it the template ARB and `AppLocaleController.productLocale`, and regenerates `lib/l10n/gen` (a language the skeleton has no translation for starts in English, with a note). Also the language the project writes its own texts in — feature specs, doc comments, `docs/dev_notes/` |
| `--notes-tracker` | `dartway/dartway` | GitHub repository where findings about the framework are filed; `none` files nothing outside the project |
| `--[no-]git` | on | Initialize a repository with an initial commit |

**`--framework-path` is how a project is built against a framework that is not published.** The
rewrite's package family (`^0.20.0-dev.2`) is not on pub.dev yet, so a project created from this
tree cannot resolve on its own; `--framework-path` resolves the same pubspecs against the same
checkout the template was written against. The block it writes says to remove it once the versions
are published.

The last thing `create` prints points at `dartway doctor` and `dartway quickstart` and says to ask
whatever assistant you use to bring the project up. The manual sequence is in the project's
`README.md`.

## `dartway setup-ai` — the toolkit in a project you already have

```bash
dartway setup-ai --base-branch develop
```

Installs the agent toolkit into the project: `.claude/CLAUDE.md`, the `dartway-*` skills, the
`/commit` and `/dartway-checkup` commands, a merged `.claude/settings.json`, and
`docs/dev_notes/`. What each of those is, and which files the installer owns, is
[The agent toolkit](agent-toolkit.md).

The project root is `git rev-parse --show-toplevel`, or the current directory outside a
repository. The layout is detected by directory suffix: exactly one `*_shared`, one `*_server` and one
`*_flutter` are required; none or two of a kind stops the command with a layout error rather than a
guess.

| Option | Default | Meaning |
|---|---|---|
| `--base-branch` | `master` | Base branch of **this** project, used by the commit and PR instructions |
| `--language` | `English` | The language the project writes its own texts in. Package APIs and error strings stay English |
| `--notes-tracker` | `dartway/dartway` | Where framework findings are filed; `none` keeps them in the project |
| `--channel` | `DARTWAY_BRANCH`, else the checkout the CLI runs from, else `stable` | Monorepo branch to take the toolkit from |
| `--local-repo` | `DARTWAY_MONOREPO_DIR` | A local checkout instead of a clone |

**An explicit flag wins, what the project recorded comes next, the default comes last.** The install
records its provenance and settings in `.claude/dartway-toolkit.json` — source, channel, commit, CLI
version, and the three settings above — and a re-run without `--base-branch`, `--language` or
`--notes-tracker` replays the recorded ones. Without that, a plain re-run would reset a project's
language and tracker, and the diff would look like any update.

**A channel switch nobody asked for is refused.** When the project recorded one channel, `--channel`
was not given, and the default is another, the command stops before fetching anything and names both
channels. Naming either one proceeds: moving between channels is a decision, and it ends up written
in the command that ran. A named local checkout ignores the channel and records none, so it is never
refused. The checkout the CLI runs from is a default like `stable`, and is refused the same way for a
project that recorded a channel: `--channel <recorded>` stays, `--local-repo <checkout>` switches.

Commit `.claude/` and `docs/dev_notes/` afterwards.

## `dartway update` — carry the project onto a newer framework

`setup-ai` installs the toolkit. `update` does that and then answers the question nothing else in a
project answers: **what else has moved.** It takes the same options, with one difference: the
channel defaults to the one the project recorded, because "update" means moving forward on the
channel the project is on.

It reports three things and changes only the first:

- **the toolkit**, installed as `setup-ai` installs it;
- **the framework packages the project is behind on** — the version each `dartway_*` package
  resolves in the project's `pubspec.lock` files against the version in the channel's
  `packages/*/pubspec.yaml`. Only packages the project depends on are listed. When a project holds
  several copies of a package (a Flutter lock and a server lock), the **lowest** is the answer: the
  oldest half is the one still owing the migrations. A hosted package moves by raising its caret
  (under a `0.x` major a minor behaves like a major, so `^0.4.0` does not admit `0.8.0`); a git one
  moves by `dart pub upgrade <names>` in the directories the report names;
- **the migration notes still to apply** — the files of `docs/migrations/` in the channel whose
  `affects:` names a package the project is below, oldest first, each with its path. A note that
  cannot be parsed is reported as a framework defect rather than skipped. See
  [Migration notes](../migrations/README.md).

If the CLI itself is older than the `dartway_cli` in the channel, the run says so first: an old CLI
installs an old idea of what a project needs, and it cannot replace itself mid-run.

**It edits nothing but the toolkit, deliberately.** A caret is one line, a changed API is not, and a
command that half-applied the rest would leave a tree nobody can tell from a finished one. The
`dartway-update` skill carries the list out: read the notes, make the edits, then move the versions,
in that order.

## `dartway generate` — the generated code

```bash
dartway generate            # write
dartway generate --check    # write nothing; exit 1 when a generated file is out of date or stale
dartway generate -v         # list every file written or removed
```

Runs `dartway_generator` over the project: DTO codecs (`*.dw.dart` parts) and the protocol registry
(`lib/generated/dw_protocol.dart`) in `*_shared`, table definitions and the schema
(`lib/generated/dw_schema.dart`) in `*_server`. What is generated from what is
[Data objects and generation](../2-core/data-objects-and-generation.md).

**The CLI does not link the generator in; it runs the one the project resolved.** The generator
pins an `analyzer`, and a globally activated CLI carrying it would force one analyzer on every
project it touches — while the generator has to match the `dartway_core_shared` and `dartway_orm`
the project builds against. So the command walks up to the directory holding the `*_server` and
`*_shared` packages, looks for `dartway_generator` in their package config (the server package
first, where the skeleton declares it as a dev dependency), and runs `dart run dartway_generator`
there. Only when no package resolves it does it fall back to a globally activated
`dartway_generator`; without either it stops and says how to add one. Run `dart pub get` first: an
unresolved package has no package config to find the generator in.

The exit code is the generator's. `--check` is what CI runs, and what `dartway check` reports as
`generatedCodeStale`.

## `dartway check` — the conventions, enforced

```bash
dartway check
dartway check --type forbiddenUiUsage
dartway check --level error
dartway check --dir lib/app/invoices
```

Runs the convention checks from the project root or from inside the `*_flutter` package: the
Flutter package, the declared top level of both packages, localization wiring, generated code,
migrations and framework locks. Exit `1` when any error-severity finding is reported, `0` otherwise.

| Option | Meaning |
|---|---|
| `--type` | One check by name (case-insensitive); an unknown name is a usage error |
| `--level` | Only checks of one severity: `info`, `warning` or `error` |
| `--dir` | Only one folder of the Flutter package (relative to it); skips every project-wide pass |

What each check means, which ones fail, and why is [The conventions checker](conventions-checker.md).

## `dartway dev` — the web app and the server on one origin

```bash
dartway dev web                                  # flutter run -d web-server + the proxy
dartway dev web --api http://localhost:8080 -- --profile   # after -- goes to `flutter run`

dartway dev proxy                                # the origin alone, in front of servers you run
dartway dev proxy --web http://localhost:5000    # `flutter run -d web-server --web-port 5000`
dartway dev proxy --web-dir build/web            # a built app instead
```

**The server answers no CORS, in development too** (D-039). A deployed web app reaches `/dw/*` and
`/health` on its own origin, because the front proxy serves the app and proxies those paths beside
it — see [Deploying the server](deploy.md). `flutter run -d chrome` breaks that on a laptop: the app
is served from a port of its own and every call is cross-origin. `dartway dev` restores the deployed
shape: **one origin, `http://localhost:8000` by default**, where `/dw/*` (the `/dw/live` socket
included) and `/health` go to the server and everything else to the web app.

Both subcommands take:

| Option | Default | Meaning |
|---|---|---|
| `--port`, `-p` | `8000` | Port of the origin to open in the browser |
| `--api` | `http://localhost:8080` | The running server |
| `--api-path` | — | A project door (a `DwHttpRoute` path such as `/mcp`) that goes to the server too. Repeatable. In production such doors live on the API host, which proxies everything; locally they share the one origin, so the proxy has to be told |

**`dev web`** runs `flutter run -d web-server --web-port <free port> --web-hostname localhost
--dart-define=DW_BACKEND_URL=<the proxy origin>` in the `*_flutter` package, starts the proxy in
front of it, and prints the address once Flutter's server is up. **Open that address, not the one
Flutter prints.** Hot reload works through the proxy. Ctrl+C stops Flutter and the proxy together.
The Flutter command is `--flutter` when given, otherwise the project's FVM SDK
(`.fvm/flutter_sdk`), `fvm flutter` when `.fvmrc` pins a version, and `flutter` from `PATH`.

**`dev proxy`** is the same origin without Flutter. `--web` (default `http://localhost:5000`) points
at a web dev server you run; `--web-dir` at a build, served the way the web image serves it —
`index.html` for any path that is not a file, the `Cache-Control` of the project's own web image
configuration (the skeleton's rules when there is none), and an `ETag`. The two options exclude each
other.

**Why no allowed-origins setting is needed.** The server lets a browser open the live socket when
the page's `Origin` names the host the request was sent to. The proxy passes the browser's `Host`
through unchanged — as the deployed Nginx does with `proxy_set_header Host $http_host` — so the page
origin `http://localhost:8000` and the host `localhost:8000` match. `X-Forwarded-For`, `X-Real-IP`
and `X-Forwarded-Proto` are added as Nginx adds them; upgraded sockets are tunnelled as bytes.

Two things to know:

- **`localhost` and `127.0.0.1` are different origins** to a browser. The app is built against the
  origin the command prints; opened under the other name, its calls are cross-origin again.
- **The server is started separately.** Until it listens, the proxy answers its paths with `502` and
  says so once in the terminal; calls go through as soon as it is up.

## `dartway test` — the server tests, on a database of their own

```bash
dartway test                        # from the project root
dartway test -- --name 'sign-in'    # everything after -- goes to `dart test`
dartway test --keep                 # leave the containers up to look inside them
```

Starts a Postgres and a MinIO for this run on ports Docker picks, waits until both accept
connections, runs `dart test` in the server package with `DW_DATABASE_*` and `DW_STORAGE_*` in its
environment, and removes both containers afterwards — Ctrl+C included. Each test file then creates
a database and buckets of its own.

| Option | Default | Meaning |
|---|---|---|
| `--keep` | off | Leave the containers running and print how to reach and remove them |
| `--image` | `postgres:17-alpine` | Postgres image — the one a deployment runs |
| `--[no-]storage` | on | Start MinIO beside Postgres; `--no-storage` for a server without uploads |
| `--storage-image` | `quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z` | MinIO image — the one a deployment runs |

Why a database per run rather than a compose service, and how a suite uses it, is
[Testing](testing.md).

## `dartway deploy` — the server, without a folder of shell scripts

```bash
dartway deploy setup --env staging
dartway deploy check --env staging
dartway deploy run   --env staging
dartway secret set SMS_API_TOKEN --env staging
```

`setup` provisions a server and renders its Compose and Nginx configuration, `run` deploys, and
`check` asserts that a deployment would work without changing anything. Everything is
described by `deploy/config.yaml`. The whole story is [Deploying the server](deploy.md).

## `dartway secret` — the values that are not in Git

```bash
dartway secret list --env local               # this machine: both halves, names only
dartway secret set SMS_API_TOKEN --env local  # the value is read from stdin
dartway secret list --env staging             # a server: the store, names only
```

One command for every environment, because `local` is an environment. What differs is where the
values live: for a server, a file on it (`init`, `set`, `list`, `put-file`, `push`, `pull`); for
`local`, `deploy/secrets.yaml > local` on this machine, where `init`, `put-file`, `push` and `pull`
have nothing to do and say so. **Values are never printed** — a question about a secret is answered
by its name, its file, and whether it is empty. [Deploying the server](deploy.md#secrets) has the
whole story.

## `dartway stats` — what actually grew

```bash
dartway stats
```

Files, total lines, average, maximum and minimum per top-level folder of the Flutter package's
`lib/` whose name starts with `app`, `auth`, `common` or `admin`, plus a total. No grades and no
opinions: the counter you read before and after a refactor. Run it from the project root or inside
the `*_flutter` package.
