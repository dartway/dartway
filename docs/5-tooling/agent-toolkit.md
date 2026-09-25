# What is the `.claude/` folder in a DartWay project?

The methodology of the framework, written for an agent instead of for a reader. Every project created
by `dartway create` has it; `dartway setup-ai` installs it into a project you already have, and
`dartway update` carries it forward. The source is `toolkit/` in the monorepo; the installer is
`packages/dartway_cli/lib/src/toolkit_installer.dart`.

```bash
dartway setup-ai --base-branch develop
```

## Why the framework ships this at all

DartWay is **highly opinionated**: less freedom in *how* to do things, more consistency and speed.
The contract lives in the shared package and every call has exactly one handler with an access rule.
A feature is a folder with exactly one public file. Styles live in the app's own UI kit and nowhere
else. None of that is guessable from the API surface — an agent reading only `pubspec.yaml` writes
correct Dart in the wrong shape, confidently, at speed, everywhere.

That is the failure worth naming. An agent that does not know the conventions does not produce
compile errors you fix in a morning; it produces a second architecture inside the first one, faster
than a person can review it. The toolkit exists so the agent writes in the conventions a person on
the project would — and so the [conventions checker](conventions-checker.md) agrees with it
afterwards.

Toolkit and code evolve in the same repository and the same pull request: a change to a package's
public API updates the affected skills with it. A skill that has fallen behind the API is worse than
a missing one — the agent writes non-working code with full confidence.

## What gets installed

```
.claude/
  CLAUDE.md                   # the constitution, always in the agent's context
  skills/dartway-*/SKILL.md   # loaded by relevance to the task
  commands/commit.md          # /commit
  commands/dartway-checkup.md # /dartway-checkup
  settings.json               # merged, not overwritten
  dartway-toolkit.json        # where this install came from
docs/dev_notes/
  README.md                   # the form of a project finding
  _coverage.md                # what /dartway-checkup has read
```

**`CLAUDE.md` is the constitution**: the laws of the framework, the naming rules, what each package
of the project is for, and where things go. It is loaded into every session, which is why it stays
short and points at skills for the how.

**The laws are the checker's error set.** A law is a rule a project does not override; everything
else in the toolkit is a default a project may replace with its own rule. The line is not drawn by
taste: the published law list is exactly the checks `dart run dartway_cli:dartway check` fails on (fifteen today), and
`packages/dartway_cli/test/toolkit_law_list_test.dart` holds the two together. A check that is only a
warning is one with a second legitimate reading, and a project cannot be forbidden to decide that for
itself.

## The skills

A task runs left to right: `dartway-requirements` → `dartway-plan` → implementation with the layer
skills → `dartway-finish`.

| Skill | For |
|---|---|
| `dartway-requirements` | Read-only analysis before a task: what the project already has, the debt in the way, the questions worth asking, options with their trade-offs |
| `dartway-plan` | Read-only planning once the requirements are agreed: an end-to-end plan and the checks to verify it against |
| `dartway-run` | Bringing the project up locally — the order of the steps and the real ports — and confirming it is alive |
| `dartway-feature-scaffold` | A feature end to end: its folder, its entry point and `DwFeatureSpec`, its layers |
| `dartway-contract` | The shared package: data objects, requests and commands, refusal codes, validation, generation |
| `dartway-server` | Handlers and the call context, rows and queries, auth hooks, jobs, routes |
| `dartway-data-layer` | The Flutter side of calls: requests, commands, actions, refusal texts |
| `dartway-realtime` | Channels, publishing, update actions |
| `dartway-access` | Access rules, channel rules, roles, identities and keys |
| `dartway-migrations` | Writing, checking and applying migrations |
| `dartway-uploads` | Files: upload purposes and their rules, the public and the private bucket, rows that store a file id |
| `dartway-testing` | Where a test goes and how to write it, tier by tier |
| `dartway-navigation` | The router: zones, route descriptors, guards |
| `dartway-ui-kit` | The kit as source inside the app, and the ban on raw styles outside it |
| `dartway-on-device` | What only a real phone shows: keyboard, focus, scroll and viewport behaviour on iOS and iOS web, with the known workarounds |
| `dartway-finish` | The definition of done before a commit or PR: audit the diff, apply only what is confirmed |
| `dartway-update` | Moving onto a newer framework: `dartway update`, the migration notes, then the versions |
| `dartway-push-delivery` | Server-side push delivery |
| `dartway-analytics` | Events tracked in the app and on the server, stored in the project's Postgres |
| `dartway-documentation` | Where descriptions live — `DwFeatureSpec`, doc comments, registries in code — and what `docs/adr/` and `docs/dev_notes/` must earn |
| `dartway-framework-notes` | Filing a finding back to the framework as an issue: what must not travel, the labels, the marker a workaround leaves in the code |

Two commands come with them. **`/commit`** writes one conventional-commit line in English and decides
nothing local — whether commits carry a ticket belongs to the project's own `CLAUDE.md`. **`/dartway-checkup`**
reports the state of the whole project and what is worth taking into work next: it runs the
project's gates first (`dart run dartway_cli:dartway check`, `dart run dartway_cli:dartway generate --check`, the analyzers, the tests), compares
them with what CI actually runs, measures how far the project trails the framework, and only then
spends reading on features.

## The names in the skills are the project's

The toolkit's markdown carries tokens, and the installer replaces them in every installed `.md` file,
so the skills talk about `my_app_server`, not about a placeholder:

| Token | Becomes |
|---|---|
| `__SHARED_PKG__` | The `*_shared` package |
| `__SERVER_PKG__` | The `*_server` package |
| `__FLUTTER_PKG__` | The `*_flutter` package |
| `__FLUTTER_APP_FILE__` | The app's wiring file, `<project>_app.dart` |
| `__BASE_BRANCH__` | `--base-branch` (default `master`) |
| `__PROJECT_LANGUAGE__` | `--language` (default `English`) |
| `__NOTES_TRACKER__` | `--notes-tracker` (default `dartway/dartway`), or `none` |

The packages are detected by directory suffix at the project root on every run; exactly one
`*_shared`, one `*_server` and one `*_flutter` are required. **A token nothing fills stops the
install before a file is touched**: the installer reads the toolkit first, and a token this CLI does
not know, or one it would fill with nothing, is named with its file — a toolkit from another
framework revision than the CLI, rather than a skill that tells the agent about `/lib/src/`. The three flag settings are recorded in
`.claude/dartway-toolkit.json` and replayed by the next install unless a flag names another value —
see [The CLI](cli.md).

## Managed files, project files, and the one in between

**Managed files are the toolkit's**, and every install removes them and copies them again:
`.claude/CLAUDE.md`, every skill directory named `dartway-*`, and the `commit.md` and
`dartway-checkup.md` commands (a retired command on the installer's list is removed the same way).
Anything else in `.claude/` — a project's own skills and commands — is never touched.

So do not edit a `dartway-*` skill in place: the next install drops the change. To customize,
**copy the skill under another name** and edit the copy. The source of truth is `toolkit/` in the
monorepo, and there is no reverse sync. Rules a project adds of its own belong in its root
`CLAUDE.md` or its own skills.

**`.claude/settings.json` is a toolkit default the project extends**, so it is merged rather than
overwritten or skipped. It pre-approves this stack's build, test and run commands — `dart pub get`,
the analyzers, the test runners, `dartway`, `docker compose up` — so a first run is not a queue of
permission prompts, and it denies reading `deploy/secrets.yaml`, turning a rule the skills state into
one the harness enforces. Nothing destructive is on the allow list. On an install, entries the toolkit
has and the project lacks are added, a value the project holds is never replaced, and **every added
entry is printed** — the one cost of merging is an entry a project removed on purpose coming back, and
printing makes that visible in the same run. A file that is not a JSON object is left as it is and
reported.

**`docs/dev_notes/`** is the one place the installer writes outside `.claude/`: the project's own
findings, one committed file per finding. It is tracked, not git-ignored — a finding travels out in
the pull request that carries it and survives a `git worktree remove`. `README.md` there is the
toolkit's and is refreshed on every install; `_coverage.md` is the project's record of what
`/dartway-checkup` has read, created once and never touched again.

`.claude/dartway-toolkit.json` records where the install came from — the repository or local path,
the channel, the commit, the CLI version — and the settings. It records **provenance, not content**:
a list of installed files or their hashes would be a second copy of the files, and copies drift.

Commit `.claude/` and `docs/dev_notes/` after every install: a clone comes with the skills in place,
and the history records which version of the methodology a piece of code was written under.

## Findings about the framework go back to the framework

A rule that did not catch a mistake, two skills that disagree, an API the app had to work around —
none of that can be fixed in the installed copy, and all of it is worth keeping: the rules are only
ever proven wrong by real code. So a finding about the framework is **filed as an issue** in the
repository `--notes-tracker` names, which defaults to the framework's own tracker, `dartway/dartway`.
A finding about the project itself goes to `docs/dev_notes/`, or to the `knownIssues` of the feature
it belongs to.

**The default is deliberate.** A project that never decided where its findings should go is a project
whose findings stay on one laptop, and making the decision a precondition would reproduce exactly that
in every project that skipped it. `--notes-tracker owner/repo` sends them to another repository;
`--notes-tracker none` files nothing outside the project — the finding is written into
`docs/dev_notes/` like any other.

## Keeping it current

- **`dartway setup-ai`** — the first install, or a re-install on the same channel.
- **`dartway update`** — the toolkit from the channel the project is on, plus the report of which
  framework packages the project is behind on and which migration notes it still owes. The
  `dartway-update` skill carries that report out.
- **`--local-repo <checkout>`** (or `DARTWAY_MONOREPO_DIR`) — install from a local monorepo checkout
  instead of a channel, for working on the framework and a project side by side. It records no
  channel. A CLI activated from a checkout uses that checkout when no channel is chosen.

A plain re-run that would move a project to another channel is refused and asks for the channel by
name. The details of both commands are in [The CLI](cli.md).

## What the toolkit does not do

It never changes code silently. `dartway-requirements` and `dartway-plan` write nothing at all;
`dartway-finish` shows what it would change and applies only the confirmed part. The point is a
reviewer that is awake at 2 a.m., not an autopilot.
