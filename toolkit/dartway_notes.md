# Notes back to the DartWay framework

Everything this project ran into that has to be fixed **in the DartWay monorepo, not here**: a rule
that did not catch a mistake, two skills that disagree, an API that forced a workaround. Git-ignored
— a working journal, kept until its entries are carried over.

**Why not fix it in place.** `.claude/CLAUDE.md`, `.claude/skills/dartway-*` and the `commit` /
`dartway-audit` commands come from the toolkit and are overwritten on every update; the `dartway_*`
packages are external. The source of truth is the monorepo, so the fix has to travel there.

**Language:** whatever this project writes in (`__PROJECT_LANGUAGE__`). What travels to the monorepo
gets translated to English there — the toolkit ships to other people.

**Status:** `open` — written, waiting to be carried over · `in-progress` — being done in the monorepo
· `done` — carried over, safe to delete.

---

## Harness — rules, skills, commands

<!-- Template. Copy, fill, delete what does not apply.

### <short title>

- **Status:** open
- **Target:** `<skill file or CLAUDE.md>` → `<section>`
- **From the code:** path/file.dart:12 — what exactly was wrong
- **Why the rule missed it:** not covered / covered vaguely / the wording allows both readings /
  no ❌✅ example / no checklist item
- **What to add:** the concrete wording, ready to paste into the toolkit
- **Checklist:** does the skill need a new checklist line, and which

-->

## Framework — the `dartway_*` package APIs

<!-- Template.

### <short title>

- **Status:** open
- **Target:** package / class / method
- **From the code:** path/file.dart:12
- **The problem:** what the API lacks, or what it forces the app to write around it
- **The proposal:** how it should look from the calling code
- **Worked around here by:** what this project did meanwhile, so the workaround can be removed later

-->

## Tooling — installer, generators, CI

<!-- Template.

### <short title>

- **Status:** open
- **Target:** `dartway` CLI command / check / installer step
- **The problem:** what it does, or fails to do, and what that costs
- **The proposal:** the behaviour to implement

-->
