# How do I start if I have an AI assistant?

> Goal: an empty folder becomes a running fullstack app without you typing a build command. Two
> commands go in; the assistant does the rest and hands you the sign-in.

## The front door: two commands

Open an empty folder in whatever coding assistant you use — Claude Code, Cursor, Codex, Copilot,
aider — and ask it to run:

```bash
dart pub global activate dartway_cli
dartway quickstart
```

`quickstart` prints the setup brief to stdout: check the machine, create the project, bring it up in
an order that is explained step by step, verify the server is actually answering, hand over the
sign-in, and what the project expects next. That text lands in the assistant's context, and it
proceeds on its own. Then say what you want in your own words — *"set up a DartWay project called
my_app and bring it up"*.

**Why a printed text and not a plugin.** An extension exists in one vendor's format, and the front
door of an open framework should not. The brief is markdown on stdout, so every assistant reads the
same instruction, and there is no second, friendlier version of it to drift from the real one. It is
maintained next to the CLI's code (`packages/dartway_cli/lib/src/quickstart_brief.dart`), and it is
equally readable by you — [the quick start](quick-start.md) is the same path, written for a person.

## What the machine has to have

The brief starts with `dartway doctor`, which reports each of these and prints the fix for whatever is
missing:

- **Dart `>=3.11` and Flutter `>=3.41`.**
- **git, with an identity.** `create` commits the project it makes; without `user.name` and
  `user.email` that commit is the step that does not happen.
- **A pub host that answers.** Every step begins with `pub get`, and pub sets no deadline on a
  connection that opens and then goes quiet. Where the route to pub.dev is filtered you get no error,
  just a resolve step that hangs until the session is killed — which is why the brief tells the
  assistant to stop and ask you rather than push past this one.
- **Docker, running.** Postgres and the object storage come from it, for development and for tests,
  and there is no second path. This is the one an assistant cannot solve for you: Docker Desktop does
  not install unattended.
- **Globally activated executables on `PATH`.** If they are not, every command still works as
  `dart pub global run dartway_cli:dartway <command>`.

## What the assistant will ask you

**Which phone number or e-mail should be the administrator.** It goes into `DW_ADMIN_IDENTIFIER`, and
the brief tells the assistant to ask rather than choose: whoever can *receive* the one-time code on
that identifier becomes the admin. An invented value is an admin nobody can sign in as — or someone
else can.

It should also ask before `docker compose down -v`. That recreates a drifted local database and
destroys its data; a fair fix, and your call.

## How you know it worked

The brief tells the assistant to report **facts**, and nothing else counts:

- the server started, which means it applied its migrations — it exits naming the migration otherwise;
- `200` from `http://localhost:8080/health`;
- the identifier to sign in with, and **the real one-time code read from the server log**. Nothing
  goes over SMS or e-mail in development; the code is printed as `Sign-in code for <identifier>: …`.
  "Enter anything" is wrong — the code is checked. The seeded accounts sign in with `111111`.

"It should be running" is not a fact. Ask for the status code.

A good first thing to try: sign in as the administrator in two browser windows, change a member's role
or an app setting in the admin panel, and watch the other window follow without a reload.

## The toolkit the project carries

`dartway create` installs the agent toolkit into `.claude/`; `dartway setup-ai` installs it into a
project that has none. From then on you keep working in prompts, and the assistant works inside the
project's conventions rather than guessing them.

- **`.claude/CLAUDE.md`** — the always-loaded constitution: DartWay's laws, which no project
  overrides, and its defaults, which a project may replace in the root `CLAUDE.md` with a reason.
- **`.claude/skills/dartway-*`** — step-by-step playbooks with the checks that prove each step:
  `dartway-run` brings the project up, `dartway-contract` writes the shared DTOs, `dartway-server`
  the handlers, `dartway-data-layer` the Flutter side, `dartway-realtime` channels and publishing,
  `dartway-access` access and channel rules, `dartway-migrations`, `dartway-uploads`,
  `dartway-testing`, `dartway-ui-kit`, `dartway-navigation`, and the process skills
  `dartway-requirements`, `dartway-plan` and `dartway-finish`. Claude Code loads them by relevance;
  any other assistant reads them as the plain markdown they are — point yours at the folder.
- **`.claude/commands/`** — `/commit` and `/dartway-checkup`.
- **`.claude/settings.json`** — pre-approves this stack's everyday build and test commands, so the
  first run is not a queue of permission prompts. Nothing destructive is on the list: stopping
  containers, commits and pushes still ask.
- **`.claude/dartway-toolkit.json`** — where the installed toolkit came from: the source and channel,
  the commit, the CLI version, and the install settings `setup-ai` and `update` were given (the
  project's language, base branch and where framework findings are filed). The next install reads
  it, so a plain re-run keeps them instead of resetting them to the defaults.

The managed files — `CLAUDE.md`, the `dartway-*` skills and the two commands — are overwritten on every
install. A skill or command of your own, under another name, is never touched, and `settings.json` is
merged: what the toolkit added is printed, and what you added stays. **Commit `.claude/`**, so the
repository is self-contained and its history says which skills the code was written with.

## Keeping it current: `dartway update`

A toolkit is a committed artifact, and a month-old one looks exactly like a fresh one. `dartway update`
is the command that says a project has fallen behind:

1. it reinstalls the toolkit from the channel the project is already on;
2. it warns when the CLI running it is older than the channel's — an old CLI installs an old idea of
   what a project needs — and says to update the CLI first;
3. it lists the framework packages the project's lock files are behind on, and how to move each;
4. it lists the migration notes (`docs/migrations/` in the framework) the project still owes an
   edit to, oldest first.

**It edits no code of the project, deliberately.** Raising a caret is one line; answering a changed
API is not, and a command that half-did it would leave a tree nobody can tell from a finished one. The
`dartway-update` skill is what carries the list out.

## When it goes sideways

- **The assistant reports success without a status code.** Ask for the output of the health check.
- **It suggests loosening an access rule to fix an empty list.** An empty answer is usually a correct
  rule. Access is closed until opened, deliberately.
- **`pub get` hangs.** The pub host is not answering — `dartway doctor` says so; the fix is the network,
  not a retry.
- **`dartway: command not found`** right after a successful install: the pub cache is not on `PATH`.
  Use `dart pub global run dartway_cli:dartway <command>`, or fix `PATH` as doctor prints.
- **No agent at hand?** Every command is in the created project's `README.md`, and the whole path is
  the [quick start](quick-start.md).

## Where to go next

- [Quick start](quick-start.md) — the same path by hand, with the reason for each step.
- [What DartWay is](what-is-dartway.md) — the ideas behind the contract, and the honest limits.
- [Project layout](project-layout.md) — the three packages and every folder in them.
- [The agent toolkit](../5-tooling/agent-toolkit.md) — what ships in `.claude/`, and how to customize
  it without losing the change on the next update.
- [The CLI](../5-tooling/cli.md) — `quickstart`, `doctor`, `create`, `setup-ai`, `update` and the rest.
