---
name: dartway-finish
description: >-
  The definition of done for a DartWay task, run before the commit or PR: runs the gates
  (generate --check, migrate check, analyzers with dartway_lints, dartway check) and tests in
  two modes: targeted locally when pull-request CI carries the full suite, otherwise full locally.
  Reviews the diff against the skills of the layers it touches and the code-shape rules owned here,
  reconciles the descriptions in the code (DwFeatureSpec, doc comments) and the tests,
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
every other skill refers to. Fast gates always run locally, whatever CI does: generation, the
migration check when row classes or migrations changed, all three analyzers, and `check`.

**Choose per suite, by reading the repository's `.github/workflows/*.yml` and `*.yaml`.** A workflow
must run on `pull_request` and execute the suite's command in the right package: `dart test` in
`__SHARED_PKG__`, the pinned CLI's `test` for server acceptance, or `flutter test` in
`__FLUTTER_PKG__`. Read `run`, `working-directory` (including defaults and `cd`), and conditions;
a comment, a push-only workflow, or a command restricted to some tests does not carry a full suite.
Record the workflow file for each covered suite. A suite no pull-request workflow runs in full
runs in full locally. With no CI workflow, run all three suites locally and report
**"no CI workflow: full suites run locally"**.

**For each suite CI carries, select from the A.1 diff, including uncommitted and untracked files:**

- Include every changed or added runnable test file in that package.
- For each changed `lib/` file, include the existing test files in its mirrored directory under
  `test/`: the same `<zone>/<feature>` path, including nested directories. Server paths retain
  `src/`. Use both paths of a rename or move, and the old path of a deletion; run surviving tests.
- A changed file with no mirror makes that package's suite run in full locally. A harness or
  support file, a shared helper, app factory or core wiring, server startup or registration, and
  migrations have package-wide reach: run that suite in full rather than guess a feature. Changes
  outside `lib/` and runnable test files with no feature mirror also use the full fallback. A
  project-wide dependency or test configuration change reaches all affected packages.
- Deduplicate paths. If the package is untouched and no tests are selected, omit its local suite
  and report why; the fast gates still run.

Before running the block, set Bash arrays `SHARED_TEST_FILES`, `SERVER_TEST_FILES`, and
`FLUTTER_TEST_FILES` to the selected paths relative to their suite's package (`__SERVER_PKG__` for
server acceptance even though the CLI runs from `__FLUTTER_PKG__`). Flutter accepts mirrored test
directories as well as files. An empty array means the full local suite. Set `RUN_SHARED_TESTS`,
`RUN_SERVER_TESTS`, and `RUN_FLUTTER_TESTS` to `true` for selected tests or a full fallback, `false`
only for an unaffected suite CI carries. Set `RUN_MIGRATE_CHECK` to `true` when row classes or
migrations changed, otherwise `false`.

```bash
CONTRACT_BASE="$(git merge-base HEAD origin/__BASE_BRANCH__)"  # resolve once; CI supplies its trusted SHA
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway generate --check --contract-base "$CONTRACT_BASE")
if "$RUN_MIGRATE_CHECK"; then
  (cd __SERVER_PKG__ && dart run bin/migrate.dart check)  # needs a database
fi
(cd __SHARED_PKG__ && dart analyze)
if "$RUN_SHARED_TESTS"; then
  (cd __SHARED_PKG__ && dart test "${SHARED_TEST_FILES[@]}")
fi
(cd __SERVER_PKG__ && dart analyze)
(cd __FLUTTER_PKG__ && dart analyze --fatal-infos)          # not flutter analyze: it skips the dartway_lints plugin
if "$RUN_SERVER_TESTS"; then
  (cd __FLUTTER_PKG__ && dart run dartway_cli:dartway test -- "${SERVER_TEST_FILES[@]}")  # real Postgres and storage
fi
if "$RUN_FLUTTER_TESTS"; then
  (cd __FLUTTER_PKG__ && flutter test "${FLUTTER_TEST_FILES[@]}")
fi
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway check --contract-base "$CONTRACT_BASE")
```

- Analyze whole packages: `dart analyze lib` skips `test/`, where moves and API changes break.
- A test red after a refactor is "I broke it" until the base branch shows otherwise.
- `projectContractVersion`: incompatible or unverified is an error, never a skipped gate. Keep the
  baseline SHA fixed after regeneration/feature commits; advance the shared breaking line for an
  incompatible generated shape. Custom/domain/manual module behavior still needs its own review.
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
  answer, a junk shape it matches (`dartway-testing` §4). **For a bugfix, ask for the red its test
  showed before the fix** (§5).
- When a Flutter harness changes, check the real error boundary as well as fake-server calls: an
  exception caught by `dw.action` must fail harness teardown; an explicitly consumed report must
  not hide another one; business refusals stay ordinary outcomes; and teardown errors must not leave
  global handlers or a live core for the next test. Timing-sensitive cache/navigation tests must
  exercise the production client options rather than the harness's zero-delay default.

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
3. 🧪 Tests and gates — what is uncovered or misplaced; each gate's result; the test files run
   locally (expand directory selections), or the full local suite and its fallback reason. Name the
   full-suite owner per suite: **"full suites: CI (`<workflow file>`)"** or
   **"full suites: run locally, no CI"** for suites without coverage. If an unmapped change required a
   full local run despite CI coverage, say so alongside its workflow.
4. 📓 Findings that outlive the task — placed per `dartway-documentation`; a framework issue with its
   text and `impact:` label, shown and waiting for a yes.
5. 🔖 Workarounds — only the markers A.5 found diverged; omit the item otherwise.

## Phase C — apply

Only what was confirmed, in batches the author names. Format only the files of the diff, excluding
sealed migrations: formatting can change their checksum and cause `DwMigrationRefused`. Keep their
`// dart format off` marker. The migrations index can be formatted normally:

```bash
git diff --name-only -z origin/__BASE_BRANCH__...HEAD -- '*.dart' \
  ':(exclude,glob)**/lib/src/migrations/m[0-9]*.dart' | \
  xargs -0 sh -c 'if [ "$#" -gt 0 ]; then dart format "$@"; fi' sh
```

Re-run the gates and targeted tests the applied edits reach, using the same per-suite CI and mirror
rule in A.2, including its full local fallback. End with what was applied, what is left to the
author, each gate's result, the test files run locally, and the same full-suite ownership line as
Phase B item 3.
