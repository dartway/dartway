# Migration notes

**One file per framework change that a project has to answer with an edit of its own.**

Everything else in the monorepo describes the framework as it is now. These notes are the only
thing addressed to a project that is *behind*: they say what the new version expects that the old
one did not, and what to change to satisfy it.

`dartway update`, run in a project, reads this folder out of the channel it installs from and
prints the notes that still apply to that project. Nothing else tells a project it owes an edit —
the compiler speaks only after the packages have already moved, and by then the person doing the
update is reading errors instead of instructions.

## When a note is written

**In the same pull request as the change, and only when a project has work to do.** The test is
whether an application on the framework, doing nothing wrong, would have to touch its own code:

- a public symbol renamed, removed or given a different signature;
- a changed default that alters behaviour a project relies on;
- a new mandatory initialization or wiring step;
- a package split, merged or renamed;
- a configuration or generated-code layout a project keeps a copy of.

**No note for:** a fix that only makes an existing call work; anything private or internal; a new
capability a project may adopt whenever it likes. A note that asks for nothing teaches people to
skim the ones that do.

`framework-finish` asks for this by name — it is step 5 of that skill, and the reason it is a step
rather than a habit is that the author of a change is the last person who can see it as a stranger
would, and the only one who still knows what they broke.

## The form

```markdown
---
title: DwCore.init takes its plugins as a list
affects:
  dartway_flutter: "0.8.0"
---

## Who is affected

A project that calls `DwCore.init` with named plugin arguments — every project created before
0.8.0, whether or not it declares plugins of its own.

## What to change

`dartway_flutter/lib/src/dw_core.dart`, in the app file (`<project>_app.dart`):

    - DwCore.init(prefs: prefsPlugin, push: pushPlugin);
    + DwCore.init(plugins: [prefsPlugin, pushPlugin]);

## How to check

`dart analyze` in the Flutter package: the old form no longer compiles, so a missed call site is
an error rather than something that surfaces at runtime.
```

**`affects` is the whole mechanism, so it is checked rather than trusted.** Each key is a package
name; each value is the version the change lands in, **quoted** — unquoted `0.8` is a YAML number
and not a version. A project below that version on any of the listed packages is shown the note;
a project that does not depend on any of them never sees it. `migration_notes_test.dart` fails if
a note names a package that does not exist, states a version ahead of what that package is on, or
cannot be parsed at all.

**Versions rather than commits**, because the CLI reads the monorepo from a shallow clone and has
no history to diff — and because a version is what a project actually moves.

**File name: `YYYY-MM-DD-slug.md`.** The notes are listed in file-name order, which is the order
they are applied in by a project that has fallen several releases behind. Two notes landing on one
day are ordered by their slug — so when one has to come after another, the slugs have to say so.

**Write the edit, not the news.** "The auth flow was reworked" is a changelog entry; this file is
read by someone who has to change a line and wants to know which one. The changelog says what
happened, the note says what to do about it.

## Where this is not the right place

- **What changed, for someone reading a release** — the package's `CHANGELOG.md`.
- **How something works now** — `docs/`, and the toolkit skill that teaches it.
- **A finding about a project's own code** — that project's `docs/dev_notes/`.
