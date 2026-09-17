---
name: dartway-finish
description: >-
  Finishing a dartway task before a commit/PR (DartWay projects): the "definition of done".
  Audits the diff against the base branch using the dartway-clean-code contract (contract, server,
  app), runs the checks (`dartway generate --check`, `dart run bin/migrate.dart check` when row
  classes or migrations changed, the analyzers and custom_lint, the shared package's `dart test`,
  `dartway test`, `flutter test`, `dartway check`), reconciles the descriptions that live in the
  code — `DwFeatureSpec` for a screen, doc comments above handlers and rules for the server, above
  DTOs for the contract — with what changed, compares `TODO(dartway, checked: …)` workaround markers
  with pubspec.lock, then SHOWS suggestions and applies ONLY what was confirmed — it never changes
  anything silently. Use when a task/feature is done, before committing or opening a PR; runs as
  /dartway-finish.
---

# DartWay — finishing a task (`dartway-finish`)

The "definition of done" for a dartway task. Run it when the work on a task or feature is done —
**before the commit/PR**. A feature is not finished until its diff has been audited against the
cleanliness contract and its description, which lives in the code, says what the code now does.

## ⛔ Safety principle

The skill works in three phases and **never changes code or docs without the author's explicit
confirmation**. Phases A (audit) and B (suggestions) are read-only. Phase C (application) covers only
what the author confirmed. Anything debatable or architectural the skill **does not touch** — it
leaves it to the author with a note.

The rules come from `dartway-clean-code` (the cleanliness contract), plus the layer skills:
`dartway-contract`, `dartway-server`, `dartway-access`, `dartway-realtime`, `dartway-data-layer`,
`dartway-migrations`, `dartway-uploads`, `dartway-navigation`, `dartway-ui-kit`,
`dartway-feature-scaffold`. It is the same body of rules `/dartway-checkup` uses; the difference:
`dartway-finish` looks at **the diff of a single task** and adds the description sync, the test check,
the checks run and a confirmation loop.

---

## Phase A — Audit (read-only)

### A.1 Diff scope

Determine the changes: `git diff --stat origin/__BASE_BRANCH__...HEAD` plus uncommitted work
(`git status`, `git diff`). Collect the changed `.dart` files, `.arb` files and migrations, grouped by
package: `__SHARED_PKG__`, `__SERVER_PKG__`, `__FLUTTER_PKG__`.

**Exclude generated code from the audit** — it is not reviewed, it is regenerated: `**/generated/**`,
`*.dw.dart`, `lib/l10n/gen/`. We audit handwritten code only. A generated file in the diff whose
source did not change is a signal, not a subject: `dartway generate` was run over a different tree,
or not run at all (A.5).

### A.2 Auditing the code against the contract

Run the detectors **over the changed files only** (not over the whole repo). For every finding —
`file:line`.

**The contract (`__SHARED_PKG__`, `dartway-contract`):**
- A DTO of the wrong kind: a read written as a command, a change written as a request; a command
  answering a bare collection instead of a data object that wraps it.
- `matches`, `sort`, `channels` or an overridden `onUpdate` that is not a pure function of the object
  and the request's fields — `DateTime.now()`, a global, a random value inside them.
- A request that shows data others change, with no `channels` — it will not follow updates; a "my …"
  request on a fixed channel instead of `DwLiveChannel.ofCaller` (`dartway-realtime`).
- Field rules checked on one side only where both sides could apply them — they belong in
  `validate()` of a `DwSelfValidating` command.
- A refusal the user reads that is not a code of the project's refusal enum, or text travelling in a
  refusal.
- Naming: a public class name of one word; a data object that is not a two-word noun; a read not
  starting `Get…`/`List…`; a change that is not verb + object.
- A DTO, field or refusal code whose meaning is not obvious, without a doc comment.

**The server (`__SERVER_PKG__`, `dartway-server`, `dartway-access`, `dartway-realtime`):**
- A handler whose `access:` is wider than the rule it serves — `DwAccessRule.anonymous` on something
  not meant for everyone, `signedIn` where ownership or a role decides — or an ownership check that
  lets another account's row through.
- A request handler that writes. Requests are retried freely and have no side effects; a write there
  runs again on every retry.
- A command that changes what some request shows and publishes nothing to that request's channel —
  the author's other screens and other people's stay stale, with no error anywhere. And a publication
  to `DwLiveChannel.ofCaller(...)` on the server (it throws): publish to
  `DwLiveChannel.forAccount(kind, accountId)`.
- Read-modify-write of a counter, a balance or a status without `lock: DwRowLock.forUpdate` — two
  concurrent commands both read the old value.
- A row rebuilt by listing its fields in the constructor instead of `copyWith` (`dartway-clean-code`).
- Related data loaded per row inside a loop — one query per relation for the whole batch; file URLs
  through one `ctx.files.publicUrls` call per batch.
- A file id from a command written onto a row without `ctx.files.requireOwned` (`dartway-uploads`); a
  replaced or cleared file not deleted.
- `ctx.refuse` and throwing confused: an answer for the user is a refusal code; an incident is an
  exception. A swallowed error (`catch (_) {}`, `catch … return null`) is neither.
- `transactional: false` on a command without a stated reason.
- A row class change with no migration in the diff; a migration that imports a row class or anything
  from `lib/`; a migration file that existed on the base branch and is **modified** in the diff
  (`dartway-migrations` — a stop, see A.5).

**The app (`__FLUTTER_PKG__`, `dartway-clean-code` Part 1 + specials):**
- Several responsibilities in one file (length is the weakest signal: >200 lines — take a look, >350 —
  a warning; a meaningful 300-line file beats a pointless split).
- `BuildContext`/`WidgetRef` in the parameters of services/functions (outside `build`).
- A `_buildXxx()` returning a `Widget` (instead of a widget class).
- `ref.invalidate(...)` used to **propagate** data — after a command, in a listener, to move data
  between screens. Under a gesture (retry, pull-to-refresh) it is correct and not a finding. After a
  command it usually means the request does not listen on the channel the command publishes to — fix
  the channel, not the screen (`dartway-realtime`).
- A **load-bearing** `dwBuildAsync`/`dwBuildListAsync` — the section its screen exists for — left on
  the default `errorWidget` (`SizedBox.shrink()`), so a failed read renders as blank; and
  `asData?.value` / `.value ??` used to combine several `AsyncValue`s, which shows a failure as an
  endless spinner.
- Server data copied into widget `State` or a hand-written notifier — it stops following updates.
  Reads are `ref.watch(dw.request(...))`, `dw.pages`, `dw.table`, `dw.window` (`dartway-data-layer`).
- A raw `onPressed: () async { await dw.command(...) }` instead of `dw.action`; a refusal turned into
  words anywhere but the app's refusal text (the function `DwFlutterConfig.refusalText` is given).
- `GlobalKey().currentState/currentContext` used to look things up in the tree.
- Outer `padding`/`margin` at the top level of a widget's `build`; a widget that sizes itself.
- A private widget class inside a feature's public file that **has a `State` or takes a callback** — a
  slice of layout with neither is fine.
- A feature's constructor carrying **data its parent computed**: ready-made lists, a `Map`, a flag
  derivable from an object already passed, or more than one callback. The question per parameter is
  "could the widget have got this itself?", and the check on the whole is "can I construct it from
  identifiers and data objects alone?" (`dartway-feature-scaffold`).
- An action handed **downwards** as a callback instead of being written with `dw.action` in the widget
  that owns the button; a screen-wide `busy` flag duplicating `DwActionBuilder`.
- Several requests of related types stitched together by id in the widget — the data object should
  arrive with what the screen shows, built by the server.
- Naming shorter than 2 words; the forbidden `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x`.
- Specials: `SnackBar`/`ScaffoldMessenger` instead of `dw.notify.*`; raw
  `Color`/`TextStyle`/`BorderRadius`/`context.theme` in features instead of the UI kit
  (`dartway-ui-kit`); `router.go()`/string routes instead of enum routes and context extensions
  (`dartway-navigation`); a `ProviderScope` written by the app; a user-visible string not from the
  app's localizations.
- Feature isolation: importing a non-entry-point file of another feature.
- A feature's entry-point widget without `implements DwFeatureWidget` / `DwFeatureSpec` — the feature exists
  in the code but says nothing about itself.
- **Ran into a "this is wrong here" during the audit — that is a line in that feature's `knownIssues`,
  not in the report and not in your head.** A setting nobody reads; a screen on placeholder data; a
  sort commented out while the field is still live. The audit is the only moment when this is
  visible, and `knownIssues` is the only place where it survives until it is dealt with. Fixed it
  within this same task — delete the line.
- Part 2 everywhere: SRP/God objects, DRY (copy-pasted widgets/mappings), KISS/YAGNI, the Law of
  Demeter (`a.b.c.d`), SoC, tell-don't-ask, magic numbers/strings, a single source of truth, swallowed
  errors.

### A.3 Checking the description (it lives in the code)

There are no separate docs per feature — the description sits where the code sits, so there is nothing
to look for: it is **in the same diff**.

- **A file inside a feature changed** — open the feature's public file and reconcile `DwFeatureSpec`
  with the new behaviour. A new observable action — an item in `behaviors`; an existing one changed —
  fix the wording. **An outdated spec is worse than a missing one:** error reports, Studio and the next
  agent read it and believe it.
- **A server rule changed** — reconcile the doc comments where the rule is enforced: above the handler
  (who may call it, what it refuses and why, what it publishes and to whom), above the access rule,
  the channel rule, the upload rule, the job. A rule that cannot be read off the code ("why this
  filter is exactly like this") gets a comment there.
- **The contract changed** — reconcile the doc comments above the DTOs, their fields, the refusal codes
  and the channel kinds: what a field means, its invariants, which channel a request listens on and
  why. Both sides of the stack read this meaning; it is written once, here.
- A new feature without a `DwFeatureSpec` is not finished. `dartway check` emits `featureSpecMissing`.
- Tempted to write a document about what you just did — don't. If the urge is about one feature, the
  description did not fit into the spec, and the question is why the spec does not answer it. If it is
  cross-cutting (an analytics event registry, a settings catalogue, a role matrix), it belongs in code —
  an enum or constants with doc comments, where the compiler and the checker see it.
- Check whether statements in `CLAUDE.md` (root) or in the skills have drifted apart from the changed
  code, in both directions. A managed file cannot be fixed here — that is a framework finding (A.6).

### A.3a Edits the analyzer does not catch

Check separately, by eye, the things that only break at runtime:

- **Sizing mechanics.** You replaced a `SizedBox`/`Padding` with an `Expanded` (or the other way round)
  — walk **every caller**: `Expanded` requires a flex parent, and the widget may have been put into a
  bottom sheet, a `SingleChildScrollView` or a dialog, where there is none. `dart analyze` stays quiet;
  it crashes for the user.
- **An explicit colour instead of a theme colour.** `WidgetStateProperty.all(color)` paints **all**
  states, including `disabled`: when adding or removing such a parameter, check how the widget looks
  disabled and while the action is running.
- **Provider family keys.** A family keyed by an object compared by identity silently creates a new
  provider on every build. `dw.request(...)` and friends are keyed by the request's generated equality;
  a hand-written family needs a record or a class with `==` and `hashCode`.
- **A request or command added to the contract without a handler.** It compiles on both sides; the
  server refuses to start. `dartway test` catches it, and so does starting the server — make sure one
  of them ran (A.5).

### A.3b Tests are part of the refactoring surface

Tests reference the code **by path and by name**, and often reference internals (`logic/`, `widgets/`)
— which is legitimate for a unit test. So any of these edits breaks `test/`, and analyzing `lib` will
not show it:

- **you moved or renamed a file** — the imports in the tests lead nowhere;
- **a free function became a method of a class or an extension** — the call no longer compiles;
- **you removed a parameter from a widget's public API** — the test passes something that no longer
  exists, or fails to pass something that became required;
- **you renamed a DTO, a field or a refusal code** — the contract test, the fake server's handlers and
  the acceptance tests all name it.

**The rule:** do bulk import edits from an explicit "old path → new path" map. A regex with a fallback
that "just in case" substitutes something when it does not match will silently rewrite half the project
— one such run cost 64 broken files and a restore from `git show`.

**A public entity moved into the kit and became private** — do not throw its test away: the same
behaviour is verified through the public kit widget.

### A.4 Checking the tests

- Non-trivial logic, money, a rule, a bugfix **without a test** → flag it (`dartway-clean-code` Part 3).
  We do not demand tests for cosmetics.
- **Ask whether the test sits where the behaviour lives** (`dartway-testing`). The common miss is not an
  absent test but a misplaced one: an access rule "covered" by a widget test that only proves the
  button is hidden — the hidden button is not the rule, and the rule is what breaks. That belongs in a
  server acceptance test; a `matches` or a `validate()` belongs in the contract test; the widget test
  covers that the button sends the right command.
- A new DTO without a line in the contract's round-trip test.
- A widget test that does not end asserting the fake server met no errors.
- **Do not ask for a coverage number and do not report one.**

### A.5 The checks — run them, do not assume them

In this order; each answers a question the next cannot. Report each as run and its result, or as not
run and why.

```bash
dartway generate --check                                   # generated code matches its sources
(cd __SERVER_PKG__ && dart run bin/migrate.dart check)      # when row classes or migrations changed; needs DW_DATABASE_*
(cd __SHARED_PKG__ && dart analyze && dart test)            # the contract
(cd __SERVER_PKG__ && dart analyze)
(cd __FLUTTER_PKG__ && flutter analyze && dart run custom_lint)
dartway test                                                # server acceptance, real Postgres and MinIO
(cd __FLUTTER_PKG__ && flutter test)                        # screens on the in-memory server
dartway check                                               # the conventions; errors fail it
```

- **`dartway generate --check` first.** Everything after it compiles against generated code; a stale
  part makes the rest answer questions about a tree that does not exist.
- **Analyze whole packages, without a path argument.** `dart analyze lib` skips `test/` — where moves and
  API changes settle. A green `dart analyze lib` with 59 compilation errors in `test/` actually happened.
- **`dart run custom_lint` in the Flutter package is mandatory.** `flutter analyze` does NOT run its
  rules, and `dartway_lints` is what catches raw styles outside the kit and a `ProviderScope` written
  by the app. A green `flutter analyze` with a red `custom_lint` is a classic trap.
- **`dartway test` and `flutter test` actually run, not "the tests probably weren't touched".** The
  analyzer proves the code compiles and says nothing about behaviour. A test failing after a refactor
  starts with the hypothesis "I broke it", and only after checking against the base branch becomes "it
  was red before me".
- **`dartway check`**: errors are law and fail it; look at the features the task touched in its per-feature
  report, not just the counter. **It runs `migrationsDrift` only with `DW_DATABASE_*` set** — when it
  prints that migrations were not checked, it has not passed them; run `migrate check` yourself.
- **A `frameworkRefsDiverged` warning is worth acting on even when the task did not cause it** — the
  framework's packages locked to different commits. Do it as its own change (`dartway-update`), not
  folded into the task's diff.
- **A migration in the diff is read, not counted.** For every migration file the diff adds, read `up`
  and `down` whole. Every `dropTable` / `dropColumn` / `DROP` is a stop until it is confirmed that the
  table or column was removed and not renamed — a rename accepted as drop + add empties the column on
  every row, and the file looks ordinary. Every `backfill:` is a data decision: check the expression is
  what existing rows should hold. A migration file that **existed on the base branch and is modified**
  in the diff is a stop, not a note: an applied migration is never edited (`dartway-migrations`).

### A.6 Findings that outlive this task

Some of what you noticed is not about this diff at all, and it dies in the chat unless it is placed.
Every finding has exactly one home — take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed in this task | fix it — no entry anywhere |
| belongs to one feature | that feature's `knownIssues`, proposed in Phase B |
| is about the **framework**: a rule that does not exist or is too vague to have prevented the mistake, two skills that disagree, an API that forced a workaround | an issue in the framework tracker |
| is a nuance, problem or technical risk of **this project** that does not fit the task and is not confined to one feature | a file under `docs/dev_notes/` |

The framework row leaves this project entirely because the managed files cannot be fixed here — they
are overwritten on update (see `.claude/CLAUDE.md`). The project row stays, tracked and committed, so it
travels out in this pull request like anything else in the diff.

- **A framework finding is offered for filing now**, with the issue text written out: the example from
  the code restated so it stands without it, in English, and the `impact:` label proposed with the text
  — what the finding cost this project is known now and not afterwards. Search the tracker first; a gap
  another project has already filed gets a comment, not a second issue. The full rules are in
  `.claude/CLAUDE.md`, "Notes back to the framework". **This is a proposal like every other one here,
  never a push that happens on its own** — an issue is public from the moment it exists, so it waits for
  a yes. Where the tracker is `none` the finding goes to `docs/dev_notes/` instead, without an issue line.
- **A project finding is written down now** as `docs/dev_notes/<slug>.md`: where, what is wrong, what we
  did about it, and the issue it references. An option may be named, not written up.
- **Then list what the diff added or should add** — new entries under `docs/dev_notes/`, issues filed or
  offered — one line each in the report. A reminder, not a gate.
- **An entry whose issue has closed is deleted**, and the workaround it stood for is re-checked.
  `gh issue view` answers that; the file does not, and is not asked to — it carries no status.
- **A workaround over a `dartway_*` API is written down twice** — the entry under `docs/dev_notes/`, and a
  `TODO(dartway, checked: <version>)` marker on the code itself. The entry says what this project is
  carrying and links the issue that will end it; the marker says what to re-check here once that issue
  closes. Wrote the entry and left the code bare — add the marker now.

### A.7 Workarounds whose framework has moved

A marker records the framework version its workaround was last confirmed against. This step compares
that version with the one the project actually resolves, and **stays silent unless they differ**.

The conditionality is the point. "Re-verify every workaround before every commit" is expensive, which
means it gets skipped, which means it is not a check at all — while a workaround's answer can only have
changed when the framework under it changed. Ask then, and the question is worth reading.

1. **Collect** the `TODO(dartway, checked: X)` markers in the files this diff touches. Not project-wide:
   the whole-project sweep belongs to `/dartway-checkup`.
2. **Resolve** the version the project is actually on, from the `pubspec.lock` of the package the marked
   file belongs to: `version` for a hosted dependency, `resolved-ref` for a git one (`source: git`). Take
   the entry of the `dartway_*` package the workaround sits on top of. The core family
   (`dartway_core_*` and the packages released with it) moves in lockstep, so any of its entries answers
   for all of them; a satellite (`dartway_router`, `dartway_lints`, `dartway_shared_preferences`, …) moves
   on its own, and the wrong entry answers a different question.
3. **Compare.** Equal — say nothing at all, not even "checked, still current". Different — one line in the
   report (Phase B, item 7).

Compare git refs by prefix: the lock holds all 40 characters and a marker usually holds seven. A
`version` comparison is exact.

**What that line asks for is a decision, not an edit.** Three outcomes, and only the first is a one-token
change:

- the workaround is still needed → refresh `checked:` to the resolved version;
- the framework now does this → delete the workaround, the `docs/dev_notes/` entry that stood for it, and
  comment on the issue if it is still open;
- the framework now does this **differently** → the case the whole mechanism exists for. A workaround that
  duplicates the framework only wastes code; one that contradicts it breaks the app, in exactly the edge
  case the framework had thought about — throwing where the framework degrades softly, failing closed
  where it fails open. Read what actually changed upstream before choosing.

---

## Phase B — Suggestions (show, do not apply)

Produce a structured report in the chat:

1. **🔴 Critical** — contract/architecture violations that hide bugs: an access rule wider than intended,
   a write in a request, a command that publishes nothing its readers listen to, a file id not checked,
   a destructive or edited migration, swallowed errors, broken feature isolation. `file:line` + how to fix.
2. **🟡 Major** — serious violations of principles (SRP, DRY, SoC, long files, per-row queries).
3. **🟢 Minor** — naming, magic numbers, small stuff.
4. **📄 Description** — which `DwFeatureSpec`s and doc comments (handlers, rules, DTOs) are outdated,
   **with a concrete proposed diff**.
5. **🧪 Tests and checks** — which non-trivial parts are uncovered or tested in the wrong place; which of
   the A.5 checks ran and their results, which did not run and why.
6. **📓 Findings that outlive the task** — one line each. Framework findings: what it is and where in the
   monorepo it lands, plus the issue text ready to file and the `impact:` label proposed with it. Project
   findings: what this project is carrying, and the `docs/dev_notes/` entry proposed for it. Plus any
   existing entry whose issue has closed.
7. **🔖 Workarounds** — only the markers A.7 found diverged, one line each: `file:line`, what is worked
   around, `checked:` versus the resolved version. **Omit the whole item when nothing diverged** — a
   report that prints it every time teaches the reader to skip it. Mark it for the author to decide.

For every item give a **concrete proposed edit**, ready to apply. Mark anything debatable/architectural as
"for the author to decide" — do not propose an automatic fix.

---

## Phase C — Application (only on confirmation)

- Ask what to apply. Support batches: "apply the descriptions", "apply Minor", "apply everything except
  the architectural items", or item by item by number.
- Apply **only what was confirmed**. Nothing silently.
- **Format the files in the diff, not the package.** `dart format lib test` rewrites line breaks in
  files the task never touched, and the diff stops answering "what did this change":
  `git diff --name-only origin/__BASE_BRANCH__...HEAD -- '*.dart' | xargs dart format`. A package that
  really needs formatting is its own commit.
- After applying, re-run the checks the edits touch (a DTO edit → `dartway generate --check` and the
  contract test; a handler → `dartway test`; a widget → `flutter test` and `dartway check`).
- Do not touch anything debatable/architectural, even if the author said "all of it" — ask again about
  such items separately.
- At the end — a short summary: what was applied, what is left to the author, which checks are green.

---

## How this differs from `/dartway-checkup`

| | `dartway-finish` (skill) | `/dartway-checkup` (command) |
|---|---|---|
| Scope | the diff of one task vs the base branch | the whole project by default — packages, CI, configs, pins — narrowed by an argument |
| Extra checks | description sync + tests + checks run + application | the gates actually running, the distance to the framework, a rolling deep pass over features |
| Output | report + edits on confirmation | report in the chat + findings placed in `knownIssues` / `docs/dev_notes/` / the tracker |
| When | finishing a task, before a PR | on demand, and periodically — its findings change without a commit here |

The detectors are shared (their source is `dartway-clean-code` and the layer skills). Do not duplicate
the logic — reference the contract.
