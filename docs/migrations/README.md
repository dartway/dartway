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

The `framework-finish` skill asks for this by name, and the reason it is a step rather than a habit
is that the author of a change is the last person who can see it as a stranger would, and the only
one who still knows what they broke.

## Not before the rewrite has a release

The DartWay 1.0 rewrite (`dartway_core_*` and the packages around it on this branch) has not been
released, and until it is, **nothing is preserved and nothing is owed**: versions stay `0.x`, the
projects moving onto it are recreated on it rather than migrated, databases included (D-031). A note
is a promise to a project that stands on a released version, so notes for the rewrite are written
once releases of it exist — from the first one on, every change that asks a project to edit its own
code carries one, in the same pull request.

A note already in this folder is filtered like any other: a project that does not depend on the
packages it names, or already has the version it lands in, is never shown it.

## The form

```markdown
---
title: The web image takes the app's origin as a build argument
affects:
  dartway_cli: "0.11.0"
---

## Who is affected

A project whose `<project>_flutter/Dockerfile` declares no `ARG DW_BACKEND_URL` — every project
created before `dartway_cli` 0.11.0. `dartway deploy` passes the app its own origin under that name,
and Docker drops a build argument the Dockerfile does not declare, without a word.

## What to change

`<project>_flutter/Dockerfile`, before `flutter build web`:

    + ARG DW_BACKEND_URL
    + RUN test -n "$DW_BACKEND_URL"
    - RUN flutter build web --release
    + RUN flutter build web --release \
    +     --dart-define="DW_BACKEND_URL=${DW_BACKEND_URL}"

## How to check

`dartway deploy check --env <environment> --local`: `web-backend-url` passes.
```

(An illustration of the form, not a real note: the version is made up.)

**`affects` is the whole mechanism, so it is checked rather than trusted.** Each key is a package
name; each value is the version the change lands in, **quoted** — unquoted `0.8` is a YAML number
and not a version. A project below that version on any of the listed packages is shown the note;
a project that does not depend on any of them never sees it. `migration_notes_test.dart` fails if
a note names a package that does not exist, states a version ahead of what that package is on, or
cannot be parsed at all.

**Versions rather than commits**, because the CLI reads the monorepo from a shallow clone and has
no history to diff — and because a version is what a project actually moves.

**A change to `template/` alone is keyed to `dartway_cli`.** The skeleton has no version of its
own, and a project keeps its copy of what it was created from — so a fix to `template/` reaches
nobody, and the note is the whole delivery. `dartway_cli` is the right key because the skeleton's Flutter
package declares it as a dev dependency, which puts it in the lock of every project `dartway create`
produces; name the version being released with the fix.

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
