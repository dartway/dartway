---
description: A checkup of the whole project — the state it is in, and what is worth taking into work next
argument-hint: "[path/module — empty = the whole project]"
allowed-tools: Read, Grep, Glob, Bash
---

# DartWay Checkup — the state of the project, and what to do about it

A strict reviewer's pass over the project: the drift that piles up unwatched, and what nobody wrote
at all — a gate declared and never run, a pin trailing the framework. The picture first, then a short
list of what to fix next.

**Scope:** `$ARGUMENTS`. Empty → the whole project: the three packages, CI, `deploy/`, the pins. A
path or a module name narrows it (resolve a name with Glob). State the scope and the file count first.

**Do not read the whole toolkit.** The machine answers first; then read only the skills the findings
point at — each law-table row in `.claude/CLAUDE.md` names its skill, and `dartway-finish` holds the
code-shape rules no layer skill owns.

## Phase 0 — the facts a command answers

1. **Run every gate** in `dartway-finish` (A.2) and record each result. `migrationsDrift` without a
   database is "not run", never a pass.
2. **Compare with CI.** Which of those does CI actually run? A gate configured and never executed reads
   as covered — the most valuable finding class. Watch for excluded test folders.
3. **The distance to the framework.** The `dartway_*` versions in each `pubspec.lock` against the
   channel in `.claude/dartway-toolkit.json`; `frameworkRefsDiverged`, `frameworkOverrideOutlived`.
   Do not run `dartway update` here — that is `dartway-update`. Grep every
   `TODO(dartway, checked: …)` project-wide and report the ones whose `checked:` trails the resolved
   version (`dartway-finish` A.5 decides each). A marker is not a finding by itself; a workaround over
   a `dartway_*` API without one is.
4. **`docs/dev_notes/`**: each entry's issue state decides (`gh issue view`); a closed issue means
   delete the entry and re-check its workaround. An entry with no issue on a project with a tracker is
   a finding nobody filed — offer to file it.
5. **`docs/dev_notes/_coverage.md`** — which features had a deep pass, and when.
6. **`docs/adr/`**, if present, is context and authoritative about why; an ADR describing how something
   works now, or code contradicting an accepted ADR, is a finding. Any other architecture note is
   context too, and where it disagrees with the skills, the skills win — say so.

## Phase 1 — the sweep

`dart run dartway_cli:dartway check` is the sweep for everything in the law table and its warnings:
group its findings by check and by feature. Then grep only what it cannot see — the code-shape list in
`dartway-finish` (A.3), plus:

- `.refetch()` / `ref.invalidate(` — every hit read in Phase 2 (`dartway-data-layer`, "Refreshing");
- a provider of the project's own returning a read whole, then taken apart in a widget — the check does
  not see it (`dartway-data-layer` §2);
- `asData?.value`, `.value ??` in `logic/` — a failure rendered as an endless spinner;
- `DwAccessRule.anonymous` — each one a decision its handler's doc comment explains; a
  `DwAccessRule.check` reading an id from the call without asking whose it is (`dartway-access` §3);
- a caller's mistake answered with `throw` instead of `ctx.refuse`; a command that publishes nothing;
  a refusal code nothing on the server raises;
- a deployment-owned value with a default (`dartway-server` §9);
- `deploy/secrets.yaml` tracked by git; one `dartway_*` package behind its siblings; a deploy domain
  written in more than one place.

Summarise as a table: rule → count.

## Phase 2 — depth, three to five features per run

Choose in this order: never passed (no coverage row) → changed most since their pass
(`git log --oneline <path>`) → open findings from the last pass → the oldest pass. Plus the top
offenders of Phase 1.

For each, load the skills of the layers it spans and read it against them, with what grep cannot see:
responsibilities, duplication, over-engineering, feature isolation, hacks and commented-out code, a
second way across the contract, hardcoded user-visible text (judge by meaning), a `DwFeatureSpec`
that no longer matches the widget, logic without tests, a bugfix without a regression test.

**A finding a command could confirm is a hypothesis until the command ran**, and is labelled so. Ten
verified findings beat thirty plausible ones.

## Phase 3 — the report, in the chat, in the user's language

1. **The picture** — ten lines: the state and the three systemic tendencies.
2. **Facts from Phase 0** — gates, what CI runs, the distance to the framework.
3. **Take into work** — prioritised; each: where (a clickable `file:line`), what is wrong, what it
   costs, what it unblocks, verified or hypothesis.
4. **Systemic patterns** — recurring drift, not isolated points.
5. **Coverage** — what got a deep pass, what remains; the next invocations (`/dartway-checkup lib/app/x`).

Then place every finding by `dartway-documentation` (fix now · `knownIssues` · the framework tracker ·
`docs/dev_notes/`), and update `docs/dev_notes/_coverage.md` with this run's features and the date.
