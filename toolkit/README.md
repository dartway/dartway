# DartWay Claude Toolkit

The Claude Code harness for DartWay apps: reusable `dartway-*` skills and commands. **The single source of truth** is the `toolkit/` folder of the `dartway` monorepo: the skills are versioned and evolve together with the framework code (a change to a package's public API updates the affected skills in the same PR — see the monorepo's root `CLAUDE.md`).

In client repos the harness is installed by a script and **committed** (`.claude/` is a generated-but-committed artifact, like the Serverpod client): you clone the project and the skills are already there, the history records which skills the code was written with, and updating is a deliberate action with a visible diff. The installer overwrites **only the managed files** (`CLAUDE.md`, the `dartway-*` skills, the `commit`/`dartway-checkup` commands) — the project's own skills and commands live alongside under their own names and are left alone. Want to customize a dartway skill — copy it under a different name.

## Structure

```
CLAUDE.md                     # the generic methodology (the always-in-context "brain"): laws, naming,
                              #   the server/flutter/shared/client layers, the skill catalog; installed as .claude/CLAUDE.md
skills/dartway-*/SKILL.md     # the DartWay methodology — 12 skills: requirements, plan, run,
                              #   feature-scaffold, models, crud-config, data-layer, navigation,
                              #   ui-kit, clean-code, push-delivery, finish
commands/{commit,dartway-checkup}.md
settings.json                 # default permissions, seeded once as .claude/settings.json
```

`CLAUDE.md` is installed as `.claude/CLAUDE.md` and committed with the project, which Claude Code automatically keeps in context — which is why a client repo needs no project `CLAUDE.md` files: the methodology rides in from the toolkit, and project knowledge lives in the code that holds it — `DwFeatureSpec`, doc comments, the registries of `lib/core/`.

The skills are **generic**: project-specific values are extracted into placeholder tokens that the installer substitutes at install time:

| Token | Value | Where from |
|---|---|---|
| `__SERVER_PKG__` / `__CLIENT_PKG__` / `__FLUTTER_PKG__` / `__SHARED_PKG__` | the Dart package names | auto-detected by `*_server`/`*_client`/`*_flutter`/`*_shared` |
| `__BASE_BRANCH__` | the base branch | a parameter of the installer run |
| `__PROJECT_LANGUAGE__` | the language the project writes its own texts in | `--language`, default English |
| `__NOTES_TRACKER__` | the GitHub repository framework findings are filed in as issues | `--notes-tracker`, the framework's own tracker by default; `none` opts out |

`settings.json` is installed as `.claude/settings.json` **only when the project has none**, and is never overwritten afterwards — a project adds its own permissions to it, and losing those on an update would cost more than a stale default. It pre-approves this stack's build commands (`dart pub get`, `docker compose up`, `serverpod generate`, the test runners) so that bringing a fresh project up is not a queue of permission prompts, and it denies reading `config/passwords.yaml` — turning a rule the skills merely state into one the harness enforces. Nothing destructive is on the allow list: `docker compose down`, commits and pushes still ask.

`docs/dev_notes/` is the one thing installed outside `.claude/`: the project's own findings — a risk, a pin that trails, a config written down twice — one **tracked** file per finding, so it travels out in a pull request and is visible in review. `README.md` there states the form and is refreshed on every install; `_coverage.md` is the project's own table of which features `/dartway-checkup` has read, and is written once and never overwritten. A finding about the **framework** gets no file at all — it is filed as an issue in the repository `__NOTES_TRACKER__` names.

Beyond `docs/adr/` and `docs/dev_notes/`, a DartWay project keeps no docs: the description of a feature lives in its `DwFeatureSpec`, the server-side rules in doc comments above the `DwCrudConfig`, cross-cutting registries in code under `lib/core/`, and the methodology in these skills. The ticket for `/commit` is passed as an argument, and the project's CI checks the format.

## Wiring it into a client repo

Installed by the CLI — the shell scripts it replaced are gone:

```bash
dart pub global activate dartway_cli
dartway setup-ai                      # in the project root
```

It clones or pulls the `dartway` monorepo (the **`stable`** branch by default — the last verified
state), takes `toolkit/` from it, detects the packages, substitutes the tokens and fills `.claude/`.
Commit `.claude/` afterwards: it is a generated-but-committed artifact, like the Serverpod client.

## Developing the toolkit

Edit the skills **here** (in the monorepo's `toolkit/`) and push. For a fast edit→test cycle, install into a real project from a local checkout:

```bash
dartway setup-ai --local-repo ../dartway    # or DARTWAY_MONOREPO_DIR=../dartway
```

Edit → re-run `setup-ai` in the project → test → `git push`. There is no reverse sync: the source of truth is always here.

The invariant: `CLAUDE.md`, `skills/` and `commands/` **must contain no project literals** — only `__*__` tokens. These files land in the `.claude/` of every project on the framework, so a role name, a package name or a domain lifted from the project you were looking at while writing arrives in all of them.

Nothing greps for it. A pattern can only list the projects we already know, which is the one set of names a fresh leak will not come from — and the version that lived here matched nothing but itself. Read your own diff instead: a name that means something in exactly one project is either a token or an invented example.
