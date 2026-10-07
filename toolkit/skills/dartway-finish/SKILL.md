---
name: dartway-finish
description: >-
  The definition of done for a DartWay task, run before the commit or PR: runs the gates
  (generate --check, migrate check, analyzers with dartway_lints, the three test suites, dartway
  check), reviews the diff against the skills of the layers it touches and the code-shape rules
  owned here, reconciles the descriptions in the code (DwFeatureSpec, doc comments) and the tests,
  compares TODO(dartway, checked: …) markers with pubspec.lock, then shows suggestions and applies
  only what was confirmed. Runs as /dartway-finish.
---

# DartWay — finishing a task (`dartway-finish`)

Three phases: **A** audit (read-only), **B** suggestions, **C** apply only what the author
confirmed. Anything debatable or architectural is left to the author with a note, even after "apply
everything".

## A.1 Scope

`git diff --stat origin/__BASE_BRANCH__...HEAD` plus uncommitted work, grouped by package. Generated
files (`*.dw.dart`, `**/generated/**`, `lib/l10n/gen/`) are not reviewed; one in the diff whose source
did not change means `generate` ran over another tree, or not at all.

## A.2 The gates — run them, do not assume them

In this order; report each as run with its result, or not run and why. This is the one list of gates
every other skill refers to.

```bash
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway generate --check)
(cd __SERVER_PKG__ && dart run bin/migrate.dart check)      # row classes or migrations changed; needs a database
(cd __SHARED_PKG__ && dart analyze && dart test)
(cd __SERVER_PKG__ && dart analyze)
(cd __FLUTTER_PKG__ && dart analyze --fatal-infos)          # not flutter analyze: it skips the dartway_lints plugin
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway test)   # server acceptance on a real Postgres and storage
(cd __FLUTTER_PKG__ && flutter test)
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway check)
```

- Analyze whole packages: `dart analyze lib` skips `test/`, where moves and API changes break.
- A test red after a refactor is "I broke it" until the base branch shows otherwise.
- `check`: read the features the task touched in its per-feature report, not only the counter;
  "migrations not checked" is not a pass.
- `frameworkRefsDiverged` is fixed as its own change (`dartway-update`), not in this diff.

## A.3 Review the diff

Read each changed file against the skill of its layer — `dartway-contract`, `dartway-server`,
`dartway-access`, `dartway-realtime`, `dartway-migrations`, `dartway-uploads`,
`dartway-feature-scaffold`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit` — only the
ones the diff reaches. What `check` already failed is not re-reported.

**Stops**, whatever the layer: an access rule wider than intended; a request handler that writes; a
command that changes what a request shows and publishes nothing; an applied migration modified, a drop
that may be a rename, `dataChecksAfter` moved (`dartway-migrations`); a file id written without
`requireOwned`; a swallowed error.

**Code shape — the rules no layer skill owns:**

- A file with more than one responsibility. Length is only the signal: over 200 lines is `fileLong`
  (a nudge), over 350 `fileTooLong` (a warning); a meaningful 300-line file beats a pointless split.
- A top-level function where a factory constructor, a method or getter, an extension (the type is
  someone else's) or a static on an owner class belongs. Exceptions: `main()` and its helpers, test
  helpers.
- `BuildContext` or `WidgetRef` in the parameters of anything but `build`.
- A `_buildXxx()` returning a widget — make it a widget class; a private widget method that
  transforms data — an extension in the feature's `logic/`; a widget in a local variable used once —
  inline it.
- A private widget class in a feature's public file that takes a callback.
- `GlobalKey().currentState`/`currentContext` to reach into the tree.
- A value rebuilt by listing its fields in a constructor instead of the generated `copyWith` — a field
  added later silently takes its default there.
- A swallowed error (`catch (_) {}`, `catch … return null`), a magic number or string, `a.b.c.d`.
- A rule that lives only in a comment ("keep these two in step"): ask what fails if it is ignored
  tomorrow. One source, a check or a type instead — or the comment says that nothing enforces it.

Only a run shows: an `Expanded` put where a caller has no flex parent (walk every caller);
`WidgetStateProperty.all(color)` painting the disabled state too; a DTO without a handler (the server
does not start — make sure a test or a start ran).

**Refactors break `test/`**, which `lib` analysis does not see: a moved file, a function turned method,
a removed parameter, a renamed DTO or code. Bulk import edits go from an explicit old → new path map,
never a regex with a fallback. An entity that moved into the kit and became private keeps its test,
through the public kit widget.

## A.4 Descriptions and tests

- A changed feature: reconcile its `DwFeatureSpec` with the new behaviour; a changed server rule: the
  doc comment where it is enforced; a changed DTO: its doc comments. An outdated description is worse
  than none. Forms: `dartway-feature-scaffold`, `dartway-documentation`.
- Something wrong noticed on the way that this task does not fix is placed now — the routing is
  `dartway-documentation`. So is a statement in the root instruction file (`AGENTS.md` or `CLAUDE.md`) or a skill that the changed code now
  contradicts, either way; a managed file is a framework finding.
- Non-trivial logic, money, a rule or a bugfix without a test is flagged; the test belongs where the
  behaviour lives (`dartway-testing`). So is a new test that fails the gate — a question it cannot
  answer, a junk shape it matches (`dartway-testing` §4). **Ask which one change proved each new test
  red**, and for a bugfix that its test was red before the fix (§5).

## A.5 Workarounds whose framework moved

For each `TODO(dartway, checked: X)` in the changed files (the marker: `dartway-framework-notes`),
read the version the file's package resolves in its `pubspec.lock` — `version`, or `resolved-ref` for
git, compared by prefix; any family package answers for the family, a satellite for itself. **Equal:
say nothing.** Different: one line, and a decision — still needed (refresh `checked:`), done upstream
(delete the workaround and its dev note), or done differently upstream (read what changed first).

## Phase B — the report

1. 🔴 Critical — stops and hidden bugs · 🟡 Major — responsibilities, duplication, per-row queries ·
   🟢 Minor — naming, magic values. Each with `file:line` and a concrete edit.
2. 📄 Descriptions — the proposed `DwFeatureSpec` and doc-comment diffs.
3. 🧪 Tests and gates — what is uncovered or misplaced; each gate's result.
4. 📓 Findings that outlive the task — placed per `dartway-documentation`; a framework issue with its
   text and `impact:` label, shown and waiting for a yes.
5. 🔖 Workarounds — only the markers A.5 found diverged; omit the item otherwise.

## Phase C — apply

Only what was confirmed, in batches the author names. Format only the files of the diff
(`git diff --name-only origin/__BASE_BRANCH__...HEAD -- '*.dart' | xargs dart format`), re-run the
gates the edits reach, and end with what was applied, what is left to the author, which gates are green.
