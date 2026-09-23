---
name: dartway-update
description: >-
  Moving this project onto a newer DartWay (DartWay projects): update the CLI, run `dartway update`
  (it installs the agent toolkit into .claude/ and reports the framework packages that are behind
  and the migration notes still owed), make the edits the notes ask for, then move the package
  versions — the core family (`dartway_core_shared`, `dartway_core_server`, `dartway_core_flutter`
  and the packages released with it, `dartway_client`, `dartway_generator`) together to one
  version, satellites (`dartway_router`, `dartway_lints`, `dartway_shared_preferences`,
  `dartway_cli`, …) each on its own — regenerate with `dart run dartway_cli:dartway generate`, and prove the result with
  the checks, the tests and a run. Use when the framework has released, when `dartway update`
  reports the project is behind, or when a fix the project is waiting for has landed upstream; runs
  as /dartway-update.
---

# DartWay — updating the project (`dartway-update`)

A project on DartWay drifts silently. The toolkit is a committed artifact that looks exactly the same
when it is a month old; a package version lives in a lock file nobody reads; and the framework changes
that ask the project to change with them are invisible until something stops compiling — or worse,
until it compiles and behaves differently.

This skill is the update, end to end: **what moved, what the project owes because of it, and the proof
that the result works.**

## What this is not

**Not a version bump.** Raising a caret is the last step, not the task. A framework release can carry
changes that expect the project's own code to be different, and moving the packages before making those
edits turns a readable instruction into a screen of compile errors.

**Not a release of this project.** It ends with a commit and a PR like any other change. Whether that
goes out is a separate decision, made the way this project makes it — with one consequence named in
step 7.

---

## Step 1. Start on a branch, from a clean tree

`git status` first. A dirty tree means somebody's unfinished work is in it, and an update touches files
across the whole project — `.claude/`, pubspecs, lock files, generated code, and whatever the migration
notes ask for.

```bash
git switch -c chore/dartway-update __BASE_BRANCH__
```

Clean tree, own branch, and the update is reviewable as one diff. That matters more here than usual:
the toolkit diff is large and mechanical, and it must not arrive mixed into a feature.

## Step 2. Update the CLI itself

```bash
dart pub global activate dartway_cli
```

The CLI reads the framework and installs the toolkit, so an old one installs an old idea of what a
project needs — including being unaware of files a newer toolkit ships. It cannot replace itself
mid-run, which is why this is a step: `dartway update` only warns when the channel carries a newer CLI
than the one running.

## Step 3. Run the update

```bash
dartway update
```

It takes the framework from the channel this project was set up with (the recorded one; `--channel`
overrides it, `--local-repo` points at a local checkout), replays the recorded install settings, and:

- **installs the toolkit** into `.claude/` and says where it came from — channel and commit;
- reports **the framework packages this project is behind on** — for each: the version the project
  resolves (the lowest across its lock files), the version the channel has, and the directories whose
  `pubspec.lock` holds it — with the instruction for hosted and for git dependencies;
- reports **the migration notes that still apply**, oldest first — the framework changes this project
  has to answer with an edit of its own, each with its file in the framework checkout and the version
  it lands in.

Read that output before doing anything. If it names no packages behind and no migrations, the update
is already finished: commit `.claude/` and stop.

> `dartway update` deliberately changes nothing but `.claude/`. Everything else it reports is work with
> judgement in it, and a command that half-applied it would leave a tree nobody can tell apart from a
> finished one.

A note reported as unreadable ("Migration notes that could not be read") is a framework defect, not
this project's: file it (step 5) and read the file by hand anyway.

## Step 4. Read every migration note, in the order given

A note applies because the project resolves a package below the version the note's `affects` names.
Each note says who is affected, what to change and how to check it. They are listed oldest first, and
that is the order to apply them in: a project several releases behind may be carrying two changes to the
same call site.

**Before editing, find out whether this project is actually affected.** `affects` puts a note in front
of you by version; whether the code uses what changed is a `grep`. A note that turns out not to apply is
a normal outcome — say so and move on.

A change to the skeleton alone reaches an existing project only through a note (keyed to `dartway_cli`):
a project keeps its copy of what `dartway create` gave it, so such a note is the whole delivery.

## Step 5. Make the edits

Apply what the notes ask for, one note at a time, and keep them separable in the diff. Use the project's
own conventions — the note says *what* has to change, not how this project writes code;
`dartway-clean-code` and the layer skills still decide that.

**Where a note and this project disagree, stop and ask.** A note is written for the general case, and a
project that has done something deliberately different is exactly the case its author could not see. Do
not invent a third way silently.

**Findings about the framework go to `__NOTES_TRACKER__`**, as they always do: a note that is wrong,
incomplete, or missing for a change that clearly needed one is a framework defect, and it is worth more
filed than fixed locally.

## Step 6. Move the packages

Only now, and by the source `dartway update` named for each.

**The core family moves in lockstep.** `dartway_core_shared`, `dartway_core_server`,
`dartway_core_flutter`, and the packages released with them — `dartway_client` (a dev dependency of the
Flutter package, for the in-memory server) and `dartway_generator` (a dev dependency of the server
package) — carry one version. Raise **every** caret of the family in **every** package to the same
version, in one change:

```yaml
# __SHARED_PKG__/pubspec.yaml
dependencies:
  dartway_core_shared: ^<version>
# __SERVER_PKG__/pubspec.yaml
dependencies:
  dartway_core_server: ^<version>
dev_dependencies:
  dartway_generator: ^<version>
# __FLUTTER_PKG__/pubspec.yaml
dependencies:
  dartway_core_flutter: ^<version>
dev_dependencies:
  dartway_client: ^<version>
```

Then `dart pub get` in `__SHARED_PKG__` and `__SERVER_PKG__`, `flutter pub get` in `__FLUTTER_PKG__`.

- **Why together:** the app and the server speak the wire of the family they resolve. Halves on
  different releases fail at runtime, not at compile time — as `426` "update the app" when the protocol
  version differs, or as a field one side does not know. And the generator must match the core it
  generates for.
- **Under a `0.x` version a minor behaves like a major**: `^0.20.0` does not admit `0.21.0`, so the
  caret has to move. Lowering a caret to make something resolve is never the fix.
- **From git** instead of pub: `dart pub upgrade <the dartway packages>` in each directory
  `dartway update` named. A git dependency is pinned when it is added and stays there until something
  upgrades it *by name*, so upgrading one package at a time is how a project ends up running two
  framework releases against each other. `dart run dartway_cli:dartway check` reports that state as `frameworkRefsDiverged`.

**Satellites move on their own.** `dartway_router` (arrives through `dartway_core_flutter`),
`dartway_lints`, `dartway_shared_preferences`, `dartway_studio_bridge`, `dartway_telegram`,
`dartway_cli` (a dev dependency of the Flutter package) are versioned independently: raise the caret of
the ones `dartway update` lists as behind, each to its own version. The core family raises its own
constraint on a satellite only in its next minor; a project that needs a newer satellite sooner uses
`dependency_overrides` — and removes the override once the family's constraint admits that version, or
it outlives its reason silently.

## Step 7. Regenerate and prove it

In this order, because each answers a question the next cannot:

```bash
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway generate) # the generator moved with the family
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway generate --check)
(cd __SERVER_PKG__ && dart run bin/migrate.dart check)     # against the local database: migrations still produce the schema
(cd __SHARED_PKG__ && dart analyze && dart test)
(cd __SERVER_PKG__ && dart analyze)
(cd __FLUTTER_PKG__ && dart analyze --fatal-infos)
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway test)
(cd __FLUTTER_PKG__ && flutter test)
(cd __FLUTTER_PKG__ && dart run dartway_cli:dartway check)
```

- **Regenerate even when no DTO or row class changed.** Generated codecs, the protocol registry and the
  schema are written by the generator the project now resolves; `dart run dartway_cli:dartway check` reports a stale tree as
  `generatedCodeStale`, and the codecs are the wire. Commit what it writes.
- **The framework's own migrations are applied by the server as it starts** (the `dw` namespace) —
  nothing to write in the project. `migrate check` and `dart run dartway_cli:dartway test` replay them together with the
  project's, which is what proves they agree.
- **Then run the app** (`dartway-run`): an update can be green everywhere and still land on a blank
  screen, because what changed was a default or a wiring step rather than an API.

**Say whether the protocol version moved.** Compare `dwProtocolVersion` in the `dartway_core_shared`
the project resolved before the update and after. When it changed, app builds already installed on
phones get `426` from the updated server and show "update the app" — so the server and the new app
builds have to go out together, and whoever releases this project needs to know before merging.

## Step 8. Commit

`.claude/` is committed with the rest — it is a generated-but-committed artifact, and its history is what
says which skills the code was written with.

One commit per concern, and the update itself is one:

```
chore(deps): move to dartway <version>, applying <n> migrations
```

Say in the body which migration notes were applied and which were read and found not to apply. The next
person doing this update on another project reads that as the first data point.

## Step 9. Report

- toolkit: what was installed, from which channel and commit;
- packages: what moved, from what to what — the family's one version, each satellite's;
- migration notes: applied · not applicable · **left undone, and why** — an update stopped halfway is a
  legitimate outcome and a dangerous silence;
- protocol version: moved or not, and what that means for installed apps;
- checks: what is green, and what was already red before this started;
- anything filed to `__NOTES_TRACKER__`.
