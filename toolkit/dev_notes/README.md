# Findings about this project

The nuances, problems and technical risks this project carries that **do not fit the task at hand
and are not confined to a single feature**: CI that runs less than it declares, a pin that trails,
a config written down twice, a tendency you keep seeing.

One file per finding, `docs/dev_notes/<slug>.md`, **committed like any other file in the repository**.
Committed is the whole point: a finding travels out of a branch through the pull request that carries
it, it is visible in review, and it survives a `git worktree remove`. The journal this replaced was
git-ignored, and on one project a single day's worth of findings had to be pulled out of throwaway
working copies by hand before they were deleted.

One file per finding rather than one file appended to, because parallel branches appending to the
same journal conflict on the same lines in every second pull request. Separate files have nothing to
conflict on, each entry stands on its own in the diff, and a finished one is deleted as one file.

**Language:** whatever this project writes in (`__PROJECT_LANGUAGE__`).

## What belongs here — and what does not

Every finding has exactly one home. Take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed right now | fix it — no entry anywhere |
| belongs to one feature or screen | that feature's `knownIssues` in its `DwFeatureSpec` |
| **has no address in code** — cross-cutting, infrastructural, a decision with a price | here |

The test is whether the finding has an address in code. If it does, it lives next to that code, where
the compiler, `dartway check`, Studio and the next reader all pass by it. If it does not, there is
nowhere to put it but here. The full rule, and what a `knownIssues` line is for, is in
`.claude/CLAUDE.md` — do not re-derive it from this paragraph.

**The defect itself lives in the tracker; this entry only references it.** The issue holds the status,
the discussion and the pull request that closes it, and an entry repeating any of that is a second
copy of a state that changes elsewhere. When the issue closes, delete the file.

A finding about the **framework** is not a project finding and does not belong here — it is filed as
an issue in `__NOTES_TRACKER__`. The exception is a workaround this project is carrying for it: that
is this project's code, so it gets an entry, and the entry links the issue. Where the tracker is
`none` there is no issue to link, and the entry *is* the record — same form, without the link line.

## How an entry is written

**Short.** Where, what is wrong, what we did about it. Mention an option if one is obvious; do not
write it up — a journal of treatises is a journal nobody reads.

```markdown
# <short title>

- **Issue:** owner/repo#123
- **Where:** `path/file.dart:12` — or the area, if it is not one place
- **What is wrong:** one or two sentences
- **What we did about it:** the workaround that is in place, or nothing yet
- **Possible direction:** optional, one line
```

Which features have had a deep pass, and when, is in [`_coverage.md`](_coverage.md).
