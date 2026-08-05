# What is the `.claude/` folder in a DartWay project?

Every project created by `dartway create` ships with a `.claude/` directory: the methodology of
the framework, written for an agent instead of for a reader. `dartway setup-ai` installs the same
thing into a project you already have.

```bash
dartway setup-ai --base-branch develop
```

## Why the framework ships this at all

DartWay is **highly opinionated**: less freedom in *how* to do things, more consistency and speed.
All Flutter ↔ server traffic goes through CRUD configs, not endpoints. A feature is a folder with
exactly one public file. Styles live in the app's own UI kit and nowhere else. None of that is
guessable from the API surface — an agent reading only your `pubspec.yaml` will write correct Dart
in the wrong shape, confidently, at speed, everywhere.

That is the failure mode worth naming. An agent that does not know the conventions does not
produce compile errors you can fix in a morning; it produces a second architecture living inside
the first one, and it produces it faster than a person can review. The toolkit exists so the agent
writes code in the same conventions a person on the project would — and so the
[conventions checker](conventions-checker.md) agrees with it afterwards.

Toolkit and code evolve in the same repository and the same pull request: a change to a package's
public API updates the affected skills alongside it. A skill that has fallen behind the API is
worse than a missing one — the agent writes non-working code with full confidence.

## What gets installed

```
.claude/
  CLAUDE.md                    # the methodology, always in the agent's context
  skills/dartway-*/SKILL.md    # 12 skills, loaded by relevance to the task
  commands/commit.md
  commands/dartway-audit.md
```

`CLAUDE.md` is the always-loaded brain: the cross-stack laws (CRUD first, domain-first, a feature
is end-to-end), naming rules, what each package is for, why the project uses no `build_runner`,
and where a feature's description lives — in `DwFeatureSpec` next to the code, not in a doc beside
it.

The installer detects your package layout by directory suffix (`*_server`, `*_client`,
`*_flutter`, optional `*_shared`) and substitutes the names into the installed markdown, so the
skills talk about `my_app_flutter`, not about a placeholder. `--base-branch` is substituted the
same way, so the commit and PR skills diff against the branch your project actually uses.

Commit `.claude/` to your repository. It is a generated-but-committed artifact, like the Serverpod
client: a clone comes with the skills already in place, and the history records which version of
the methodology a piece of code was written under.

## Managed files, and how to customize

Reinstalling overwrites **only what the toolkit manages**: `CLAUDE.md`, every skill directory
named `dartway-*`, and the `commit` / `dartway-audit` commands. Anything else in `.claude/` — your
own skills, your own commands — is never touched.

So do not edit a `dartway-*` skill in place; the next `setup-ai` will drop your changes on the
floor. To customize, **copy the skill under a different name** and edit the copy. The source of
truth is the toolkit in the monorepo, and there is no reverse sync.

Updating is a deliberate act with a visible diff: run `setup-ai` again, read what changed, commit.

`.claude/settings.json` sits on the other side of that line: it is written once, when the project
has none, and never touched again. It pre-approves this stack's build commands — `dart pub get`,
`docker compose up`, `serverpod generate`, the test runners — so a first run is not a queue of
permission prompts, and it denies reading `config/passwords.yaml`, which turns a rule the skills
merely state into one the harness enforces. Nothing destructive is on the allow list: `docker
compose down`, commits and pushes still ask. A project adds its own permissions there, and an
update will not take them away — the price being that a changed default reaches an existing project
only if someone deletes the file first.

That is also why the install leaves a `dartway_notes.md` at the project root, git-ignored. A rule
that did not catch a mistake, two skills that disagree, an API the app had to work around — none of
that can be fixed in the installed copy, and all of it is worth keeping: the rules are only ever
proven wrong by real code. The journal is where such findings wait to be carried into the monorepo,
and `dartway-finish` lists the open ones at the end of a task so they do not just accumulate.

## The skills

The lifecycle of a task runs left to right: `dartway-requirements` → `dartway-plan` →
implementation with the layer skills → `dartway-finish`.

**`dartway-run`** — bring the project up locally and confirm it is alive: dependencies, Postgres
in Docker, migrations, seeding, server, app. Knows the order that matters, the real ports, where
the sign-in code is printed, and how to read the failures people actually hit.

**`dartway-requirements`** — read-only analysis before a task: what the project already has on the
topic, blocking debt versus adjacent debt, the questions worth asking, and 2–3 implementation
options along the escalation ladder with tradeoffs, risks and a rough estimate.

**`dartway-plan`** — read-only planning once the requirements are agreed: a step-by-step
end-to-end plan (models → migrations → CRUD configs → server logic → Flutter → tests → docs), the
subtleties and risks, and a checklist to verify against afterwards.

**`dartway-clean-code`** — the cleanliness contract for all Dart/Flutter work: self-explanatory
naming, one responsibility per file, never passing `BuildContext` or `WidgetRef` as parameters, no
`_buildXxx()` widget methods, no `ref.invalidate`, plus SOLID/KISS/DRY/YAGNI and when tests are
required.

**`dartway-feature-scaffold`** — building a feature end to end: navigation → entry point → state
and logic → CRUD configs → models → tests, with the feature structure, its isolation, and the
`DwFeatureSpec` written in the feature's own file.

**`dartway-models`** — Serverpod `.spy.yaml` models: base versus event models, nullable
discipline, bidirectional relations and `onDelete`, indexes, enums, and the edit → generate →
migrate → config workflow.

**`dartway-crud-config`** — the server playbook: `DwCrudConfig<T>` and its hooks, read configs and
their mandatory `accessFilter`, `DwModelWrapper`, the pure-domain versus session-aware boundary.
All server logic goes through configs, not endpoints.

**`dartway-data-layer`** — the Flutter data layer: reads and writes through `dw.repo`, lists via
`dwBuildListAsync`, backend filtering versus local filtering, actions through `dw.action`,
notifications through `dw.notify.*` rather than `SnackBar`, the profile getters.

**`dartway-navigation`** — the DartWay router: zones as enums, route descriptors, zone guards,
type-safe enum parameters, and how the router is assembled.

**`dartway-ui-kit`** — the kit lives as source inside the app: the framework ships no buttons, no
text widget and no theme. App widgets with named constructors, `DwActionBuilder`, and the ban on
raw styles inside features.

**`dartway-push-delivery`** — server-side push through the optional `dartway_push_server` module:
the engine, recipient resolution, FCM/RuStore transports, idempotent enqueue, retries, campaign
progress. Opt-in — an app that does not depend on it has no push tables.

**`dartway-finish`** — the definition of done before a commit or PR: audits the diff against the
contract, checks the feature's description for drift and the test coverage, then shows suggestions
and applies only what you confirm.

Two commands come with them: `/dartway-audit` — a deep review of a module or the whole app against
the same contract; `/commit` — a commit in the format the project's CI checks, with the ticket
passed as an argument.

## What the toolkit does not do

It never changes code silently. `dartway-requirements` and `dartway-plan` write nothing at all;
`dartway-finish` shows what it would change and applies only the confirmed part, leaving anything
architectural to you with a note. The point is a reviewer that is awake at 2 a.m., not an
autopilot.
