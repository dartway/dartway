---
title: Every top-level ctx.transaction retries a deadlock
affects:
  dartway_core_server: "0.21.0-dev.17"
---

## Who is affected

A project that opens `ctx.transaction` outside a transactional command — in a route, a
`transactional: false` command, a leased (`transactional: false`) job or a startup step — or that
wraps one in a retry loop of its own. A top-level `ctx.transaction` now retries a deadlock (`40P01`)
or a serialization failure up to three attempts, with the memo cleared between them; a
transactional queued job and a recurring job re-run their handler in place the same way. Nothing
breaks if a project does neither step below.

## What to change

1. Read every such `ctx.transaction` body for work outside the database — an outbound HTTP call,
   a message sent, a file written. The body may now run up to three times: move that work before
   or after the transaction.
2. Delete hand-rolled retry loops around `ctx.transaction` that catch `DwSerializationFailure` or
   SQLSTATE `40P01`. Left in place, such a loop nests its own attempts around the framework's, up to
   three times three, and does not clear the memo between them.

## How to check

`grep -rn "40P01\|DwSerializationFailure" <project>_server/lib` finds no retry loop, and no
`ctx.transaction` body in a route, a non-transactional command, a leased job or a startup step
calls another service.
