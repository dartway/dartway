---
name: dartway-requirements
description: >-
  Requirements analysis BEFORE starting a DartWay task (DartWay projects): the developer gives a spec —
  the skill studies in depth what the project already has on the topic (models, CRUD configs, features, docs),
  identifies refactoring and code-quality opportunities in the affected feature per the
  dartway-clean-code contract (blocking debt vs adjacent debt), assembles a pool of clarifying questions and
  proposes 2–3 implementation options along the 3-level DartWay ladder (Event models →
  CRUD configuration → custom endpoint) with constraints, tradeoffs, risks and a rough time
  estimate. Read-only: writes nothing, only a report. Run as /dartway-requirements at the
  start of work on a feature/task — before planning and code.
---

# DartWay — requirements analysis (`dartway-requirements`)

The first step of a DartWay task: turn a raw spec into a clear, justified set of decisions. The skill is **read-only** — it studies the project and produces a report (what exists + questions + options), **does not touch the code** and does not write a plan (that is the next step — `dartway-plan`).

## ⛔ Principle

Do not propose a solution before you understand **what the project already has**. DartWay is domain-first and CRUD-first: almost everything is done through models and CRUD configs, not new endpoints (laws 1, 2, 4). Reuse what exists, do not breed duplicates. The solution must reflect domain reality, not the momentary UI.

## Phase A — Parsing the spec

Parse the requirement: what user/business goal, what scope, which entities and actions are mentioned. Extract the **implicit assumptions and gaps** — what the spec does not say but what will have to be decided. Do not fill them in silently — this is material for the questions (Phase D).

## Phase B — Codebase analysis (read-only)

Find everything already related to the topic (Glob/Grep/Read; for broad coverage — Explore subagents):

- **Models** — are there suitable `.spy.yaml` files (fields, relations, enums): what to reuse, what to extend, what is missing. Domain-first (`dartway-models`).
- **CRUD/logic** — existing `DwCrudConfig`, permissions (`allowSave`/`allowDelete`), validations, side effects (`dartway-crud-config`).
- **Features** — nearby features in Flutter (entry point, flow), what is reusable; remember feature isolation.
- **Current behaviour** — read the `DwFeatureSpec` of the affected features (in their public files) and the `knownIssues` there: what is already acknowledged as wrong is most likely the subject of the task. Architecture and cross-cutting conventions — `docs/1_general/*`.

Reduce it to three lists: **what already exists → what is missing → what gets in the way** (constraints of the current schema/permissions/architecture).

Along the way, while reading the code of **the entire affected feature** (not just the lines of the future diff), record quality signals — violations of the `dartway-clean-code` contract and layer antipatterns. This is material for Phase C; do not draw conclusions here.

## Phase C — Refactoring and quality opportunities

Since the area has already been studied in Phase B — assess what in it is worth improving per the project's methodology, while the work has not started yet.

- **Coverage** — the whole affected feature/module (including the parts the task does not edit directly), not just the future diff.
- **Source of rules** — the `dartway-clean-code` contract (Part 1 — the team's hard rules; Part 2 — SOLID/KISS/DRY/YAGNI and the rest) and the layer skills (`dartway-models`, `dartway-crud-config`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit`). Do **not** duplicate the detectors — check against the contract.

Split the findings into two groups:

- 🔧 **Blocking debt** — existing code that **gets in the way of or complicates the new work**: a god object you will have to extend; a direct field update (e.g. `balance`) instead of an Event model in money logic the feature will touch; a missing abstraction/extension; a broken feature isolation on the integration path. Such debt **must be accounted for** in the scope, risks and estimate of the corresponding option (Phase E).
- 🧹 **Adjacent debt** — contract violations **near** the work area, which can be tidied up along the way (boy-scout rule) but which do not block the task. Optional, **the author's call**.

**Discipline:** read-only, no auto-fixes; do not inflate this into a full repository audit (that is the job of `/dartway-audit`); every finding comes with a `file:line` and a short "why this is debt".

**Boundary:** `dartway-finish` audits the finished **diff** before a PR, `/dartway-audit` audits a **module on request**; here it is a look **forward** at the area before the work starts, so that the chosen approach accounts for the existing debt.

## Phase D — Pool of clarifying questions

Only the **genuinely blocking** questions (not the ones derivable from the code or from a reasonable default). Group them:

- **Domain/model** — which entities, fields, relations, states.
- **Permissions and roles** — who can do what (affects `allowSave`/`allowDelete`/access filters).
- **Flow/UX** — the steps, the edge cases and the empty/error states.
- **Data/migrations** — what happens to existing data, backward compatibility.
- **Non-functional** — volumes, real-time, offline, performance.

For each question propose a reasonable **default** (your recommendation), so that agreement goes fast.

## Phase E — Implementation options

Give **2–3 options** along the 3-level ladder of increasing complexity (law 4): Event models → CRUD configuration → custom endpoint (the last one only as an exception, with justification). For each:

- **Essence** — how it works in DartWay terms (which models, configs, features).
- **What it touches** — models/migrations, CRUD configs, Flutter features.
- **Constraints and tradeoffs** — what is impossible/awkward, what it affects.
- **Risks** — migrations, permissions, races (money/counters → Event models), feature isolation.
- **Blocking debt** — which refactoring from Phase C the option drags along (if the chosen approach requires cleaning up first — reflect that in the scope).
- **Time estimate** — a rough range (S/M/L or hours-days) accounting for the blocking debt and with the caveat that it depends on the answers to the questions.

Finish with a **recommendation** — which option and why.

## Output format

A report in the chat, in the user's language, changing nothing:

1. **What the project already has** on the topic and **what is missing / what gets in the way**.
2. **Refactoring opportunities** — 🔧 blocking debt (to be accounted for in the plan) and 🧹 adjacent debt (the author's call), with `file:line`.
3. **Clarifying questions** — grouped, with defaults.
4. **Implementation options** — with constraints/risks/estimate + a recommendation.

Next, once the requirements are agreed and an option is chosen → **`dartway-plan`** (a detailed step-by-step plan).
