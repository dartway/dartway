---
title: Declare lifecycle states and use guarded transitions
affects:
  dartway_orm: "0.23.0-dev.1"
  dartway_core_server: "0.23.0-dev.1"
  dartway_cli: "0.26.0-dev.1"
---

## Who is affected

Projects adopting state columns for lifecycle status fields. Existing unannotated columns keep
their ordinary repository behavior; review lifecycle statuses when updating the server toolkit.

## What to change

1. Declare a const `DwStateTransitions<YourStatus>` beside the enum with `initial` and `moves`.
   Annotate the row's non-null enum field with `@DwStateColumn(yourTransitions)` and regenerate.
2. Replace `update(row.copyWith(status: next))` and bulk state assignments with
   `transition(id, column: (t) => t.status, to: next)` or `transitionWhere`. Translate null or
   unchanged requested ids into the feature's refusal. Publish only returned rows.
3. Insert only initial states. Replace upserts on that table with insert/tryInsert plus transitions.
   Ordinary updates must carry the current stored state; they cannot reset a concurrently changed one.
   Catch `DwStaleState` for an ordinary edit that races a transition and translate it into your
   feature's conflict, or leave it to the server's `dw.conflict` response (HTTP 409, no incident).
   Re-read before deciding whether to retry. Keep `on DwRowNotFound` for missing rows, including
   state tables. Generated stored-row `copyWith(status: next)` throws `DwStateWriteException`
   when the value changes; `status: row.status` is allowed and passes the checker.
4. Remove raw SQL state writes in `lib/`. A migration backfill for stranded values uses `m.backfill`.

The annotation does not alter the SQL schema; no schema migration is needed for the annotation
alone. Do not rewrite an applied migration.

## How to check

Run generation and `dartway check`, then the feature's acceptance suite on a real Postgres. Cover
forbidden initial states and moves, repeated terminal moves, and competing transitions where only
one is legal after the first completes. Also verify an ordinary edit racing a transition throws
`DwStaleState` without overwriting fields, a deleted row throws `DwRowNotFound`, and an intentional
state change through `update(row.copyWith(...))` remains a programming error.
