---
name: dartway-update
description: >-
  Moving this project onto a newer DartWay (DartWay projects): updates the agent toolkit,
  reads the framework's migration notes, makes the edits they ask for, moves the package
  versions and proves the result with the checker, the analyzer and the tests. Use when the
  framework has released, when `dartway update` reports the project is behind, or when a fix
  the project is waiting for has landed upstream; runs as /dartway-update.
---

# DartWay — updating the project (`dartway-update`)

A project on DartWay drifts silently. The toolkit is a committed artifact that looks exactly the
same when it is a month old; a package version lives in a lock file nobody reads; and the
framework changes that ask the project to change with them are invisible until something stops
compiling — or worse, until it compiles and behaves differently.

This skill is the update, end to end: **what moved, what the project owes because of it, and the
proof that the result works.**

## What this is not

**Not a version bump.** Raising a caret is the last step, not the task. A framework release can
carry changes that expect the project's own code to be different, and moving the packages before
making those edits turns a readable instruction into a screen of compile errors.

**Not a release of this project.** It ends with a commit and a PR like any other change. Whether
that goes out is a separate decision, made the way this project makes it.

---

## Step 1. Start on a branch, from a clean tree

`git status` first. A dirty tree means somebody's unfinished work is in it, and an update touches
files across the whole project — `.claude/`, pubspecs, lock files, and whatever the migrations
ask for.

```bash
git switch -c chore/dartway-update __BASE_BRANCH__
```

Clean tree, own branch, and the update is reviewable as one diff. That matters more here than
usual: the toolkit diff is large and mechanical, and it must not arrive mixed into a feature.

## Step 2. Update the CLI itself

```bash
dart pub global activate dartway_cli
```

The CLI reads the framework and installs the toolkit, so an old one installs an old idea of what a
project needs — including being unaware of files a newer toolkit ships. It cannot replace itself
mid-run, which is why this is a step rather than something `dartway update` does for you.

## Step 3. Run the update

```bash
dartway update
```

It installs the toolkit into `.claude/` and then reports three things:

- **the toolkit** it just installed, and where it came from — channel and commit;
- **the framework packages** this project is behind on, with the version it is on and the version
  the channel has, per lock file;
- **the migration notes** that still apply — the framework changes this project has to answer with
  an edit of its own.

Read that output before doing anything. If it names no migrations and no packages, the update is
already finished: commit `.claude/` and stop.

> `dartway update` deliberately changes nothing but `.claude/`. Everything else it reports is
> work with judgement in it, and a command that half-applied it would leave a tree nobody can
> tell apart from a finished one.

## Step 4. Read every migration note, in the order given

Each note says who is affected, what to change and how to check it. They are listed oldest first,
and that is the order to apply them in: a project several releases behind may be carrying two
changes to the same call site.

**Before editing, find out whether this project is affected at all.** The note's `affects` line
puts it in front of you by version; whether the code actually uses what changed is a `grep`. A
note that turns out not to apply is a normal outcome — say so and move on.

## Step 5. Make the edits

Apply what the notes ask for, one note at a time, and keep them separable in the diff. Use the
project's own conventions — the migration says *what* has to change, not how this project writes
code; `dartway-clean-code` and the feature layout still decide that.

**Where a note and this project disagree, stop and ask.** A migration is written for the general
case, and a project that has done something deliberately different is exactly the case its author
could not see. Do not invent a third way silently.

**Findings about the framework go to `__NOTES_TRACKER__`**, as they always do: a migration note
that is wrong, incomplete, or missing for a change that clearly needed one is a framework defect,
and it is worth more filed than fixed locally.

## Step 6. Move the packages

Only now, and by source — `dartway update` says which is which:

- **hosted:** raise the caret in the `pubspec.yaml` it names, then `dart pub get`. Under a `0.x`
  major a minor behaves like a major: `^0.4.0` does not admit `0.8.0`, so the caret has to move,
  and lowering one to make something resolve is never the fix.
- **from git:** `dart pub upgrade <the dartway packages>` in the directory it names. A git
  dependency is pinned when it is added and stays there until something upgrades it *by name*, so
  upgrading one package at a time is how a project ends up running two framework releases against
  each other.

**Move them together.** The halves of this framework are released as a set, and a client on one
release talking to a server on another fails at runtime, not at compile time.

If the update moved `dartway_serverpod_core_*` or a Serverpod version, regenerate afterwards —
`serverpod generate` in `__SERVER_PKG__`, with the `serverpod_cli` version this project pins
(`dartway doctor` states it). The generated client is code the project commits, so a stale one is
a lie the compiler believes.

## Step 7. Prove it

In this order, because each one answers a question the next cannot:

```bash
dartway check                  # the conventions, including whether the framework refs now agree
dart analyze                   # every package
dartway test                   # or this project's test command
```

Then **run the app** (`dartway-run`): an update can be green in all three and still land on a
blank screen, because what changed was a default or a wiring step rather than an API.

`dartway check` matters here for one finding in particular: if it still reports the framework
packages locked to several commits, step 6 moved only some of them.

## Step 8. Commit

`.claude/` is committed with the rest — it is a generated-but-committed artifact, and its history
is what says which skills the code was written with.

One commit per concern, and the update itself is one:

```
chore(deps): move to dartway <version>, applying <n> migrations
```

Say in the body which migrations were applied and which were read and found not to apply. The
next person doing this update on another project reads that as the first data point.

## Step 9. Report

- toolkit: what was installed, from which channel and commit;
- packages: what moved, from what to what;
- migrations: applied · not applicable · **left undone, and why** — an update stopped halfway is
  a legitimate outcome and a dangerous silence;
- checks: what is green, and what was already red before this started;
- anything filed to `__NOTES_TRACKER__`.
