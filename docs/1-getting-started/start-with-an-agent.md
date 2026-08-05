# How do I start if I have an AI assistant?

> Goal: an empty folder becomes a running fullstack app without you typing a build command. Two
> commands go in; the assistant does the rest and tells you how to sign in.

## The two commands

Open an empty folder in whatever coding assistant you use — Claude Code, Cursor, Codex, Copilot,
aider — and ask it to run:

```bash
dart pub global activate dartway_cli
dartway quickstart
```

The second command prints the setup brief: what the machine needs, how to create the project, the
order the bring-up steps come in and why that order is not negotiable, how to verify the server is
actually answering, and how to hand you the sign-in. That text lands in the assistant's context and
it proceeds on its own.

Then say what you want, in your own words — *"set up a DartWay project called my_app and bring it
up"*.

**Why a printed text and not a plugin.** An extension exists in one vendor's format, and the front
door of an open framework should not. The brief is markdown on stdout, so every assistant reads the
same instruction, and there is no second, friendlier version of it to drift from the real one. It
is also perfectly readable by you.

## What the machine has to have

The assistant will run `dartway doctor` first, which reports each of these and prints the fix for
whatever is missing:

- **Dart `>=3.11` and Flutter `>=3.41`**
- **Docker, running.** The database comes from it and there is no second path. This is the one an
  assistant cannot solve for you: Docker Desktop does not install unattended, so if doctor says the
  daemon is not responding, start it.
- **`serverpod_cli`, pinned to the version the project depends on.** Needed as soon as you declare
  your first model. A drifted generator writes a protocol that compiles and then misbehaves at
  runtime, which is a bad afternoon to debug.

## What you get, and how you know it worked

Three packages — `my_app_server`, `my_app_client` (generated, never edited by hand) and
`my_app_flutter` — a git repository with an initial commit, and an agent toolkit in `.claude/`.

The assistant should end by reporting **facts**: the migrations it applied, `200` from
`http://localhost:8080/`, and the phone number to sign in with — `79990000003` for a plain user,
`79990000001` for an admin. **The one-time code is printed in the server console**, and the real one
is what you should be handed; nothing goes over SMS in development, and "enter anything" is wrong,
because the code is checked.

A good first thing to try: sign in as the admin, change the app name in the admin panel, and watch
the home screen in a second window update without a reload. Postgres → CRUD config → typed live
list → widget, proving itself on the first screen.

## From there on

The project carries its own conventions, and they are not decoration — DartWay is opinionated so
that an agent adding the fifth feature does not tear apart the first four.

- `.claude/CLAUDE.md` holds the laws: CRUD configs instead of endpoints, domain-first models, what
  counts as a feature, where a building block goes.
- `.claude/skills/dartway-*` are the playbooks — bringing the project up, models, CRUD configs, the
  data layer, navigation, the UI kit, finishing a task. Claude Code loads them by relevance; any
  other assistant reads them as the plain markdown they are. Point yours at the folder.
- `.claude/settings.json` arrives pre-approving this stack's build commands, so the first run is not
  a queue of permission prompts, and denying reads of `config/passwords.yaml`.
- `dartway check` grades the Flutter package against those conventions and fails on errors — the
  check that keeps an agent honest between reviews.

## When it goes sideways

- **The assistant reports success without a status code.** Ask for the output of the liveness check.
  "It should be running" is not a fact, and the brief says so.
- **It suggests loosening access to fix an empty list.** An empty response from a read config is
  usually a correct `accessFilter`. Access is closed until it is opened, deliberately.
- **It offers to recreate the database** (`docker compose down -v`). Fair fix for a local schema
  that drifted, and it destroys the data — your call, not its.
- **`dartway: command not found`** right after a successful install means the pub cache is not on
  PATH. Everything also works as `dart pub global run dartway_cli:dartway <command>`; doctor warns
  about this before it bites.
- **No agent at hand?** Every command is in the created project's `README.md`, and the walkthrough,
  including your first feature, is the [quick start](quick-start.md).

## Where to go next

- **[Quick start](quick-start.md)** — the same path by hand, then a model, a CRUD config and a live
  screen.
- **[What DartWay is](what-is-dartway.md)** — the idea behind the CRUD config, and the honest limits.
- **[Project layout](project-layout.md)** — the three packages and every folder in them.
- **[The agent toolkit](../5-tooling/agent-toolkit.md)** — what ships in `.claude/`, what is managed,
  and how to customize without losing it on the next update.
- **[The CLI](../5-tooling/cli.md)** — `quickstart`, `doctor`, `create`, `setup-ai`, `check`, `stats`,
  `deploy`.
