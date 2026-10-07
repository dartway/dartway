---
name: dartway-commit
description: Commit the current branch's changes as one conventional-commit line, in English
---


Analyze all the changes in the current branch and commit them with a precise, brief description **in
English**.

**The first line:** `<type>(<scope>): <short description>` — `type` is `feat`, `fix` or `chore`,
decided by the meaning of the change; the scope is optional and welcome where the change belongs to a
named part (`feat(invoices):`, `fix(deploy):`). The body, after a blank line, is optional.

- `fix: stabilize the quiz result option bar layout`
- `feat(survey): add a redirect condition`

**What is local is the project's.** A ticket number, its format, a CI check of the message — read the
project's root instruction file (`AGENTS.md` or `CLAUDE.md`) and follow what it says; do not invent a requirement it does not state, and
do not stop to ask for a ticket in a project without a tracker.

**A trailing `(#NN)` in `git log` is not part of the format**: GitHub appends it on squash-merge.
Copying it produces two.
