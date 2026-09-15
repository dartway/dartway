---
name: dartway-requirements
description: >-
  Requirements analysis BEFORE starting a DartWay task (DartWay projects): the developer gives a spec
  — the skill studies in depth what the project already has on the topic (data objects, requests and
  commands in the contract, row classes, handlers with their access and channel rules, features and
  their specs), identifies refactoring and code-quality opportunities in the affected feature per the
  dartway-clean-code contract (blocking debt vs adjacent debt), assembles a pool of clarifying
  questions and proposes 2–3 implementation options along the DartWay ladder (reuse what the contract
  already has → extend the contract with a request or a command and its handler → a job or a door,
  only where a call cannot express it) with constraints, tradeoffs, risks and a rough time estimate.
  Read-only: writes nothing, only a report. Run as /dartway-requirements at the start of work on a
  feature/task — before planning and code.
---

# DartWay — requirements analysis (`dartway-requirements`)

The first step of a DartWay task: turn a raw spec into a clear, justified set of decisions. The skill is
**read-only** — it studies the project and produces a report (what exists + questions + options), **does
not touch the code** and does not write a plan (that is the next step — `dartway-plan`).

## ⛔ Principle

Do not propose a solution before you understand **what the project already has**. DartWay is domain-first
and contract-first: everything the app and the server say to each other is a data object, a request or a
command in the shared contract, answered by a handler with an access rule and kept live through channels.
Reuse what exists, do not breed duplicates. The solution must reflect domain reality, not the momentary
UI.

## Phase A — Parsing the spec

Parse the requirement: what user/business goal, what scope, which entities and actions are mentioned.
Extract the **implicit assumptions and gaps** — what the spec does not say but what will have to be
decided. Do not fill them in silently — this is material for the questions (Phase D).

## Phase B — Codebase analysis (read-only)

Find everything already related to the topic (Glob/Grep/Read; for broad coverage — Explore subagents):

- **The contract** (`__SHARED_PKG__`) — data objects that already describe the entity (fields, what is
  nullable and why), requests that read it (their kind, `matches`, channels), commands that change it,
  refusal codes, channel kinds, upload purposes. What to reuse, what to extend, what is missing
  (`dartway-contract`).
- **The server** (`__SERVER_PKG__`) — row classes and their relations, the handlers answering those DTOs,
  their access rules, what each command publishes, channel rules, jobs, routes (`dartway-server`,
  `dartway-access`, `dartway-realtime`).
- **Features** — nearby features in the app (entry point, flow), what is reusable; remember feature
  isolation.
- **Current behaviour** — read the `DwFeatureSpec` of the affected features (in their public files) and
  the `knownIssues` there: what is already acknowledged as wrong is most likely the subject of the task.
  Server rules are in the doc comments above handlers and rules; contract meaning above the DTOs;
  cross-cutting conventions in the registries and enums of `lib/core/`.

Reduce it to three lists: **what already exists → what is missing → what gets in the way** (constraints of
the current contract, schema, access rules, architecture).

Along the way, while reading the code of **the entire affected feature** (not just the lines of the future
diff), record quality signals — violations of the `dartway-clean-code` contract and layer antipatterns.
This is material for Phase C; do not draw conclusions here.

## Phase C — Refactoring and quality opportunities

Since the area has already been studied in Phase B — assess what in it is worth improving per the
project's methodology, while the work has not started yet.

- **Coverage** — the whole affected feature/module (including the parts the task does not edit directly),
  not just the future diff.
- **Source of rules** — the `dartway-clean-code` contract (Part 1 — the team's hard rules; Part 2 —
  SOLID/KISS/DRY/YAGNI and the rest) and the layer skills (`dartway-contract`, `dartway-server`,
  `dartway-access`, `dartway-realtime`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit`). Do
  **not** duplicate the detectors — check against the contract.

Split the findings into two groups:

- 🔧 **Blocking debt** — existing code that **gets in the way of or complicates the new work**: a god
  object you will have to extend; a balance or counter updated in place where the feature touches money;
  a request that does not listen on the channel the new command will publish to; a data object shaped for
  one screen that the new feature would have to bend; a broken feature isolation on the integration path.
  Such debt **must be accounted for** in the scope, risks and estimate of the corresponding option
  (Phase E).
- 🧹 **Adjacent debt** — contract violations **near** the work area, which can be tidied up along the way
  (boy-scout rule) but which do not block the task. Optional, **the author's call**.

**Discipline:** read-only, no auto-fixes; do not inflate this into a full repository audit (that is the
job of `/dartway-checkup`); every finding comes with a `file:line` and a short "why this is debt".

**Boundary:** `dartway-finish` audits the finished **diff** before a PR, `/dartway-checkup` audits a
**module on request**; here it is a look **forward** at the area before the work starts, so that the chosen
approach accounts for the existing debt.

## Phase D — Pool of clarifying questions

Only the **genuinely blocking** questions (not the ones derivable from the code or from a reasonable
default). Group them:

- **Domain** — which entities, fields, relations, states; what may be absent and what may not.
- **Access and roles** — who may read and change what, who sees whose data, what an anonymous visitor
  gets (affects access rules, channel rules, ownership checks).
- **Flow/UX** — the steps, the edge cases, the empty, refused and error states.
- **Live updates** — who must see a change without reloading: the author's other devices, other members,
  an admin panel.
- **Data and migrations** — what happens to existing rows, renames, values for new required fields.
- **Non-functional** — volumes (paging kind), files, background work, installed app builds that will meet
  the change.

For each question propose a reasonable **default** (your recommendation), so that agreement goes fast.

## Phase E — Implementation options

Give **2–3 options** along the ladder of increasing weight — the heavier rung only when the lighter one
cannot express the requirement:

1. **Reuse the contract** — existing requests and commands already cover it; the work is a field on a data
   object, a rule in a handler, a channel added to a request, a screen.
2. **Extend the contract** — a new data object, request or command with its handler, access rule and
   publications. The normal shape of a new feature.
3. **Outside a call** — a background job, a `DwRoute` door for an external caller — only with
   the reason a request or a command cannot carry it.

For each option:

- **Essence** — how it works in DartWay terms (which DTOs, rows, handlers, channels, features).
- **What it touches** — contract, rows and migrations, handlers and rules, app features.
- **Constraints and tradeoffs** — what is impossible/awkward, what it affects.
- **Risks** — migrations over existing data, access, races (money/counters → row locks or event rows),
  live updates that do not reach a screen, installed app builds, feature isolation.
- **Blocking debt** — which refactoring from Phase C the option drags along (if the chosen approach
  requires cleaning up first — reflect that in the scope).
- **Time estimate** — a rough range (S/M/L or hours-days) accounting for the blocking debt and with the
  caveat that it depends on the answers to the questions.

Finish with a **recommendation** — which option and why.

## Output format

A report in the chat, in the user's language, changing nothing:

1. **What the project already has** on the topic and **what is missing / what gets in the way**.
2. **Refactoring opportunities** — 🔧 blocking debt (to be accounted for in the plan) and 🧹 adjacent debt
   (the author's call), with `file:line`.
3. **Clarifying questions** — grouped, with defaults.
4. **Implementation options** — with constraints/risks/estimate + a recommendation.

Next, once the requirements are agreed and an option is chosen → **`dartway-plan`** (a detailed
step-by-step plan).
