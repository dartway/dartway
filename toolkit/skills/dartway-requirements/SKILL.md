---
name: dartway-requirements
description: >-
  Requirements analysis before a DartWay task: study what the project already has on the topic
  (DTOs, rows, handlers and rules, features and their specs), note the debt in the affected feature
  (blocking vs adjacent), ask only the blocking questions with a proposed default, and offer 2–3
  options along the DartWay ladder (reuse the contract → extend it → a job or a door) with risks and
  a rough estimate. Read-only: a report, no code. Run as /dartway-requirements at the start of a task.
---

# DartWay — requirements analysis (`dartway-requirements`)

Read-only: a report in the chat. Understand what exists before proposing anything; reuse it, and let
the solution follow the domain, not the momentary screen. The plan is the next step (`dartway-plan`).

**A. The spec.** The goal, the scope, the entities and actions — and the implicit assumptions and gaps,
kept for the questions, never filled in silently.

**B. What exists** (Glob/Grep/Read; Explore agents for breadth): the contract's DTOs, codes, channels and
purposes; the server's rows, handlers with their rules and publications, jobs, routes; nearby features,
their `DwFeatureSpec` and `knownIssues` — what is already known to be wrong is often the task. Reduce it
to **what exists → what is missing → what gets in the way**.

**C. Debt in the affected feature** — the whole feature, not only the future diff, judged by the law
table and the layer skills: 🔧 **blocking** (it complicates the new work — account for it in the options)
and 🧹 **adjacent** (tidy along the way, the author's call), each with `file:line`. Not a repository
audit: that is `/dartway-checkup`.

**D. Questions** — only the blocking ones, grouped (domain; access and roles; flow and states; who must
see a change live; existing data and migrations; volumes, files, background work, installed builds), each
with a proposed default.

**E. Options, 2–3, the lighter rung first:** reuse the contract (a field, a rule, a channel, a screen) →
extend it (new DTOs with handlers, rules and publications) → outside a call (a job, a `DwHttpRoute`),
with the reason a call cannot carry it. For each: how it works in DartWay terms, what it touches,
tradeoffs, risks (migrations, access, races, live updates, installed builds), the blocking debt it drags,
a rough estimate. End with a recommendation.

Output: **what exists / missing / in the way → debt → questions with defaults → options with a
recommendation**, in the user's language.
