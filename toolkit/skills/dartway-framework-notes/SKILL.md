---
name: dartway-framework-notes
description: >-
  Filing a finding back to the DartWay framework as an issue: when to file one unasked, restating it
  for a stranger, the `impact:` and `silent` labels, showing the text before creating it, and the
  `TODO(dartway, checked: …)` marker a workaround leaves in the code. Use the moment such a finding
  appears, and before creating any issue in the framework tracker.
---

# DartWay — notes back to the framework (`dartway-framework-notes`)

**Tracker:** `__NOTES_TRACKER__`. `.claude/` is overwritten on update, so a rule that let you down is
fixed there, not here.

**File one without being asked when** the code broke a rule that does not exist or is too vague to have
prevented it; the app had to work around a `dartway_*` API (a wrapper, a `hide`, a copied private
helper); or you are tempted to edit a managed file — that temptation is the finding. Write it as the
toolkit would need it: the example, why the rule did not catch it, the wording to add.

## Before creating the issue

1. **Restate it for a stranger** — no paths, class names or domain of this project. If nothing
   survives, it was never about the framework: `docs/dev_notes/`.
2. **In English.**
3. **Search the tracker.** A gap already filed gets a comment with your impact, not a second issue; its
   label rises to the worst voice.
4. **Label it** — part of the text you show:
   - `impact:blocks` — could not be worked around, or the feature was dropped;
   - `impact:workaround` — worked around, and the code carries the marker;
   - `impact:friction` — works, but the API or its documentation pushes toward the wrong thing;
   - `silent` (orthogonal) — it broke with no error, test or log line.
5. **Show the text and wait for a yes** — an issue is public the moment it exists.

With the tracker `none` (`dartway setup-ai --notes-tracker none`), nothing leaves the project: the
finding is a `docs/dev_notes/` entry without the issue line.

## A workaround leaves a marker in the code

```dart
// TODO(dartway, checked: 0.20.0): <what we work around, what should appear upstream>
```

`checked:` is the framework version the workaround was last confirmed against — the version of a pub
dependency, the resolved ref of a git one. The marker, the issue and the `docs/dev_notes/` entry are one
record; write all three. `dartway-finish` compares `checked:` with `pubspec.lock` and speaks only when
they differ; `/dartway-checkup` does it project-wide.
