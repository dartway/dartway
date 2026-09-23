# DartWay Claude Toolkit

The Claude Code harness for DartWay apps: reusable `dartway-*` skills and commands. **The single source of truth** is the `toolkit/` folder of the `dartway` monorepo: the skills are versioned and evolve together with the framework code (a change to a package's public API updates the affected skills in the same PR — see the monorepo's root `CLAUDE.md`).

In client repos the harness is installed by the CLI and **committed** (`.claude/` is a generated-but-committed artifact, like the output of `dart run dartway_cli:dartway generate`): you clone the project and the skills are already there, the history records which skills the code was written with, and updating is a deliberate action with a visible diff. The installer overwrites **only the managed files** (`CLAUDE.md`, the `dartway-*` skills, the `commit`/`dartway-checkup` commands) — the project's own skills and commands live alongside under their own names and are left alone. Want to customize a dartway skill — copy it under a different name.

## Structure

```
CLAUDE.md                     # the generic methodology (the always-in-context "brain"): laws, naming,
                              #   the shared/server/flutter packages, the skill catalog; installed as .claude/CLAUDE.md
skills/dartway-*/SKILL.md     # the DartWay methodology — 19 skills:
                              #   process: requirements, plan, run, finish, update
                              #   contract and server: contract, server, realtime, access, migrations,
                              #     uploads, push-delivery
                              #   app: feature-scaffold, data-layer, navigation, ui-kit, on-device
                              #   everywhere: clean-code, testing
commands/{commit,dartway-checkup}.md
dev_notes/{README,_coverage}.md   # installed into the project's docs/dev_notes/ (see below)
settings.json                 # default permissions, merged into .claude/settings.json
```

`CLAUDE.md` is installed as `.claude/CLAUDE.md` and committed with the project, which Claude Code automatically keeps in context — so the methodology rides in from the toolkit, and project knowledge lives in the code that holds it — `DwFeatureSpec`, doc comments, the registries of `lib/core/`. The root `CLAUDE.md` the skeleton gives a project is the project's own, and the installer never touches it: it is where a project records the defaults it replaces and the conventions DartWay says nothing about.

The skills are **generic**: project-specific values are extracted into placeholder tokens that the installer substitutes at install time:

| Token | Value | Where from |
|---|---|---|
| `__SHARED_PKG__` / `__SERVER_PKG__` / `__FLUTTER_PKG__` | the Dart package names | the directories in the project root ending in `_shared` / `_server` / `_flutter` |
| `__FLUTTER_APP_FILE__` | the app's wiring file, `<project>_app.dart` | derived from the Flutter package name |
| `__BASE_BRANCH__` | the base branch of the project | `--base-branch`, default `master` |
| `__PROJECT_LANGUAGE__` | the language the project writes its own texts in | `--language`, default English |
| `__NOTES_TRACKER__` | the GitHub repository framework findings are filed in as issues | `--notes-tracker`, the framework's own tracker by default; `none` opts out |

`settings.json` is installed as `.claude/settings.json` and **merged** on every later install: what the toolkit has and the project lacks is added and printed entry by entry, and everything the project added stays. It is the third kind of file here — neither the toolkit's outright like the skills, nor the project's outright like the dev-notes coverage table, but a default the project extends. A file the installer never touched would let a new `deny` rule reach no existing project. It pre-approves this stack's development commands (`dart pub get`, `docker compose up` and `exec`, `dart run` for `bin/server.dart`, `bin/migrate.dart` and `bin/seed_dev.dart`, `dartway`, the analyzers and test runners) so that bringing a fresh project up is not a queue of permission prompts, and it denies reading `deploy/secrets.yaml`, the git-ignored copy of every environment's secrets — turning a rule the skills merely state into one the harness enforces. Nothing destructive is on the allow list: `docker compose down`, commits and pushes still ask.

`docs/dev_notes/` is the one thing installed outside `.claude/`: the project's own findings — a risk, a pin that trails, a config written down twice — one **tracked** file per finding, so it travels out in a pull request and is visible in review. `README.md` there states the form and is refreshed on every install; `_coverage.md` is the project's own table of which features `/dartway-checkup` has read, and is written once and never overwritten. A finding about the **framework** gets no file at all — it is filed as an issue in the repository `__NOTES_TRACKER__` names.

Beyond `docs/adr/`, `docs/dev_notes/` and the READMEs the skeleton ships, a DartWay project keeps no docs: the description of a feature lives in its `DwFeatureSpec`, the server-side rules in doc comments above the handlers and access rules, cross-cutting registries in code under `lib/core/`, and the methodology in these skills. `/commit` writes one conventional-commit line and decides nothing local: a ticket convention, if the project has one, is stated in the project's own `CLAUDE.md`.

## Wiring it into a client repo

Installed by the CLI:

```bash
dart pub global activate dartway_cli
dartway setup-ai                      # in the project root, the first time
```

It clones or pulls the `dartway` monorepo (the **`stable`** branch by default — the last verified
state; a CLI activated from a monorepo checkout or git ref uses that checkout instead, so its toolkit
is of its own revision), takes `toolkit/` from it, detects the packages, substitutes the tokens, fills `.claude/` and
records what it installed in `.claude/dartway-toolkit.json`. Commit `.claude/` afterwards: it is a
generated-but-committed artifact. `dartway create` installs the toolkit the same way into the project it creates.

**Afterwards the door is `dartway update`**, not `setup-ai` again: it installs the toolkit the same
way — from the channel the project recorded, replaying the settings it was set up with — and then
reports what else has moved, which packages are behind and which migration notes the project still
owes an edit to. `dartway-update` is the skill that carries that list out.

## Developing the toolkit

Edit the skills **here** (in the monorepo's `toolkit/`) and push. For a fast edit→test cycle, install into a real project from a local checkout:

```bash
dartway setup-ai --local-repo ../dartway    # or DARTWAY_MONOREPO_DIR=../dartway
```

Edit → re-run `setup-ai` in the project → test → `git push`. There is no reverse sync: the source of truth is always here.

The invariant: `CLAUDE.md`, `skills/` and `commands/` **must contain no project literals** — only `__*__` tokens. These files land in the `.claude/` of every project on the framework, so a role name, a package name or a domain lifted from the project you were looking at while writing arrives in all of them.

Nothing greps for it. A pattern can only list the projects we already know, which is the one set of names a fresh leak will not come from. Read your own diff instead: a name that means something in exactly one project is either a token or an invented example.
