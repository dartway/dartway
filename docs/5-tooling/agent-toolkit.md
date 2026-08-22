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
  skills/dartway-*/SKILL.md    # 13 skills, loaded by relevance to the task
  commands/commit.md
  commands/dartway-checkup.md
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
named `dartway-*`, and the `commit` / `dartway-checkup` commands. Anything else in `.claude/` — your
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

That is also why a finding about the framework leaves the project entirely. A rule that did not catch
a mistake, two skills that disagree, an API the app had to work around — none of that can be fixed in
the installed copy, and all of it is worth keeping: the rules are only ever proven wrong by real code.
Such a finding is **filed as an issue in the framework's tracker**, and `dartway-finish` writes the
issue text and offers it at the end of a task. Unless `dartway setup-ai --notes-tracker owner/repo`
names another repository, that tracker is the framework's own; `--notes-tracker none` keeps
everything inside the project, and nothing reaches the network.

**The default is deliberate.** A project that never decided where its findings should go was a
project whose findings stayed put — waiting in a git-ignored file that nothing else in the world
could see.

There used to be a journal in between, and it is worth saying why it is gone. It kept a status of its
own beside each entry, which is a second copy of a state that changes elsewhere: one project's
journal advertised eleven open findings a fortnight after all eleven had shipped, the entry asking
for this mechanism among them, because the fixes landed in the monorepo and nothing wrote back to the
laptop. Being git-ignored, it was invisible in every place work is actually reviewed — and a
`git worktree remove` deleted a copy of it without a word, since `git status` says nothing about
ignored files.
Making that decision a precondition would have reproduced the failure in every project that skipped
it.

The half that does **not** travel is the reason filing is not a copy. An entry earns its keep here by
naming this codebase — the file and line, the class, the workaround the app wrote, the marker beside
it — and that is precisely what cannot go into a repository other people read. So `CLAUDE.md` asks
for four things before an issue exists: the finding restated so it stands without this project's
code (if nothing survives that, it was never about the framework), English rather than the project's
language, a search of the tracker first because three projects meeting one API gap is one issue, and
an explicit yes — creating a public issue is the only step in the journal that cannot be taken back.

One kind of finding needs a second half, in the code. A workaround over a `dartway_*` API is written
down as an entry *and* marked where it lives — `// TODO(dartway, checked: 518ae6d): …`, naming the
framework version it was last confirmed against. The reason is that the entry alone answers the
wrong question: it says the workaround exists, never that it is still needed, and the framework
moves while the code does not. A real one outlived its fix by weeks on a project already pinned past
it, and it was not an idle duplicate — it threw where the framework had chosen to degrade softly,
so the app died on an offline start. `dartway-finish` compares `checked:` against the version
resolved in `pubspec.lock` and raises the marker **only** when they have diverged, which is the only
moment the answer can have changed; `/dartway-checkup` runs the same comparison across the whole
project, for the workarounds no task has touched.

## The skills

The lifecycle of a task runs left to right: `dartway-requirements` → `dartway-plan` →
implementation with the layer skills → `dartway-finish`.

**`dartway-run`** — bring the project up locally and confirm it is alive: dependencies, Postgres
in Docker, migrations, the first administrator, server, app. Knows the order that matters, the real ports, where
the sign-in code is printed, and how to read the failures people actually hit.

**`dartway-requirements`** — read-only analysis before a task: what the project already has on the
topic, blocking debt versus adjacent debt, the questions worth asking, and 2–3 implementation
options along the escalation ladder with tradeoffs, risks and a rough estimate.

**`dartway-plan`** — read-only planning once the requirements are agreed: a step-by-step
end-to-end plan (models → migrations → CRUD configs → server logic → Flutter → tests → docs), the
subtleties and risks, and a checklist to verify against afterwards.

**`dartway-clean-code`** — the cleanliness contract for all Dart/Flutter work: self-explanatory
naming, one responsibility per file, never passing `BuildContext` or `WidgetRef` as parameters, no
`_buildXxx()` widget methods, `ref.invalidate` only where the user asked for it, a failed read that
looks like neither an empty list nor a spinner, plus SOLID/KISS/DRY/YAGNI and when tests are
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

**`dartway-testing`** — where a test goes and how to write it: a rule from a `DwCrudConfig` is an
integration test on the server against a live database, plain logic is a unit test, and a feature is
a widget test with the core booted and the server standing in as a recording transport. A DartWay
feature saves for itself and hands no callback out, so the technique is not guessable — and the
skeleton ships a worked example of each layer in its `test/` folder. Also what is deliberately not
tested, and why there are no coverage thresholds.

**`dartway-finish`** — the definition of done before a commit or PR: audits the diff against the
contract, checks the feature's description for drift and the test coverage, then shows suggestions
and applies only what you confirm.

Two commands come with them. `/commit` — a commit in the format the project's CI checks, with the
ticket passed as an argument. And `/dartway-checkup` — the state of the project and what is worth
taking into work next.

The checkup answers two questions for the same person on different days: *how bad is it* and *what
do I fix first*. It runs the project's own gates before reading anything — the checker, the lints,
the analyzer, the tests — then compares that against what CI actually executes, because a rule
declared and never run reads as covered while enforcing nothing. It measures how far the project's
pin trails the framework, since a workaround here may already be a duplicate of something upstream
now does. Only then does it spend reading on a handful of features, chosen from a coverage table so
that successive runs go deeper instead of skimming the same surface.

What it finds gets placed rather than announced, and the test is whether the finding has an address
in code: one that belongs to a feature becomes a line in its `knownIssues`, one about the framework
becomes an issue in the tracker, and a cross-cutting risk with no address at all becomes a file under
`docs/dev_notes/` — tracked and committed, so it travels out in a pull request and is visible in
review. The defect itself lives in the tracker either way; the entry beside the code only references
it, which is why neither carries a status of its own.

## What the toolkit does not do

It never changes code silently. `dartway-requirements` and `dartway-plan` write nothing at all;
`dartway-finish` shows what it would change and applies only the confirmed part, leaving anything
architectural to you with a note. The point is a reviewer that is awake at 2 a.m., not an
autopilot.
