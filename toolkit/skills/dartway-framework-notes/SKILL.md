---
name: dartway-framework-notes
description: >-
  Filing a finding back to the DartWay framework as an issue: when to file one without being asked
  (a rule that did not exist or was too vague, a workaround over a `dartway_*` API, the temptation to
  edit a managed file), how to restate it for a stranger, the `impact:` and `silent` labels, showing
  the text before creating it, and the `TODO(dartway, checked: …)` marker a workaround leaves in the
  code. Use the moment such a finding appears, and before creating any issue in the framework
  tracker.
---

# DartWay — notes back to the framework (`dartway-framework-notes`)

`.claude/` is managed and gets overwritten on update, so a rule that let you down cannot be fixed here. It also cannot be left unsaid: the rules are only ever proven wrong by real code, and this project is the real code. Such a finding is **filed as an issue in the framework tracker** — there is no local journal in between.

**Tracker:** `__NOTES_TRACKER__` — the GitHub repository this project's framework findings are filed in as issues.

**File one without being asked when:**

- the code broke a rule that does not exist, or exists too vaguely to have prevented it;
- the app had to work around a `dartway_*` API — an extra wrapper, a `hide`, a copied private helper;
- you are tempted to edit a managed file (`CLAUDE.md`, `skills/dartway-*`, the `commit` / `dartway-checkup` commands). That temptation *is* the finding.

Write it the way it would have to be written in the toolkit: the example from the code, why the existing rule did not catch it, and the concrete wording to add — not "something is off here".

### What travels, and what must not

**The part that names this codebase does not travel.** Paths, class names, what the app did as a workaround — exactly what makes the finding actionable here, and exactly what must not appear in a repository other people read. That is why a workaround leaves a record in **both** places: the issue says what should change in the framework, `docs/dev_notes/` and the marker in the code say what this project is carrying meanwhile.

So before an issue is created:

1. **Restate the finding for a stranger** — the rule that was missing, the API that forced the workaround, put so that it stands without this project's code. If nothing survives that, the finding was never about the framework and belongs in `docs/dev_notes/`.
2. **Write it in English** — the tracker is read by people who do not work on this project.
3. **Search the tracker first.** Three projects meeting one API gap is one issue with three voices, not three issues.
4. **Label what it did to you** — the two labels below, and they are part of the text you show.
5. **Show the text and wait for a yes.** This is the only irreversible step here — an issue exists publicly from the moment it is created.

**The one tracker value that is not a repository is `none`**, chosen deliberately (`dartway setup-ai --notes-tracker none`) by a project that must not push into a repository other people read. Nothing then reaches the network: the finding is written into `docs/dev_notes/` in the same form, without the issue line.

#### The two labels

**`impact:` — what the finding did to this project, not how bad it feels.** The value is remembered, not judged.

| Label | What actually happened |
|---|---|
| `impact:blocks` | It could not be worked around. Either the project cannot do what it has to, or the workaround cost more than the feature and the feature was dropped |
| `impact:workaround` | It was worked around, and the code carries the marker to prove it. The day the fix lands upstream, that code starts duplicating the framework |
| `impact:friction` | It works, but the API pushes you to write the wrong thing, or the documentation says something untrue. Nobody was blocked and there was nothing to work around |

**`silent` — it breaks with no error attached.** Orthogonal to impact. Nothing announced the defect — no exception, no red test, no line in a log — so it was found by eye, months later, if at all.

**None of this ranks your finding against anyone else's.** The labels record what happened to this project; which issue is picked up first is decided where the queue lives. **A gap another project has already filed gets a comment, not a second issue**: your impact in one line, and the label rises to the worst voice on the issue if yours is worse.

### A workaround over a `dartway_*` API also leaves a marker in the code

The issue records that the framework should change. It does not record whether this project's workaround is still needed — and that is the half which goes wrong, because the framework moves while the project's code does not. The day the fix lands upstream the workaround keeps running, now duplicating the framework, and nobody is looking.

So the code carries a marker naming the framework version the workaround was last confirmed against:

```dart
// TODO(dartway, checked: 0.20.0): <what we work around, what should appear upstream>
```

- **`checked:`** — the version of the framework this workaround was last verified against: the version number for a pub dependency, the resolved ref for a git one.
- **The sentence** — what the app is doing instead, and what would have to exist upstream for the workaround to go.

The marker and the `docs/dev_notes/` entry are two halves of one record. Write both. `dartway-finish` compares `checked:` against the version resolved in `pubspec.lock` and raises the marker **only when the two have diverged**.
