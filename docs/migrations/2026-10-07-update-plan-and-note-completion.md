---
title: Plan exact framework updates and record verified migration-note dispositions
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

Projects and automation running `dartway update`, including projects that already raised their
framework pins or installed a new toolkit without reviewing all migration notes.

## What to change

Replace an immediate `dartway update` installation with `dartway update --plan`, followed by
`dartway update --target <full-commit-sha>` with the same source and installer options. The plan
prints the target SHA. Local framework sources are read from their committed tree.

If plugin preflight fails because a hosted version is unpublished, select a published target or
configure a resolvable project-owned git/path plugin source. Do not accept an unresolvable pin.

Review every unconfirmed migration note. An unknown baseline does not say that nothing was
migrated; it says no verified note dispositions were recorded. For each note, inspect usage,
apply any required edits and run its checks. After verification, record it explicitly:

```bash
dartway update --target <sha> --complete docs/migrations/<note>.md --verified --verification "Checks and actual results"
dartway update --target <sha> --not-applicable docs/migrations/<note>.md --verified --verification "Inspected usage and applicability evidence"
```

Use the same source options as the plan. Commit `.dartway/migrations.json` with the project edits.
Record only verified notes; outstanding work stays unconfirmed. Dependency locks and toolkit
installation are not migration evidence. Preserve existing records rather than resetting the ledger.

## How to check

Run `dartway update --plan --target <sha>` with the same source. Verify that it changes no project
files, completed notes disappear from the unconfirmed list, and every remaining note stays listed,
even when the dependency locks already resolve the target. Run the project's normal finish gates
and verify the application before recording applied notes.
