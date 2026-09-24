---
name: dartway-plan
description: >-
  Development planning AFTER the requirements are agreed (DartWay projects): the requirements are
  approved and an implementation option is chosen — the skill analyses the codebase once more for the
  chosen approach and produces a detailed step-by-step end-to-end plan in the DartWay order (contract
  → server → app: data objects, requests, commands, refusal codes and channels → row classes,
  generation, migrations, handlers with access rules and publications → routes, features, data
  layer, UI kit, texts → tests → descriptions), highlights the subtleties and risks and gives a
  verification checklist for after the implementation. Read-only: produces a plan, writes no code.
  Run as /dartway-plan after /dartway-requirements, before writing code.
---

# DartWay — development planning (`dartway-plan`)

The second step of a DartWay task: turn the agreed requirement and the chosen option into a **detailed,
executable plan**. The skill is **read-only**: it analyses the code and produces a plan, the subtleties,
the risks and a verification checklist. **It writes no code.**

## ⛔ Principle

The plan follows the DartWay order: **contract → server → app.** The contract comes first because both
sides compile against it — a data object, the requests that read it and the commands that change it are
the agreement the handler and the screen are then written to. The domain comes before the screen: data
objects and rows reflect the domain, not the momentary needs of one widget. Maximum reuse of what exists;
a door outside the call mechanism (a `DwHttpRoute`) only for an external caller, as a documented exception.
Do not plan work "just in case" — YAGNI.

## Phase A — Context

Record: the agreed requirement + the **chosen implementation option** (from `dartway-requirements`). If no
option is chosen or the requirements are not agreed — stop and send it back to `dartway-requirements`.

**Read `docs/adr/` if the project has it.** Those are decisions already taken, each with the alternatives
it ruled out and why. Two things follow: an approach listed there as rejected is not proposed again as if
it were new — and if you believe it should be reconsidered, say so explicitly, naming the ADR and what has
changed since. A decision quietly re-litigated is how a project ends up arguing the same question twice a
year. Skip an ADR whose status says `superseded by NNNN` and read that one instead.

## Phase B — Re-analysis for the chosen option

Determine precisely what and where you are touching (Glob/Grep/Read):

- **the contract** in `__SHARED_PKG__/lib/src/` — the data objects, requests and commands, the project's
  refusal enum, the channel kinds, the upload purposes;
- **the server** in `__SERVER_PKG__/lib/src/` — the row classes, the handlers answering those DTOs, the
  access and channel rules, jobs, routes, upload rules, the mappers that build data objects from rows;
- **the app** in `__FLUTTER_PKG__/lib/` — the features and their `DwFeatureSpec`, the routes, the requests
  they watch and the commands they run.

What is **reused** (existing DTOs, rows, handlers, features, UI kit widgets), which layer patterns apply —
lean on `dartway-contract`, `dartway-server`, `dartway-access`, `dartway-realtime`, `dartway-migrations`,
`dartway-uploads`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit`, `dartway-feature-scaffold`.

## Phase C — Step-by-step plan

Order the steps end-to-end. Each step: **what to do → which files → which skill to lean on**. Skip the
layers that are not relevant.

1. **Contract** (`__SHARED_PKG__`) — the data objects (fields, nullability that reflects the domain, doc
   comments on what each field means); the requests that read them — the kind (`DwSingleRequest`,
   `DwMaybeRequest`, `DwListRequest`, `DwPageRequest`, `DwTableRequest`, `DwWindowRequest`), `matches`
   and `sort` where the kind has them, the **channels** each listens on; the commands that change them
   (`DwActionCommand`, `validate()` for field rules both sides apply); new refusal codes in the project's
   refusal enum; new channel kinds; upload purposes. `dartway-contract`, `dartway-realtime`.
2. **Server rows and schema** (`__SERVER_PKG__`) — row classes (`@DwSqlTable`, foreign keys, unique
   columns, indexes); for money and counters, an event row rather than a field updated in place.
   `dartway-server`.
3. **Generation and migration** — `dart run dartway_cli:dartway generate` (codecs, the protocol registry, tables, the schema),
   then `dart run bin/migrate.dart create <name>` and the review of the draft: every decision named
   (rename or drop, the backfill for a `NOT NULL` column on a table with rows). `dartway-migrations`.
4. **Handlers** — one per new request and command, each with its access rule (`DwAccessRule` — who may
   call it, and where ownership is checked); what each command **publishes, to which channel**, so every
   request that shows the changed data follows it; channel rules for new channel kinds; row locks for
   read-modify-write. Doc comments above handlers and rules state the rule. A request or command without
   a handler stops the server from starting. `dartway-server`, `dartway-access`, `dartway-realtime`.
5. **Background and doors, only if the option needs them** — jobs (`DwJobDefinition`, `DwRecurringJob`)
   for work outside a call, a `DwHttpRoute` for an external caller (a webhook), upload rules and `canRead`
   for files. `dartway-server`, `dartway-uploads`.
6. **App** (`__FLUTTER_PKG__`) — the route (`dartway-navigation`) → the feature's entry point and its
   `DwFeatureSpec` (`dartway-feature-scaffold`) → the data layer: `ref.watch(dw.request(...))` /
   `dw.pages` / `dw.table` / `dw.window`, commands through `dw.action` (`dartway-data-layer`) → the UI
   kit (`dartway-ui-kit`) → texts: new strings in every `.arb`, `flutter gen-l10n`, and a text for every
   new refusal code in the app's refusal text.
7. **Tests** (`dartway-testing`) — the contract test for new DTOs, `validate()`, `matches` and channels;
   server acceptance tests for access rules, what commands write and publish, refusals; widget tests for
   what the screen shows and sends. For a bugfix — the failing test first.
8. **Description** — reconcile the feature's `DwFeatureSpec` with the new behaviour; server rules in doc
   comments above handlers and rules, contract meaning above DTOs. No separate doc is created for a
   feature.
9. **An ADR — only if this plan itself settles a choice.** The test is whether a real alternative was
   rejected here: a second storage, a door instead of a command, a library not taken, a shape of the API
   that lost. If so, the plan's last step is `docs/adr/NNNN-slug.md` with the alternatives and the reasons
   — the part which cannot be read off the code afterwards. If nothing was rejected, there is no ADR, and
   inventing one produces exactly the document the framework tells projects not to write.

## Phase D — Subtleties and risks

Call out explicitly:

- edge cases and empty states; what a refusal looks like on the screen;
- **access**: who may call each request and command, who may subscribe to each channel, and what an
  anonymous caller gets; a filter that must not leak another account's rows;
- **updates**: every screen that shows the changed data — does its request listen on the channel the
  command publishes to, and does `matches` remove an object that leaves its filter; a "my …" request on
  the caller's channel;
- transactions and races (money, counters, statuses → row locks or event rows);
- **migrations and existing data**: renames that must not become drop + add, backfills, whether the
  migration applies on a database with rows;
- **installed apps**: a changed or removed field in a data object meets app builds already on phones —
  whether they must be forced to update — a raised breaking line of `__SHARED_PKG__`'s `version:` — when this goes out;
- feature isolation (import only the entry point); real-time and performance (per-row queries, page
  sizes); what may break in adjacent features.

## Phase E — What to check after the implementation

A "definition of done" checklist for this task:

- **Functionally** — the key scenarios (including the edge cases) pass, in the running app (`dartway-run`).
- **Generated and migrated** — `dart run dartway_cli:dartway generate --check` is clean; `dart run bin/migrate.dart check`
  passes; the migration applies on a database with rows.
- **Tests** — the new/updated contract, acceptance and widget tests are green; the bugfix is covered by a
  regression test.
- **Access and updates** — refused where intended; the other screens and the other devices follow the
  change live.
- **Description** — the feature's `DwFeatureSpec` and the doc comments are reconciled with the new
  behaviour.
- **Before the PR** — run **`dartway-finish`** (diff audit against the contract + description sync + tests
  + checks).

## Output format

The plan in the chat, in the user's language, touching no code: **Context → Step-by-step plan → Subtleties
and risks → Verification checklist**. Once the plan is approved — move on to implementation (via plan mode
or normal work), checking against the layer skills; close the task through `dartway-finish`.
