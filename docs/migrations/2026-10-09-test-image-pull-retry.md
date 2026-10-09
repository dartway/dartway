---
title: dartway test pulls its own images, with retries
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

A project whose CI runs a "pre-pull test containers" step before `dartway test`, one that reads
the image names out of the CLI's private `lib/src/deploy/stack.dart`. The step is optional: nothing
breaks if it stays, but it breaks silently whenever that file changes.

## What to change

Delete the step from the workflow. `dartway test` now pulls the Postgres and storage images itself
when they are absent, with up to three attempts, and names the image when every attempt fails.

## How to check

The CI job runs `dartway test` with no step before it that pulls images, and the suite is green.
