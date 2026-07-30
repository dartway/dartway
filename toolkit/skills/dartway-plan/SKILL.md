---
name: dartway-plan
description: >-
  Development planning AFTER the requirements are agreed (DartWay projects): the requirements are approved
  and an implementation option is chosen — the skill analyses the codebase once more for the chosen approach and
  produces a detailed step-by-step end-to-end plan (models → migrations → CRUD configs → server-side
  logic → Flutter data layer/feature/navigation/UI Kit → tests → docs), highlights the subtleties and risks
  and gives a verification checklist for after the implementation. Read-only: produces a plan, writes no code. Run
  as /dartway-plan after /dartway-requirements, before writing code.
---

# DartWay — development planning (`dartway-plan`)

The second step of a DartWay task: turn the agreed requirement and the chosen option into a **detailed, executable plan**. The skill is **read-only**: it analyses the code and produces a plan, the subtleties, the risks and a verification checklist. **It writes no code.**

## ⛔ Principle

The plan follows the DartWay order of layers (domain-first, CRUD-first): first the models and the schema, then the configs/logic, then Flutter, then the tests and the docs. Maximum reuse of what exists; new endpoints only as a documented exception (law 4). Do not plan work "just in case" — YAGNI.

## Phase A — Context

Record: the agreed requirement + the **chosen implementation option** (from `dartway-requirements`). If no option is chosen or the requirements are not agreed — stop and send it back to `dartway-requirements`.

## Phase B — Re-analysis for the chosen option

Determine precisely what and where you are touching (Glob/Grep/Read): the specific `.spy.yaml` models, the CRUD configs, the Flutter features and their `DwFeatureSpec`. What is **reused** (existing models/widgets/extensions), which layer patterns apply — lean on `dartway-models`, `dartway-crud-config`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit`, `dartway-feature-scaffold`.

## Phase C — Step-by-step plan

Order the steps end-to-end. Each step: **what to do → which files → which skill to lean on**. Skip the layers that are not relevant.

1. **Models/schema** — `.spy.yaml` edits (fields, relations, enums, nullable discipline). `dartway-models`.
2. **Generation/migrations** — `serverpod generate` → `create-migration`.
3. **CRUD configs** — `DwCrudConfig`: permissions, validations, before/after, side effects; registration in `crudConfigurations`. `dartway-crud-config`.
4. **Server-side logic** — `domain` (pure) / `app` (session-aware).
5. **Flutter** — navigation (the route) → the feature's entry point → data layer (watch/save) → UI Kit → specials. `dartway-feature-scaffold` / `dartway-data-layer` / `dartway-navigation` / `dartway-ui-kit`.
6. **Tests** — non-trivial logic / Event models / permissions; for a bugfix — the failing test first.
7. **Description** — reconcile the feature's `DwFeatureSpec` with the new behaviour, server-side rules go in doc comments above the CRUD config. No separate doc is created for a feature.

## Phase D — Subtleties and risks

Call out explicitly: edge cases and empty states; transactions/races (money/counters → Event models, not a direct field update); permissions and access filters; migrations and backward compatibility with existing data; feature isolation (import only the entry point); real-time/performance; what may break in adjacent features.

## Phase E — What to check after the implementation

A "definition of done" checklist for this task:

- **Functionally** — the key scenarios (including the edge cases) pass.
- **Tests** — the new/updated ones are green; the bugfix is covered by a regression test.
- **Migrations** — they apply on a clean DB and on top of an existing one.
- **Permissions/access** — behave as intended.
- **Description** — the feature's `DwFeatureSpec` is reconciled with the new behaviour.
- **Before the PR** — run **`dartway-finish`** (diff audit against the contract + docs sync + tests).

## Output format

The plan in the chat, in the user's language, touching no code: **Context → Step-by-step plan → Subtleties and risks → Verification checklist**. Once the plan is approved — move on to implementation (via plan mode or normal work), checking against the layer skills; close the task through `dartway-finish`.
