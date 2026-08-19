---
name: dartway-finish
description: >-
  Finishing a dartway task before a commit/PR (DartWay projects): the "definition of done".
  Audits the diff against the base branch using the dartway-clean-code contract (Flutter + server),
  checks the affected feature's description for drift (DwFeatureSpec next to the code, doc comments
  above the CRUD config) and test coverage, then SHOWS suggestions and applies ONLY what was
  confirmed — it never changes anything silently. Use when a task/feature is done, before committing
  or opening a PR (Law 6); runs as /dartway-finish.
---

# DartWay — finishing a task (`dartway-finish`)

The "definition of done" for a dartway task. Run it when the work on a task/feature is done — **before the commit/PR** (Law 6). It audits the changes, checks the documentation and the tests, and helps bring the task up to the contract.

## ⛔ Safety principle

The skill works in three phases and **never changes code or docs without the author's explicit confirmation**. Phases A (audit) and B (suggestions) are read-only. Phase C (application) covers only what the author confirmed. Anything debatable or architectural the skill **does not touch** — it leaves it to the author with a note.

The rules come from `dartway-clean-code` (the cleanliness contract), plus `dartway-data-layer`, `dartway-models`, `dartway-crud-config`, `dartway-navigation`, `dartway-ui-kit`. It is the same body of rules the `/dartway-checkup` command uses; the difference: `dartway-finish` looks at **the diff of a single task** and adds docs sync + a test check + a confirmation loop.

---

## Phase A — Audit (read-only)

### A.1 Diff scope
Determine the changes: `git diff --stat origin/__BASE_BRANCH__...HEAD` + uncommitted work (`git status`, `git diff`). Collect the list of changed `.dart`/`.spy.yaml`/doc files.

**Exclude generated code from the audit** (it is not reviewed): `**/generated/**`, `*.g.dart`, `*.freezed.dart`, the whole `__CLIENT_PKG__` package, `*.spy.yaml` generated output. We audit handwritten code only.

### A.2 Auditing the code against the contract
Run the detectors **over the changed files only** (not over the whole repo). For every finding — `file:line`.

**Flutter (`dartway-clean-code` Part 1 + specials):**
- Several responsibilities in one file (length is the weakest signal: >200 lines — take a look, >350 — a warning; a meaningful 300-line file beats a pointless split).
- `BuildContext`/`WidgetRef` in the parameters of services/functions (outside `build`).
- A `_buildXxx()` returning a `Widget` (instead of a widget class).
- `ref.invalidate(...)` used for refreshing.
- `GlobalKey().currentState/currentContext` used to look things up in the tree.
- Outer `padding`/`margin` at the top level of a widget's `build`.
- A private widget class (`class _Foo extends ...Widget`) inside a feature's public file that **has a `State` or takes a callback** — a slice of layout with neither is fine (`dartway-clean-code` §1.8).
- A feature's constructor carrying **data its parent computed**: ready-made lists, a `Map`, a flag derivable from a model already passed, or more than one callback. The question per parameter is "could the widget have got this itself?" (§1.9a), and the check on the whole is "can I construct it from identifiers and models alone?" (`dartway-feature-scaffold`).
- An action handed **downwards** as a callback instead of being written with `dw.action` in the widget that owns the button; a screen-wide `busy` flag duplicating `DwActionBuilder` (§1.9b).
- A file in a feature's `widgets/` that imports the client package to switch over a model, pick a label, or fire an action — that is a feature standing in the wrong place (`dartway-feature-scaffold`, "Groups").
- A provider named after a screen (`<Screen>Snapshot`/`State`/`ViewModel`) whose fields fewer than half its consumers read; anything derived from a **single** model belongs on that model as an extension (`dartway-data-layer` §4a).
- Several `modelList` calls of related types stitched together by foreign key in the widget — the graph arrives with the model (`dartway-data-layer` §3a).
- Naming shorter than 2 words; the forbidden `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x`.
- Specials (`dartway-data-layer`): `SnackBar`/`ScaffoldMessenger` instead of `dw.notify.*`; `watchModel<UserProfile>()` instead of `ref.watchUserProfile`; a raw `onPressed`/`() async {}` instead of `dw.action`; raw `Color`/`TextStyle`/`BorderRadius`/`context.theme` in features instead of the UI Kit; `router.go()`/string routes instead of enum routes and context extensions (`dartway-navigation`).
- Feature isolation: importing a non-entry-point file of another feature.
- A feature's entry-point widget without `implements DwFeature` / `DwFeatureSpec` — the feature exists in the code but says nothing about itself (its spec is read by error reports, Studio, and the agent). Changed the feature's behavior — reconcile `behaviors`: an outdated spec is worse than a missing one. How to fill it in — `dartway-feature-scaffold`, "Feature spec".
- **Ran into a "this is wrong here" during the audit — that is a line in that feature's `knownIssues`, not in the report and not in your head.** A setting nobody reads; a screen on mocks; commented-out sorting while the field is still live in the form. The audit is the only moment when this is visible, and `knownIssues` is the only place where it will survive until it is dealt with: Studio filters by it. Fixed it within this same task — you delete the line.
- Part 2: SRP/God objects, DRY (copy-pasted widgets/mappings), KISS/YAGNI, the Law of Demeter (`a.b.c.d`), SoC (logic in State/UI), tell-don't-ask, magic numbers/strings, a single source of truth, swallowed errors (`catch (_) {}`, `catch ... return null`).

**Server (`dartway-crud-config` / `dartway-models`):**
- An arbitrary endpoint instead of a CRUD config (without a documented exception).
- A model without a `DwCrudConfig`, or not registered in `crudConfigurations`.
- A direct field update (e.g. `balance`) instead of an Event model in transactional/money logic.
- Swallowed errors in config callbacks; nullable "for the UI's sake" in `.spy.yaml`.
- A model with an `include` leaving the server **without** it — a save response with no `afterSaveTransform` re-read, a `DwModelWrapper(object: parent)` written straight into `afterUpdates`, a worker's `sendUpdates` with the flat row. The client replaces its copy wholesale, so the nested lists are blanked on every device with no error anywhere (`dartway-data-layer` §3a). Countable: places the parent goes out vs calls to the loader that carries the include.

### A.3 Checking the description (it lives in the code)

There are no separate docs per feature — the description sits where the code sits, so there is nothing to look for: it is **in the same diff**.

- A file inside a feature changed — open the feature's public file and reconcile `DwFeatureSpec` with the new behavior. A new observable action appeared — an item in `behaviors`; an existing one changed — fix the wording. **An outdated spec is worse than a missing one:** it is read by error reports, Studio, and the next agent.
- A CRUD config changed — reconcile the doc comments above it: permissions, validations, side effects. A rule appeared that cannot be read off the code ("why `accessFilter` is exactly like this") — a comment above the config.
- A new feature without a `DwFeatureSpec` is not finished. The checker will emit `featureSpecMissing`.
- Tempted to write a document about what you just did — don't; a DartWay project keeps no `docs/` folder. If the urge is about one feature, it means the description did not fit into the spec, and the question is why the spec does not answer it. If it is about something cross-cutting (the analytics event registry, the settings catalog, the access matrix), it belongs in code — an enum or constants in `lib/core/` with doc comments, where the compiler and the checker can see it.
- Check whether the statements in `CLAUDE.md` (root or per-package) or in the skills have drifted apart from the changed code (in both directions — that is how we found the `DwCallback`→`DwUiAction` drift).

### A.3a Edits the analyzer does not catch

Check separately, by eye, the things that only break at runtime:

- **Sizing mechanics.** You replaced a `SizedBox`/`Padding` with an `Expanded` (or the other way round) — walk
  **every caller**: `Expanded` requires a flex parent, and the widget may have been put into a bottom sheet,
  a `SingleChildScrollView`, or a dialog, where there is no flex parent. `dart analyze` will stay quiet, it
  will crash for the user.
- **An explicit color instead of a theme color.** `WidgetStateProperty.all(color)` paints **all** states,
  including `disabled`: when adding or removing such a parameter, check how the widget looks disabled
  and while the action is running.
- **Provider family keys.** A family keyed by an object compared by identity silently
  creates a new provider on every build. The framework's own key has the same edge: a
  `DwModelListStateConfig` compares `relationUpdatesConfigs` **by list reference**, so that list must be a
  top-level `final` and not assembled in place (`dartway-data-layer` §3a).

### A.3b Tests are part of the refactoring surface

Tests reference the code **by path and by name**, and often reference internals (`logic/`, `widgets/`)
— which is legitimate for a unit test. So any of these edits breaks `test/`, and analyzing `lib` will
not show it:

- **you moved or renamed a file** — the imports in the tests lead nowhere;
- **a free function became a method of a class or an extension** — the call `doThing(x, ...)` no longer
  compiles, it has to be `x.doThing(...)`;
- **you removed a parameter from a widget's public API** (e.g. a visual parameter moved into the kit) — the test
  passes something that no longer exists, or fails to pass something that became required;
- **you dropped code generation** — the tests keep calling `Assets.*` / `FontFamily.*`;
- **you moved `@riverpod` to a manual provider** — the test overrides stop compiling (see
  `dartway-data-layer`, "Overriding a provider in a test").

**The rule:** do bulk import edits from an explicit "old path → new path" map. A regex with a
fallback that "just in case" substitutes something when it does not match will silently rewrite half the project
— one such run cost 64 broken files and a restore from `git show`.

**A public entity moved into the kit and became private** — do not throw its test away: the same behavior
is verified through the public kit widget. A test of a private composition → a test of its wrapper.

### A.4 Checking the tests
- Non-trivial logic/money/"downgrade" rollbacks or a bugfix **without a test** → flag it (`dartway-clean-code` Part 3). We do not demand tests for cosmetics.
- **Ask whether the test sits at the layer the behaviour lives at** (`dartway-testing`). The common
  miss is not an absent test but a misplaced one: an access rule from a `DwCrudConfig` "covered" by a
  widget test that only proves the button is hidden — the UI hiding it is not the rule, and the rule
  is what breaks. That belongs in an integration test on the server; the widget test then covers what
  it can, which is that the button sends the right model.
- **Do not ask for a coverage number and do not report one.** The question is whether the thing that
  would break is covered, at the layer where it lives — a percentage is met by covering what was
  never at risk.

### A.5 Automated checks
- **`dartway check` in the Flutter package is mandatory.** It checks what neither the analyzer nor the lints see: the structure of features and groups, the boundaries (importing another feature's internals at any depth), styles bypassing the kit, missing feature specs, dead code inside a feature (`unusedFeatureFile` — a widget or helper its own feature stopped using; nobody outside may import it, so nothing else can see it is gone), references to non-existent assets. The report is per-feature, with an A–D grade — look at the features the task touched, not just at the overall counter.
- **A `frameworkRefsDiverged` warning is worth acting on even when the task did not cause it.** If this project takes the framework from git, `ref: master` is written once per package and reads as "all of it from master", while the lock pins each package at whatever master was when *that* package was added — so the halves of the framework drift apart with no version number anywhere to show it. The check names the commits and the directories; `dart pub upgrade` on the dartway packages there brings them back together. Do it as its own change, not folded into the task's diff.
- `dart analyze` (server) and `flutter analyze` (Flutter) — must be clean.
- **Analyze the whole package, without a path argument.** `dart analyze lib` looks faster and "good enough", but `test/` is not included in it — and tests reference the code by paths and names, which is exactly where the consequences of moves and API changes settle. A green `dart analyze lib` with 59 compilation errors in `test/` is a case that actually happened.
- **`dart run custom_lint` in the Flutter package is mandatory.** `flutter analyze` does NOT run its rules, and it is `dartway_lints` that catches the ban on raw `Color`/`TextStyle`/`BorderRadius` outside ui_kit and the other conventions. A green `flutter analyze` with a red `custom_lint` is a classic trap.
- **A generated-code diff wider than the models the task touched is almost never a real change.** If `git diff --stat` over `__SERVER_PKG__/lib/src/generated/` or `__CLIENT_PKG__/lib/src/protocol/` names files the task has nothing to do with, the cause is a formatter mismatch, not new behaviour: `serverpod generate` writes through the `dart_style` bundled with the Serverpod CLI, and the repository holds code formatted by the project's SDK. Do not read those files line by line looking for what changed, and do not commit them — run `dart format` over **both** paths and re-check, remembering that `create-migration` regenerates, so the format pass has to be the last step of the three (`dartway-models`). `dartway check` reports the state as `generatedCodeUnformatted`. What survives the format pass is the real diff, and that is what gets reviewed.
- **`flutter test` was actually run, not "the tests probably weren't touched".** The analyzer proves that the code compiles and says nothing about behavior: an overflow in a narrow layout, an uninitialized `dw`, a layout that fell apart — all of that is only visible in a run. A test failing after a refactoring starts with the hypothesis "I broke it", and only after checking against HEAD becomes "the test was red before me".

### A.6 Findings that outlive this task

Some of what you noticed is not about this diff at all, and it dies in the chat unless it is placed.
Every finding has exactly one home — take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed in this task | fix it — no entry anywhere |
| belongs to one feature | that feature's `knownIssues`, proposed in Phase B |
| is about the **framework**: a rule that does not exist or is too vague to have prevented the mistake, two skills that disagree, an API that forced a workaround | `dartway_notes.md` |
| is a nuance, problem or technical risk of **this project** that does not fit the task and is not confined to one feature | `dev_notes.md` |

Both journals sit at the project root and are git-ignored. The framework one exists because the
managed files cannot be fixed here — they are overwritten on update (see `CLAUDE.md`).

- **Write down now** anything of either kind you have not written yet. `dartway_notes.md` asks for
  the example, why the rule missed it and the wording to add. `dev_notes.md` asks for three lines:
  where, what is wrong, what it leads to — an option may be named, not written up.
- **Then list the `open` entries of both** in the report, one line each. A reminder, not a gate: the
  task is finished either way, but the entries stop being invisible.
- **When `dartway_notes.md` names a tracker other than `none`**, an entry with no issue yet is offered
  for filing, and one that has an issue is reported by its state rather than by what the file says —
  `gh issue view` answers that, the file does not. An issue that has closed is the signal to delete
  the entry, and to re-check the workaround it stood for if there was one. What to strip and restate
  before filing is in `CLAUDE.md`, "Where an entry goes when it leaves this project" — including the
  `impact:` label, which is proposed with the text rather than left for someone to guess later,
  because what the finding cost this project is known now and not afterwards. The step is a proposal
  like every other one here, never a push that happens on its own.
- **A workaround over a `dartway_*` API is written down twice** — the entry in `dartway_notes.md`,
  and a `TODO(dartway, checked: <ref>)` marker on the code itself (see `CLAUDE.md`, "Notes back to
  the framework"). The journal says what should change upstream; the marker says what to re-check
  here once it has. Wrote the entry and left the code bare — add the marker now.

### A.7 Workarounds whose framework has moved

A marker records the framework version its workaround was last confirmed against. This step compares
that version with the one the project actually resolves, and **stays silent unless they differ**.

The conditionality is the point. "Re-verify every workaround before every commit" is expensive,
which means it gets skipped, which means it is not a check at all — while a workaround's answer can
only have changed when the framework under it changed. Ask then, and the question is worth reading.

1. **Collect** the `TODO(dartway, checked: X)` markers in the files this diff touches. Not
   project-wide: what the task did not open is not this task's business, and the whole-project sweep
   belongs to `/dartway-checkup`.
2. **Resolve** the version the project is actually on, from the `pubspec.lock` of the package the
   marked file belongs to: `resolved-ref` for a git dependency (`source: git`), `version` for a
   hosted one. Take the entry of the `dartway_*` package the workaround sits on top of — the core,
   the Flutter toolbox and the plugins move independently, so the wrong entry answers a different
   question.
3. **Compare.** Equal — say nothing at all, not even "checked, still current". Different — one line
   in the report (Phase B, item 7).

Compare git refs by prefix: the lock file holds all 40 characters and a marker usually holds seven,
so test whether the longer starts with the shorter. A `version` comparison is exact.

**What that line asks for is a decision, not an edit.** Three outcomes, and only the first is a
one-token change:

- the workaround is still needed → refresh `checked:` to the resolved version;
- the framework now does this → delete the workaround, and close the `dartway_notes.md` entry with it;
- the framework now does this **differently** → the case the whole mechanism exists for. A workaround
  that duplicates the framework only wastes code; one that contradicts it breaks the app, and it
  breaks it in exactly the edge case the framework had thought about — throwing where the framework
  degrades softly, failing closed where it fails open. Read what actually changed upstream before
  choosing.

---

## Phase B — Suggestions (show, do not apply)

Produce a structured report in the chat:

1. **🔴 Critical** — contract/architecture violations that hide bugs (Part 1, swallowed errors, God objects, broken feature isolation, an endpoint instead of CRUD). `file:line` + how to fix.
2. **🟡 Major** — serious violations of principles (SRP, DRY, SoC, long files).
3. **🟢 Minor** — naming, magic numbers, small stuff.
4. **📄 Docs** — which feature docs/`CLAUDE.md`/skills are outdated, **with a concrete proposed diff** for the fix.
5. **🧪 Tests** — which non-trivial parts are uncovered.
6. **📓 Journals** — the `open` entries of both, one line each. From `dartway_notes.md`: what it is
   and where in the monorepo it lands — plus its issue and that issue's current state where a tracker
   is configured, and an offer to file the ones that have none. From `dev_notes.md`: what this project
   is carrying. Nothing is applied here — the first list is what to take to the framework, the second
   is what to schedule.
7. **🔖 Workarounds** — only the markers A.7 found diverged, one line each: `file:line`, what is
   worked around, `checked:` versus the resolved version. **Omit the whole item when nothing
   diverged** — this section appears when the framework has moved under a workaround, and a report
   that prints it every time teaches the reader to skip it. Mark it for the author to decide: which
   of A.7's three outcomes applies is answered by reading the framework, not by this skill.

For every item give a **concrete proposed edit**, ready to apply. Mark anything debatable/architectural as "for the author to decide" — do not propose an automatic fix.

---

## Phase C — Application (only on confirmation)

- Ask what to apply. Support batches: "apply the docs", "apply Minor", "apply everything except the architectural items", or item by item by number.
- Apply **only what was confirmed**. Nothing silently.
- After applying edits to a doc, update `last-verified` in its header to today's date.
- Do not touch anything debatable/architectural, even if the author said "all of it" — ask again about such items separately.
- At the end — a short summary: what was applied, what is left to the author.

---

## How this differs from `/dartway-checkup`

| | `dartway-finish` (skill) | `/dartway-checkup` (command) |
|---|---|---|
| Scope | the diff of one task vs the base branch | the whole project by default — packages, CI, configs, pins — narrowed by an argument |
| Extra checks | docs sync + tests + application | the gates actually running, the distance to the framework, a rolling deep pass over features |
| Output | report + edits on confirmation | report in the chat + entries placed in `knownIssues` / the journals |
| When | finishing a task, before a PR | on demand, and periodically — its findings change without a commit here |

The detectors are shared (their source is `dartway-clean-code`). Do not duplicate the logic — reference the contract.
