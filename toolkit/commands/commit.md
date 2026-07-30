---
description: Commit the current branch's changes in the format the CI checks
argument-hint: "<TICKET> (e.g. PROJ-123)"
---

Analyze all the changes in the current branch and make a commit with a precise description of what was done, **in English**, briefly.

## The ticket is a required argument

The ticket number is passed as a **command argument**: `$ARGUMENTS` (e.g. `PROJ-123`). We do **not** pull the ticket out of the branch name. If the argument is empty — stop and ask for the ticket number, do not commit.

## The format of the first line

`<type>: <short description> #<TICKET>`

- `<type>` — `feat`, `fix` or `chore` (lowercase), then `: ` (a colon plus one space). Determine it from the meaning of the changes.
- `<short description>` — in English, terse, what was done; latin letters/digits/spaces/`-`/`.`/`_`.
- `#<TICKET>` — `#` + the argument passed in (e.g. `#PROJ-123`).

Examples:

- `fix: stabilize quiz result option bar layout #PROJ-58`
- `feat: add survey redirect condition #PROJ-149`
- `chore: add local docker dev setup #PROJ-14`

The exact ticket format (prefix, case) is set by the project's CI — it does the final check; see the project's `CLAUDE.md`/README if you need to confirm. The commit body (after a blank line) is optional; keep useful context the way the project does.

First determine the type (`feat`/`fix`/`chore`) from the meaning of the changes, assemble one correct first line with the ticket passed in, and make the commit.
