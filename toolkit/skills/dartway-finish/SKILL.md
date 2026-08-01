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

The rules come from `dartway-clean-code` (the cleanliness contract), plus `dartway-data-layer`, `dartway-models`, `dartway-crud-config`, `dartway-navigation`, `dartway-ui-kit`. It is the same body of rules the `/dartway-audit` command uses; the difference: `dartway-finish` looks at **the diff of a single task** and adds docs sync + a test check + a confirmation loop.

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
- A private widget class (`class _Foo extends ...Widget`) **with value for reuse/testing** inside a feature's public file (a trivial local helper for a single screen is fine, see `dartway-clean-code` 1.8).
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

### A.3 Checking the description (it lives in the code)

There are no separate docs per feature — the description sits where the code sits, so there is nothing to look for: it is **in the same diff**.

- A file inside a feature changed — open the feature's public file and reconcile `DwFeatureSpec` with the new behavior. A new observable action appeared — an item in `behaviors`; an existing one changed — fix the wording. **An outdated spec is worse than a missing one:** it is read by error reports, Studio, and the next agent.
- A CRUD config changed — reconcile the doc comments above it: permissions, validations, side effects. A rule appeared that cannot be read off the code ("why `accessFilter` is exactly like this") — a comment above the config.
- A new feature without a `DwFeatureSpec` is not finished. The checker will emit `featureSpecMissing`.
- Tempted to create a file in `docs/` named after the feature — don't: it means the description did not fit into the spec, and the question is why the spec does not answer it. `docs/1_general/` is only for cross-cutting references that have no feature of their own (the analytics event registry, the settings catalog, the access matrix).
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
  creates a new provider on every build.

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

### A.5 Automated checks
- **`dartway check` in the Flutter package is mandatory.** It checks what neither the analyzer nor the lints see: the structure of features and groups, the boundaries (importing another feature's internals at any depth), styles bypassing the kit, missing feature specs, dead code inside a feature (`unusedFeatureFile` — a widget or helper its own feature stopped using; nobody outside may import it, so nothing else can see it is gone), references to non-existent assets. The report is per-feature, with an A–D grade — look at the features the task touched, not just at the overall counter.
- `dart analyze` (server) and `flutter analyze` (Flutter) — must be clean.
- **Analyze the whole package, without a path argument.** `dart analyze lib` looks faster and "good enough", but `test/` is not included in it — and tests reference the code by paths and names, which is exactly where the consequences of moves and API changes settle. A green `dart analyze lib` with 59 compilation errors in `test/` is a case that actually happened.
- **`dart run custom_lint` in the Flutter package is mandatory.** `flutter analyze` does NOT run its rules, and it is `dartway_lints` that catches the ban on raw `Color`/`TextStyle`/`BorderRadius` outside ui_kit and the other conventions. A green `flutter analyze` with a red `custom_lint` is a classic trap.
- **`flutter test` was actually run, not "the tests probably weren't touched".** The analyzer proves that the code compiles and says nothing about behavior: an overflow in a narrow layout, an uninitialized `dw`, a layout that fell apart — all of that is only visible in a run. A test failing after a refactoring starts with the hypothesis "I broke it", and only after checking against HEAD becomes "the test was red before me".

---

## Phase B — Suggestions (show, do not apply)

Produce a structured report in the chat:

1. **🔴 Critical** — contract/architecture violations that hide bugs (Part 1, swallowed errors, God objects, broken feature isolation, an endpoint instead of CRUD). `file:line` + how to fix.
2. **🟡 Major** — serious violations of principles (SRP, DRY, SoC, long files).
3. **🟢 Minor** — naming, magic numbers, small stuff.
4. **📄 Docs** — which feature docs/`CLAUDE.md`/skills are outdated, **with a concrete proposed diff** for the fix.
5. **🧪 Tests** — which non-trivial parts are uncovered.

For every item give a **concrete proposed edit**, ready to apply. Mark anything debatable/architectural as "for the author to decide" — do not propose an automatic fix.

---

## Phase C — Application (only on confirmation)

- Ask what to apply. Support batches: "apply the docs", "apply Minor", "apply everything except the architectural items", or item by item by number.
- Apply **only what was confirmed**. Nothing silently.
- After applying edits to a doc, update `last-verified` in its header to today's date.
- Do not touch anything debatable/architectural, even if the author said "all of it" — ask again about such items separately.
- At the end — a short summary: what was applied, what is left to the author.

---

## How this differs from `/dartway-audit`

| | `dartway-finish` (skill) | `/dartway-audit` (command) |
|---|---|---|
| Scope | the diff of one task vs the base branch | a whole module/folder on request |
| Extra checks | docs sync + tests + application | code audit only |
| Output | report + edits on confirmation | report in the chat |
| When | finishing a task, before a PR | a deep check of an area on demand |

The detectors are shared (their source is `dartway-clean-code`). Do not duplicate the logic — reference the contract.
