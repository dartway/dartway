---
name: framework-finish
description: The synchronisation audit to run before committing a change to the DartWay framework — checks that a public API change is reflected in example/, template/, toolkit/skills/, docs/ and the CHANGELOG, that a change asking projects to edit their own code carries a migration note in docs/migrations/, and that a bumped package version still satisfies the carets stated for it in example/ and template/. Run it once the package code is done, before the commit or the PR.
---

# framework-finish — the monorepo synchronisation audit

The DartWay monorepo lives by the synchronisation law (see the root `CLAUDE.md`): the public API, `example`, **`template`**, the toolkit skills and the docs evolve together, in one pull request. This skill catches the drift across a diff — and, in step 5, the one mirror that lives outside this repository: the projects built on the framework, which learn what they owe from `docs/migrations/` or not at all.

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

### Step 4b. Ask the repository whether it is what it says it is

Three of the facts this repository states about itself are copies of something else, and a copy goes stale in silence:

- **the lockfiles** record a version for each path-overridden local package, written by whichever `pub get` ran last — stale ones dirty every working tree on the next resolve, and a tree that dirties itself makes "dirty means another session is here" meaningless (#192, #172);
- **the carets** in `template/`/`example/` are compared, everywhere else, against the **local** `packages/*/pubspec.yaml` — and those two move in the same pull request, so that comparison is green exactly when the skeleton has become uninstallable for a stranger (#143);
- **the git settings** `CLAUDE.md` names live in `.git/config`, per clone and per machine, and nothing sets them or notices they are missing (#170).

One command asks all three:

```bash
dart run tool/self_check.dart            # everything
dart run tool/self_check.dart --offline  # skip the check that needs pub.dev
```

**Its exit code has three values, and the third is the point:** `0` clean, `1` something is not what we say it is, `2` a check could not be carried out — pub.dev unreachable, most likely. A check that could not run is not a check that failed; reporting the two the same way is how people learn to skim a gate.

**What a finding means differs by check, so read the summary rather than the count.** A stale lockfile is fixed by `flutter pub get` and a commit. A missing git setting is fixed by the `git config` line it prints, and it is yours alone — setting it here sets it for nobody else. **A caret finding is not fixed by editing the caret:** it means the packages are not published yet, which is a release decision. Report it and name the packages that lag.

This is deliberately not in `tool/checks.sh`, and therefore not in CI: two of the three would be red on every runner by construction — a fresh clone has none of the git settings, and the carets are unsatisfied for as long as a release is pending. A gate that is red by design is a gate people stop reading.

## Step 5. Does a project on the framework have to change?

The mirrors above keep this repository consistent with itself. This step is the only one addressed
outward — to an application that is **behind**, and whose author will read what you write here
weeks from now with none of today's context.

**The test: would an application on the framework, doing nothing wrong, have to touch its own code
because of this change?** If yes, the change is not finished until `docs/migrations/` holds a note
saying what to do. If no, write nothing — a note that asks for nothing teaches people to skim the
ones that do.

Yes for: a public symbol renamed, removed or re-signatured; a required parameter added; a changed
default that alters behaviour a project relies on; a new mandatory wiring or initialization step; a
schema change a project inherits through `create-migration`; a package that has to be declared
where it did not before.

No for: a fix that only makes an existing call work; anything private; a new capability a project
may adopt whenever it likes.

**Why this is a step and not a habit.** The author of a change is the last person able to see it as
a stranger would, and the only one who still knows what they broke — a week later that knowledge is
gone from everywhere except the diff. Between 2026-08-22 and 2026-09-05 six changes needed a note
and none was written; they were reconstructed afterwards out of the changelogs, which worked only
because the changelogs happened to be unusually good.

The form, and what `affects` means, is `docs/migrations/README.md`. Two things to get right:

- **`affects` is the mechanism, not decoration.** It names each package with the version the change
  lands in, quoted. That is what decides which projects are shown the note; a version that never
  arrives is a migration that never becomes due, and `migration_notes_test.dart` fails on it.
- **Write the edit, not the news.** The `CHANGELOG` entry says what happened and is written for a
  reader; the note is read by someone who has to change a line and wants to know which one. They
  are two texts, and the note is usually the shorter.

## Step 6. Report and fix

Give the drift as a list in the form `<API change> → <mirror> → <what exactly is stale or missing>`. If there is none, say so in one line.

Propose concrete edits. **Apply only the confirmed ones** — except the trivial ones (a CHANGELOG entry, a method name corrected in a skill), which you may apply straight away, listing what you applied.
