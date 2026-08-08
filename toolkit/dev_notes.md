# Findings about this project

The nuances, problems and technical risks this project carries that **do not fit the task at hand
and are not confined to a single feature**: CI that runs less than it declares, a pin that trails,
a config written down twice, a tendency you keep seeing. Git-ignored — a working journal, kept until
each entry is dealt with.

**Language:** whatever this project writes in (`__PROJECT_LANGUAGE__`).

## What belongs here — and what does not

Every finding has exactly one home. Take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed right now | fix it — no entry anywhere |
| belongs to one feature | that feature's `knownIssues` in its `DwFeatureSpec` |
| is about the DartWay framework, not this project | `dartway_notes.md` |
| **fits none of the above** | here |

Without that gate this file becomes a TODO dump in two weeks, which is the thing the framework tells
projects not to keep. If a finding has a feature, it lives next to the code — where the compiler, the
checker, Studio and the next reader all pass by it.

## How an entry is written

**Short.** Where, what is wrong, what it leads to. Mention an option if one is obvious; do not write
it up — a journal of treatises is a journal nobody reads.

**Status:** `open` — written, nothing done yet · `in-progress` — being dealt with · `done` — safe to
delete.

---

## Entries

<!-- Template. Copy, fill, delete the rest.

### <short title>

- **Status:** open
- **Where:** `path/file.dart:12` — or the area, if it is not one place
- **What is wrong:** one or two sentences
- **What it leads to:** the consequence, not the feeling
- **Possible direction:** optional, one line

-->

---

## Deep-pass coverage

Which features `/dartway-checkup` has read properly, and when. The command chooses what to read next
from this table — never-visited first, then the ones that changed most since their pass — so a
project gets covered feature by feature instead of skimmed all at once every time.

Delete a row when the feature is gone. Keep it when the feature is refactored: what matters is when
somebody last looked at it closely.

| Feature | Last deep pass | Findings then | Still open |
|---|---|---|---|
| <!-- app/issues/board --> | <!-- 2026-08-08 --> | <!-- 3 --> | <!-- 1 --> |
