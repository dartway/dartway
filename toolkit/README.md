# DartWay Claude Toolkit

The Claude Code harness for DartWay apps: reusable `dartway-*` skills and commands. **The single source of truth** is the `toolkit/` folder of the `dartway` monorepo: the skills are versioned and evolve together with the framework code (a change to a package's public API updates the affected skills in the same PR — see the monorepo's root `CLAUDE.md`).

In client repos the harness is installed by a script and **committed** (`.claude/` is a generated-but-committed artifact, like the Serverpod client): you clone the project and the skills are already there, the history records which skills the code was written with, and updating is a deliberate action with a visible diff. The installer overwrites **only the managed files** (`CLAUDE.md`, the `dartway-*` skills, the `commit`/`dartway-audit` commands) — the project's own skills and commands live alongside under their own names and are left alone. Want to customize a dartway skill — copy it under a different name.

## Structure

```
CLAUDE.md                     # the generic methodology (the always-in-context "brain"): laws, naming,
                              #   the server/flutter/shared/client layers, the skill catalog; installed as .claude/CLAUDE.md
skills/dartway-*/SKILL.md     # the DartWay methodology — 12 skills: requirements, plan, run,
                              #   feature-scaffold, models, crud-config, data-layer, navigation,
                              #   ui-kit, clean-code, push-delivery, finish
commands/{commit,dartway-audit}.md
setup-claude.sh / .ps1        # legacy installers, superseded by `dartway setup-ai` — nothing calls them
```

`CLAUDE.md` is installed as `.claude/CLAUDE.md` and committed with the project, which Claude Code automatically keeps in context — which is why a client repo needs no project `CLAUDE.md` files: the methodology rides in from the toolkit, and project knowledge lives in `docs/`.

The skills are **generic**: project-specific values are extracted into placeholder tokens that the installer substitutes at install time:

| Token | Value | Where from |
|---|---|---|
| `__SERVER_PKG__` / `__CLIENT_PKG__` / `__FLUTTER_PKG__` / `__SHARED_PKG__` | the Dart package names | auto-detected by `*_server`/`*_client`/`*_flutter`/`*_shared` |
| `__BASE_BRANCH__` | the base branch | a parameter of the installer run |
| `__PROJECT_LANGUAGE__` | the language the project writes its own texts in | `--language`, default English |

`dartway_notes.md` is the one file installed outside `.claude/`: a git-ignored journal at the project root where findings about the framework itself are recorded — a rule that did not catch a mistake, an API that forced a workaround. Managed files cannot be fixed in place (they are overwritten on update), so this is where the fix waits to be carried into the monorepo. An existing journal is never overwritten.

The docs paths (`docs/1_general`, `docs/audits`) are a DartWay convention, hardcoded as-is; there are no separate per-feature docs, the description lives in `DwFeatureSpec` next to the code. The ticket for `/commit` is passed as an argument, and the project's CI checks the format.

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

The invariant: `CLAUDE.md`, `skills/` and `commands/` **must contain no project literals** — only `__*__` tokens. The check:

```bash
grep -rniE 'tvolkova|tvaity|kerla|RAZRABOTKA|BAGI|DEVOPS' CLAUDE.md skills commands   # must be empty
```
