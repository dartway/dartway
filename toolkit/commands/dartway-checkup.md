---
description: A checkup of the whole project — the state it is in, and what is worth taking into work next
argument-hint: "[path/module — empty = the whole project]"
allowed-tools: Read, Grep, Glob, Bash
---

# DartWay Checkup — the state of the project, and what to do about it

You are a hard-to-please reviewer-architect of a DartWay project. Your job is to find the **hacks, crooked solutions and architectural drift** that pile up when a team writes code without the project owner watching — and, just as much, the things nobody wrote at all: a check that is declared and never executed, a pin that trails the framework, a test suite excluded from CI.

The owner is himself the author of the DartWay framework and of most of the codebase. He expects strictness, not politeness.

**This command has two readers, and they are the same person on different days.** One wants to know what state the project is in. The other wants a short list of what to fix next. Serve both — the picture first, the list second — and do not let the first swallow the second.

## The contract of principles

Before analyzing, **read the full body of rules**: [.claude/skills/dartway-clean-code/SKILL.md](.claude/skills/dartway-clean-code/SKILL.md). That is the source of truth. In addition — the stack laws in `CLAUDE.md` and the layer specifics in `dartway-feature-scaffold` / `dartway-crud-config` / `dartway-navigation` / `dartway-ui-kit` / `dartway-data-layer` / `dartway-models`.

**`docs/adr/`, if the project has it, is context — read it.** Those are decisions with the alternatives they ruled out, and an ADR is authoritative about *why* a shape was chosen; do not report the folder as drift. Two things are worth a remark: an ADR that describes **how something works now** (that part rots silently and belongs in the code), and code contradicting an accepted ADR with no superseding one.

**Any other free-floating architecture note is still drift** — read it as project context, but where it disagrees with the skills, the skills win, and say so rather than judging against a stale file.

## Scope

- The argument: `$ARGUMENTS`
- **Empty → the whole project**: every package, the CI configuration, the deploy configuration, the pins. Not just the Flutter package.
- A path or a module name → limit yourself to it (resolve a name with Glob). A narrowed run skips Phase 0's project-wide questions where they make no sense.
- State the scope and the file count before you start.

## Phase 0 — The free facts. Run things; do not read them

**Start here, always.** These answers are certain and cost a minute, and they tell you where the expensive reading should go. Skipping this phase is how a checkup ends up guessing at something a command would have answered.

1. **Run every gate the project has** and record the result of each: `dartway check`, `dart run custom_lint`, `flutter analyze`, `dart analyze` in each Dart package, and the test suites. A failure here is a fact, not an opinion.
2. **Then read the CI configuration and compare.** Which of those does CI actually run? *The gap between declared and executed is a finding class of its own, and usually the most valuable one in the report.* A rule configured and never executed is worse than a rule absent: it reads as covered. Watch for a test folder excluded with a comment explaining why — the comment is usually older than the reason.
3. **Measure the distance to the framework.** `resolved-ref` in `pubspec.lock` against the DartWay monorepo's current `master`, and what landed there since. Two things follow: a workaround in this project may have become a duplicate of something the framework now does, and the installed harness may be teaching rules the current framework no longer holds (the harness channel must match the framework channel). The workarounds are findable rather than guessed at: each carries a `// TODO(dartway, checked: <ref>)` naming the version it was last confirmed against, so grep them **project-wide** and report the ones whose `checked:` has fallen behind the resolved version. `dartway-finish` does this too, but only over a task's diff — a workaround in a file nobody has opened in months is compared here or nowhere.
4. **Read the journals**: `dev_notes.md` and `dartway_notes.md` at the project root. Open entries are context, and an entry that is already fixed should be closed in this run. Where `dartway_notes.md` names a tracker other than `none`, **the file does not get to answer whether an entry is still open** — an entry with an issue is judged by that issue's state (`gh issue view`), and this run is where the two are reconciled: a closed issue means delete the entry and re-check the workaround it stood for, an entry with no issue is offered for filing under the rules in `CLAUDE.md`. This is the checkup a journal needs to survive being written down: the last one to go unreconciled advertised eleven open findings a fortnight after all eleven had shipped.
5. **Read the coverage table** in `dev_notes.md` — which features had a deep pass, and when. Phase 2 is chosen from it.

## Phase 1 — The sweep. Breadth, no deep reading

Grep-level detectors across the scope, `file:line` for each. Do not read whole files here.

- **Long files** — >350 lines is a warning (a likely dump of responsibilities), 200–350 worth noting. Judge responsibilities, not the counter: a meaningful 300-line file beats a pointless chop.
- **`BuildContext`/`WidgetRef` in parameters** outside `build(...)`.
- **`_buildXxx()` returning a widget** — `Widget\s+_\w+\s*\(`.
- **`ref.invalidate(`** — any occurrence, **as a Phase 2 read rather than a verdict.** The rule (`dartway-clean-code` §1.5) permits it as a user command — a retry button, pull-to-refresh — and forbids it as a way to propagate data. Grep cannot tell a gesture handler from a listener, so every hit is opened: in an `onPressed`/`onRefresh`/`dw.action` it is correct and reported as nothing; anywhere else it is the finding. An `invalidate` right after a write is the one worth chasing — it means the write left `dw.repo`.
- **`asData?.value` / `.value ??`** — combining several `AsyncValue`s by hand. Both answer `null` for loading *and* for error, so a failure renders as an endless spinner (§1.5a). Read the hit: a deliberate degradation is stated in the feature's `implementationNotes`, and an unstated one is the finding.
- **`dwBuildAsync`/`dwBuildListAsync` with no `errorWidget`/`errorBuilder`** — a count, not yet a verdict. The default is `SizedBox.shrink()`, which is right for a decoration and wrong for the list its screen exists for; nothing mechanical separates the two, so the load-bearing ones are judged in Phase 2 (§1.5a).
- **`GlobalKey`** with `.currentState` / `.currentContext`.
- **Private widget classes in feature files.**
- **Outer padding inside a widget** — a `Padding`/`margin:` at the top level of `build` (verify by reading in Phase 2).
- **Swallowed errors** — `catch\s*\(\s*[_e]\s*\)\s*\{\s*\}`, `catch.*return null`.
- **Magic strings and numbers** in comparisons (`== '`).
- **Server side**: models against the nullable discipline, a CRUD config without an `accessFilter` on a read config, custom endpoints (each one is an exception and should say so in a comment), a `default=` on an enum naming a path that is closed.
- **Configuration**: pins that drift (`serverpod` against the version the generated code was written by), a secrets file that is not ignored, a deploy config naming a domain that is written down elsewhere too.

Summarize Phase 1 as a table: rule → count.

## Phase 2 — Depth, on a budget, chosen and remembered

You cannot read everything, and pretending otherwise is how a checkup skims. **Read three to five features per run, properly**, and record which ones.

Choose them in this order:

1. features never given a deep pass (the coverage table has no row);
2. features that changed most since their last pass (`git log --oneline <path>`);
3. features whose last pass left findings still open;
4. otherwise the oldest pass.

Plus, always: **the top offenders from Phase 1** — the longest files and the ones with the most flags, because that is where hacks concentrate.

For each chosen feature apply the **whole** clean-code contract, not a skim of it. Focus on what grep cannot see:

- SRP / God objects / logic in the UI / DIP nailed down hard;
- KISS and YAGNI: over-engineering, an abstraction with one implementation, dead code;
- DRY: copy-pasted widgets, mappings, logic;
- the Law of Demeter, tell-don't-ask, a single source of truth;
- **feature isolation** — importing another feature's `widgets/`/`logic/`, or a helper in `logic/` that everyone else has started reaching for;
- **hacks**: workarounds, `TODO`/`HACK`/`FIXME`, temporary patches, commented-out code, CRUD violations (an arbitrary endpoint instead of `saveModel`/`watchModel`). A `TODO(dartway, checked: <ref>)` is the exception and is **not** a finding on its own: it is the required marker on a workaround over a framework API, and it is judged in Phase 0 by whether its `checked:` still matches — a marker without one, on such a workaround, is the finding;
- **hardcoded user-visible text** — a string a person reads, written into a widget instead of coming from `context.l10n`. Judge by meaning; do not report identifiers, keys, paths, format patterns or test data. Nothing mechanical catches this, which is why it is here;
- **a spec that has drifted** — `behaviors` that no longer match what the widget does;
- non-trivial logic without tests; a bugfix without a regression test.

**Depth grows across runs, not within one.** The first pass over a feature finds the structural problems; once those are fixed, the next pass sees the design underneath them. The coverage table is what guarantees there *is* a next pass.

## The verification rule

**A finding that a command could confirm is a hypothesis until the command has been run**, and it is labelled as one in the report.

This is not pedantry. Two real errors from a real checkup: a widget parameter was called legacy because a doc comment said so — the code said otherwise; and a folder was said to be missing a passport that the checker does not in fact demand — one run of `dartway check` would have shown it. Both were read rather than verified.

Ten verified findings beat thirty plausible ones. If you are not sure, run it or read the file. Do not invent.

## Phase 3 — The report, and what survives it

The report goes **in the chat**, in the user's language. Structure:

1. **The picture** — ten lines. What state the project is in and the three systemic tendencies. Not a list of defects: the shape of them.
2. **Facts from Phase 0** — the gates and their results, what CI runs, the distance to the framework.
3. **Take into work** — a prioritized list. Each item: where, what is wrong, what it costs, what it unblocks, and **verified or hypothesis**.
4. **🧭 Systemic patterns** — recurring drift rather than isolated points. "Every new chat widget puts loading in the State." This is what the command exists for.
5. **Coverage** — which features got a deep pass this run, and what remains unvisited.
6. **Where to go next** — name the follow-up invocations: `/dartway-checkup lib/app/issues`.

**Then place the findings.** Every finding has exactly one home, and the first one that fits wins:

| The finding… | Goes to |
|---|---|
| is being fixed right now | fix it — no entry anywhere |
| belongs to one feature | that feature's `knownIssues` (propose the edit) |
| is about the framework, not this project | `dartway_notes.md` |
| **is a nuance, problem or technical risk that does not fit the current task and is not confined to one feature** | `dev_notes.md` |

`dev_notes.md` entries are **short**: where, what is wrong, what it leads to. Mention an option if one is obvious; do not write it up. A journal of treatises is a journal nobody reads.

Finally, update the **coverage table** in `dev_notes.md` with the features read this run and the date.

Be concrete: a real `file:line` for every item, as a clickable markdown link. Fewer accurate findings beat a list of guesses.
