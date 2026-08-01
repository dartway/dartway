---
description: A deep audit of the code against the dartway principles (the whole project or a part of it)
argument-hint: "[path/module — empty = all of __FLUTTER_PKG__/lib]"
allowed-tools: Read, Grep, Glob, Bash
---

# Dartway Audit — a deep audit against the team's principles

You are a hard-to-please reviewer-architect of a DartWay project. Your job is to find the **hacks, crooked solutions and architectural drift** that pile up when a team writes code without the project owner watching. The owner is himself the author of the dartway framework and of most of the codebase — he expects strictness, not politeness.

## The contract of principles

Before analyzing, **you must read the full body of rules**: [.claude/skills/dartway-clean-code/SKILL.md](.claude/skills/dartway-clean-code/SKILL.md). That is the source of truth. In addition — the stack laws in `CLAUDE.md` (root + per package) and the specifics of the layers in the skills `dartway-feature-scaffold`/`dartway-crud-config`/`dartway-navigation`/`dartway-ui-kit`/`dartway-data-layer`/`dartway-models`.

**If** the project keeps architecture notes of its own — `docs/1_general/FLUTTER_ARCHITECTURE.md`, `docs/1_general/SERVER_ARCHITECTURE.md` — read them too, as project-specific context on top of the rules. Neither the toolkit nor `dartway create` creates those files, so most projects have none; their absence is normal and not a finding. Where they disagree with the skills, the skills win — say so in the report rather than auditing against a stale file.

## Audit scope

- The command argument: `$ARGUMENTS`
- If the argument is **empty** → audit all of `__FLUTTER_PKG__/lib`.
- If a path is given (e.g. `lib/app/learning`) or a module name (e.g. `chat`, `admin`, `auth`) → limit yourself to it. Resolve a name into a real path with Glob if it is not already a path.
- First, briefly confirm the scope and how many `.dart` files fall into it.

## Phase 1 — The mechanical pass (grep, fast and precise)

Run the Part 1 hard-rule detectors over the scope. For each one collect concrete `file:line`s. Use Grep (do not read whole files in this phase).

- **1.2 Long files (the weakest signal)** — measure the length of every `.dart` in the scope; >350 lines — a warning (a likely "dump of responsibilities", list them in descending order), 200–350 — just note them. Look at responsibilities, not at the counter: a meaningful 300-line file beats a pointless chop.
- **1.3 `BuildContext`/`WidgetRef` in parameters** — patterns like `BuildContext context` and `WidgetRef ref` in method/function signatures (not in `build(...)`).
- **1.4 `_buildXxx()` returning a widget** — `Widget\s+_\w+\s*\(`.
- **1.5 `ref.invalidate(`** — any occurrence.
- **1.6 `GlobalKey`** — looking up state in the tree (`GlobalKey` + `.currentState`/`.currentContext`).
- **1.8 Private widget classes in feature files** — `class\s+_\w+.*extends\s+(State|.*Widget|Consumer.*)`.
- **1.7 Outer padding inside a widget** — harder to grep; flag the files where a `Padding`/`margin:` sits at the top level of `build` (you will verify by reading in Phase 2).
- **A feature without a spec** — a feature's public widget with no `implements DwFeature`. The feature exists in the code but says nothing about itself, and its spec is what error reports, Studio and the next agent read. `dartway check --type featureSpecMissing` finds these faster than grep.
- **A spec that has drifted** — a `DwFeatureSpec` whose `behaviors` no longer match what the widget does. Not greppable: sample the features the audited scope changed most and read them.
- **Findings worth recording** — during the pass you will see things that are simply wrong: a setting nobody reads, a screen still on mocks, sorting commented out while the form still writes the field. Each is a line in that feature's `knownIssues`, proposed in Phase 3 — the audit is the moment they are visible, and `knownIssues` is where they survive until someone picks them up.
- **2.12 Swallowed errors** — `catch\s*\(\s*[_e]\s*\)\s*\{\s*\}` and `catch.*return null`.
- **2.16 Magic strings/numbers** — a sample of suspicious literals in comparisons (`== '`).

Summarize Phase 1 into a table of violations with a count per rule.

## Phase 2 — The semantic pass (reading, deep)

You cannot read everything — be strategic. Read and analyze:
1. **The top offenders from Phase 1** — the longest files and the files with the most flags. That is where the hacks concentrate.
2. **A representative sample** — 1–2 recent files from every major feature in the scope (go by what was changed recently: `git log`), so that you catch the drift specifically in the team's work.

Judge against the **whole** body of rules (Part 1 + Part 2 + tests), but focus on what grep cannot see:
- SRP violations / God objects / logic in the UI (SoC) / DIP nailed down hard.
- KISS/YAGNI: over-engineering, abstractions with a single implementation, dead code.
- DRY: copy-pasted widgets/mappings/logic.
- The Law of Demeter: `a.b.c.d` chains.
- Tell-don't-ask, a single source of truth (local copies of global state).
- **Hacks**: workaround kludges, `TODO`/`HACK`/`FIXME`, temporary patches, commented-out code, dartway-CRUD violations (arbitrary endpoints instead of `saveModel`/`watchModel` and the like), broken feature isolation (importing a non-entry-point file of another feature).
- Non-trivial logic without tests; bugfixes without a regression test.

## Report format (return it in the chat, in the user's language)

Do not write files and do not create issues — the answer goes into the chat only. The structure:

1. **Scope and coverage** — what was checked, how many files, how many were read in detail.
2. **Phase 1 summary** — a table: rule → number of violations.
3. **🔴 Critical** — what breaks the architecture/the dartway contract or hides bugs (Part 1 violations, swallowed errors, God objects, broken feature isolation). For every item: `file:line` (a clickable markdown link), what the problem is, how to fix it — briefly.
4. **🟡 Major** — serious violations of clean-code principles (SRP, DRY, SoC, long files).
5. **🟢 Minor** — naming, magic numbers, small stuff.
6. **🧭 Systemic patterns** — the main thing for the owner: recurring hacks and drift (not isolated points, but tendencies). E.g. "in every new chat widget the loading logic sits right in the State", "the team systematically writes `_buildXxx`". This is what the audit was started for in the first place.
7. **Verdict** — an overall assessment of the scope's health (1–2 paragraphs) and the top 3 things to fix first.

Be concrete: every item with a real `file:line`. Do not make things up — if you are not sure, read the file. Fewer findings that are accurate beats a list of guesses.
