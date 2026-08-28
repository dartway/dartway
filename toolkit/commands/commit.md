---
description: Commit the current branch's changes as one conventional-commit line, in English
---

Analyze all the changes in the current branch and make a commit with a precise description of what was done, **in English**, briefly.

## The format of the first line

`<type>(<scope>): <short description>`

- `<type>` — `feat`, `fix` or `chore` (lowercase). Determine it from the meaning of the changes.
- `<scope>` — optional, and welcome where the change belongs to a named part: `feat(session):`, `fix(deploy):`.
- `<short description>` — terse, what was done, in English.

Examples:

- `fix: stabilize the quiz result option bar layout`
- `feat(survey): add a redirect condition`
- `chore: add a local docker dev setup`

The body (after a blank line) is optional; keep useful context the way the project does.

## What this command deliberately does not decide

**Anything local belongs to the project, not here.** Whether commits carry a ticket number, in what format, whether a CI job checks the message at all — that is the project's convention, and it lives in the project's own `CLAUDE.md`. Read it; follow it if it says something; do not invent a requirement it does not state, and do not stop to ask for a ticket in a project that has no tracker. A command that blocks on an answer that does not exist looks like compliance and is not.

**A trailing `(#NN)` in the history is not part of the format.** GitHub appends the pull request number on squash-merge, after the fact. Reading `git log` to learn the convention therefore shows a number nobody typed — reproduce it and the next merge yields two, one of them meaningless. In a project numbering its tickets, the two are indistinguishable on sight.

First determine the type from the meaning of the changes, assemble one correct first line, and make the commit.
