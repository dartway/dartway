---
name: dartway-plan
description: >-
  Planning after the requirements are agreed and an option chosen: re-read the code for that
  option and produce a step-by-step end-to-end plan in the DartWay order (contract → server → app →
  tests → descriptions), with the risks and a verification checklist. Read-only: writes no code. Run
  as /dartway-plan after /dartway-requirements, before writing code.
---

# DartWay — development planning (`dartway-plan`)

Read-only: a plan in the chat, no code. Needs the agreed requirement and the **chosen option** from
`dartway-requirements`; without them, send it back there. No work "just in case".

**A. Context.** The requirement and the option. **Read `docs/adr/`**: an approach an ADR rejected is not
proposed again as new — reconsidering one names the ADR and what changed (skip a superseded one for its
successor).

**B. Re-read** exactly what the option touches: the DTOs, refusal codes, channels and purposes in
`__SHARED_PKG__/lib/src/`; the rows, handlers, rules, jobs and mappers in `__SERVER_PKG__/lib/src/`; the
features, their specs and routes in `__FLUTTER_PKG__/lib/`. Name what is reused.

**C. The plan**, each step: what → which files → which skill. Skip what does not apply.

1. Contract — data objects, requests (kind, channels, `matches`), commands, refusal codes, channel
   kinds, purposes (`dartway-contract`, `dartway-realtime`).
2. Rows — money and counters as event rows (`dartway-server`).
3. Generate and migrate — every decision of the draft named (`dartway-migrations`).
4. Handlers — the rule of each, what each command publishes where, locks, channel rules
   (`dartway-server`, `dartway-access`, `dartway-realtime`).
5. Jobs, routes, upload rules — only if the option needs them.
6. App — route, feature and spec, reads and commands, kit, texts and refusal texts
   (`dartway-navigation`, `dartway-feature-scaffold`, `dartway-data-layer`, `dartway-ui-kit`).
7. **Risks to guard** — take the items from D and the spec that fall into `dartway-testing`'s six
   must-test classes; this selects from D, it is not a second risk survey. Each item names its class
   (1–6) and the expected outcome from the spec, guarded once at the boundary that owns it.
   **`No must-test risk: <why>`** is valid. A bugfix still starts with the failing test.
8. Descriptions reconciled in the code (`dartway-documentation`).
9. An ADR — only if the plan itself rejected a real alternative.

**D. Risks**, called out: edge and empty states and how a refusal looks; who may call and subscribe,
what an anonymous caller gets, a filter that could leak; every screen that must follow the change and
whether its request hears the channel; races (locks or event rows); renames and backfills over existing
rows; installed app builds and the contract's breaking line; feature isolation and neighbours that may
break.

**E. Verification**: the scenarios pass in the running app (`dartway-run`); the gates of
`dartway-finish` are green, and the migration applies on a database holding rows, not only on scratch; refused where intended and live where intended; the descriptions match; then
`dartway-finish`.

Output: **Context → Plan → Risks → Verification**, in the user's language.
