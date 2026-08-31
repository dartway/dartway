---
name: framework-finish
description: The synchronisation audit to run before committing a change to the DartWay framework — checks that a public API change is reflected in example/, template/, toolkit/skills/, docs/ and the CHANGELOG, and that a bumped package version still satisfies the carets stated for it in example/ and template/. Run it once the package code is done, before the commit or the PR.
---

# framework-finish — the monorepo synchronisation audit

The DartWay monorepo lives by the synchronisation law (see the root `CLAUDE.md`): the public API, `example`, **`template`**, the toolkit skills and the docs evolve together, in one pull request. This skill catches the drift across a diff.

## Step 1. Collect the diff

```bash
git diff <base>...HEAD --stat        # plus anything uncommitted: git status, git diff
```

The base is `master` unless told otherwise. What matters is what changed under `packages/`.

## Step 2. Decide what counts as a public API change

A package's public API is what it exports: the files reachable through `lib/<package>.dart` and whatever `lib/src/...` re-exports outward. It is an API change when there is:

- a new, removed or renamed public class, method, parameter or extension;
- a changed signature, or changed behaviour, of a public method;
- a changed default in a config (`DwCrudConfig`, `DwSaveConfig`, `DwAuthConfig`, …);
- a new mandatory initialization step (`DwCore.init`, `setupRepository`, …).

Purely internal edits — private code, a refactor with no behaviour change, `zarchive/` — are not API.

## Step 3. Check the mirrors

For each API change, check whether it is reflected in:

| Mirror | What to look for |
|---|---|
| `example/` | Does example use the API that changed; does it compile; does it demonstrate the new capability |
| `template/` | **Does the skeleton compile.** This is what every new project receives through `dartway create`; nobody runs the template day to day, so it rots quietly and you hear about it from a stranger. If the change touched auth, roles, navigation, the admin panel, the UI kit or `DwCore.init`, the template is almost certainly affected |
| `toolkit/skills/` | grep for the old names and signatures in `toolkit/skills/*/SKILL.md` and `toolkit/CLAUDE.md` — a skill must not teach an agent an API that is gone |
| `docs/` | grep for the concepts involved — a page must not contradict the code |
| the package's `CHANGELOG.md` | Is there an entry under the current (unreleased) version |

**The mirror outside this repository.** Change `packages/dartway_studio_bridge` and you have changed one side of a contract whose other side lives in a separate repository (`dartway/dartway_studio`). The folders are no longer neighbours, so this item is the only thing holding the check:

- a field added to a bridge model → Studio has to show it, or it arrives and disappears;
- a field removed or renamed → Studio breaks on parsing.

If a checkout of Studio exists on the machine, look and say what needs fixing there. If it does not — **say so as an explicit line in the report**: "the bridge changed, the Studio side was not checked". Passing over it in silence is not allowed: bridge drift is caught by neither the compiler nor the checker, and it surfaces as an empty panel in Studio.

The same applies to `docs/` and the site, but more gently — the site is a consumer and collects the content itself.

Quick additional checks:

- **the toolkit invariant:** the diff under `toolkit/` carries no literals from a specific project, only `__*__` tokens. There is deliberately no grep for this: a pattern listing the projects we remember today will not catch the leak that arrives from the next one, and the previous grep found precisely its own documentation. Read it with your eyes — a name that means something in exactly one project has to be a token or an invented example;
- **the skeleton invariant:** `template/` holds no domain models — `grep -riE 'club|booking|chat|news|fitness' template/ --include=*.dart --include=*.spy.yaml` comes back empty. Domain leaks into the skeleton unnoticed (a widget copied out of example brings `ClubSession` with it);
- **the template's migrations and generated code are under version control** (`git ls-files template/dartway_starter_server/migrations/ | head -1` is not empty). They were in `.gitignore` once, and for months `dartway create` handed out a project that would not start: the folder was there locally and missing from the clone;
- no new files under `zarchive/`/`zarchiv/` sneaked into the diff;
- new user-facing strings in the core are in English;
- new access configs do not introduce "open to everyone" as a default.

## Step 4. Constraints against package versions

**This step runs every time, not only when the API changed.** Its trigger is the package's version rather than its public symbols: bump `version:` and the carets on that package in `example/` and `template/` may have stayed on the previous minor.

**First check whether the bump was warranted at all** (root `CLAUDE.md`, "Versioning"): a version is the number of the next release, not a count of pull requests, and it moves once per release cycle. `git show origin/stable:packages/<pkg>/pubspec.yaml | grep -m1 '^version:'` — equal to master and this PR moves it; master already ahead and the pending release carries a bump, so a second one is a finding rather than the norm. The one exception is escalation: a breaking change in front of a pending patch raises the minor.

Why this is not caught on its own: both trees hold a `dependency_overrides` block pointing at the local packages, and **for an overridden package pub does not check the constraint at all**. An unsatisfiable line resolves in silence for exactly as long as the block is there. `dartway create` strips it — and the constraint is read for the first time, for real, in a stranger's tree.

The check is mechanical and takes a minute:

```bash
grep -H '^version:' packages/*/pubspec.yaml packages/*/*/pubspec.yaml
grep -nE '^\s+dartway_[a-z_]+:\s*\^' template/*/pubspec.yaml example/*/pubspec.yaml
```

For each package in the first list, find the carets on it in the second and check that the version satisfies them. **The trap is what a caret means for `0.x`:** `^0.6.0` is `>=0.6.0 <0.7.0`, not "0.6.0 and newer". A package at `0.7.1` does **not** satisfy its own `^0.6.0`; under a zero major, a minor behaves like a major. That is exactly how `dartway_studio_bridge` and `dartway_cli` fell a minor behind their own carets while five sibling packages were kept in step.

A mismatch is **a line in the report** of the form `<package> <version> → <file>:<line> ^<constraint>`, and it is fixed by raising the caret to the current version's minor. Packages that simply are not in `template/`/`example/` (`dartway_telegram`, the push transports) are not a finding.

### And pub.dev has the last word

Both checks above read the tree. Neither can see the thing that actually breaks a stranger: the caret in `template/` is compared with the **local** `packages/*/pubspec.yaml`, and those two move in the same pull request. The check is therefore green in exactly the situation that hurts — local version 0.12.0, caret `^0.12.0`, pub.dev 0.11.0 — because `dependency_overrides` mean pub never reads the constraint here at all, and `dartway create` strips the block on the way out.

```bash
dart run tool/caret_check.dart
```

It asks pub.dev for each `dartway_*` the skeleton depends on and names every caret the published version does not satisfy, with the file and line. **Its exit code has three values, and the third matters:** `0` all satisfied, `1` findings listed, `2` pub.dev could not be asked. A lost connection reported as a finding would read as "the release is broken" and be believed, so it is kept separate.

A finding here is not fixed by editing the caret — it is fixed by publishing, which is a release decision. Report it and say which packages lag.

### The lockfiles say a version too

The carets are not the only copy of a package's version outside its `pubspec.yaml`. Every committed `pubspec.lock` records one for each path-overridden local package, and that copy is written by whichever `pub get` ran last — nothing keeps it in step with a bump. It is checked in one command:

```bash
dart run tool/lock_check.dart
```

It names every lockfile whose recorded version disagrees with the package's own, and exits 1. The fix it prints is the fix: `flutter pub get` in each tree it named, then commit the lockfile.

**Why it earns a step of its own rather than a mention.** A stale lock breaks nothing at runtime, so nothing ever fails because of it. What it does is dirty the working tree: the next `pub get` in any tree rewrites the file, and `git status` comes back modified in a tree where nobody touched it. `CLAUDE.md` makes a clean tree mean "another session is working here" — it is the first rule of Claude's git protocol — so this noise is read as the alarming thing, and it puts the forbidden `git add -A` back in reach. Two locks sat a minor behind for a whole release cycle exactly this way (#192).

## Step 5. Report and fix

Give the drift as a list in the form `<API change> → <mirror> → <what exactly is stale or missing>`. If there is none, say so in one line.

Propose concrete edits. **Apply only the confirmed ones** — except the trivial ones (a CHANGELOG entry, a method name corrected in a skill), which you may apply straight away, listing what you applied.
