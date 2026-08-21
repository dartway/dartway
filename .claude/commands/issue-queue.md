---
description: Drive the open GitHub issue queue — pick the top issue, clarify it, agree on a fix, hand it to a subagent that opens the PR
---

# The issue queue

One pass over the framework's open issues, run as a loop with the owner in it.
The owner decides *what* gets fixed; you decide *what is worth deciding on next*,
and you never lose anything on the way.

## Before anything

- `git status` — clean tree only (see the git protocol in `CLAUDE.md`).
- `git fetch origin && git merge --ff-only origin/master` — a stale master makes
  every judgement about "is this still open?" wrong.
- Issues are read from the GitHub API (`curl -s https://api.github.com/repos/dartway/dartway/issues?state=open&per_page=100`)
  when `gh` is not on the machine; with `gh` present, `gh issue list` is shorter.

## The loop

### 1. Pick the top issue

Priority, in order:

1. `impact:blocks` — there is nothing a project can write to work around it.
2. `impact:workaround` over `impact:friction`.
3. `silent` raises whatever it sits on: a defect nobody is told about costs
   more than a loud one.
4. Age breaks ties; a cluster of issues around one seam beats a lone one.

Before picking, discard the dead: an issue whose fix already rode in on a
merged PR that forgot the `Closes #N` keyword. Cross-references
(`/issues/<n>/timeline`) show these. Report them for closing — do not fix them
twice.

### 2. Clarify it — briefly

Read the issue, then read the code it names. Enough to answer three things:
what actually happens, why it happens, and what the blast radius is. Confirm
the mechanism in the tree rather than trusting the report's diagnosis; a report
written from a production incident often names the symptom correctly and the
cause approximately.

Stop when you can state the defect in one paragraph. This step is not the fix.

### 3. Bring it to the owner

Write it out: the mechanism, then **two or three shaped options** with a
recommendation and what each one costs. Name the parts of the tree the fix
would touch — the synchronisation law means the blast radius is rarely one
package. Flag anything that would need a decision the owner alone can make
(a breaking change, a migration in live projects, an API shape).

Then stop and wait. This is a conversation, not an approval form.

### 4. Hand it over

Once the owner has chosen, spawn a subagent. The brief it gets must carry:

- the issue number, its body, and everything you established in step 2;
- the chosen option and why the others were rejected;
- the working rules: **its own worktree** (`git worktree add ../dartway-wt/<slug> -b <type>/<slug> master`),
  never the shared tree; `git add` by name; conventional commits; English in
  everything that reaches GitHub;
- the acceptance test — how the fix is *demonstrated*, not asserted;
- the finish line: `framework-finish`, `dart analyze` and the tests green, then
  **open the PR itself** (`gh pr create`, body carrying `Closes #<n>`), and
  report the PR URL back.

Two standing instructions for every subagent:

- **Come back with the question, do not guess.** A brief that turns out to be
  wrong, a fix that grows a second breaking change, a test that cannot be
  written — those come back as questions, not as improvisation.
- **Findings that are not the task go in the report, not in the branch.** They
  become queue entries, not scope creep.

### 5. Keep the contour

After every step, the running state is stated back to the owner:

| | |
|---|---|
| **In flight** | issue → branch → subagent → PR, with status |
| **Next** | the two or three candidates and why they rank there |
| **Incidental findings** | what surfaced along the way and is not being fixed now |
| **To close** | issues already fixed by a merged PR |

The contour lives in the conversation and in the issue tracker — not in a file
in the tree (`CLAUDE.md`, "the place is not yours to invent"). Anything that
must outlive the session goes out through the `aios` skill.

### 6. Go again

A PR opened is not the end of an item; a PR merged is. Then take the next one.
