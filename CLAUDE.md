# DartWay — the framework monorepo

This is the repository of **the DartWay framework itself** (fullstack Dart: Flutter + Serverpod), not of an application built on it. The methodology for applications lives in `toolkit/` and is installed into their `.claude/` by the installer — do not confuse the two CLAUDE.md files: this one is about developing the framework.

## Monorepo map

| Folder | Role |
|---|---|
| `packages/dartway_serverpod_core/` | The core (4 packages: server / client / flutter / shared) — generic CRUD, real-time, auth, filters |
| `packages/dartway_flutter` | The Flutter toolbox (application skeleton): DwAppRunner, guarded actions (`dw.action`), the async-UI contract, notifications, error reporting, `DwPlugins`. Ships no design |
| `packages/dartway_shared_preferences` | Local-storage plugin: reactive riverpod providers over SharedPreferences, reached through `dw.plugins.prefs`. Optional — the core does not pull it in |
| `packages/dartway_lints` | Convention enforcement (custom_lint rules) |
| `packages/dartway_router` | Navigation: an opinionated wrapper over `go_router` — zones, route descriptors, typed parameters. Depends on nothing of ours (`flutter` + `go_router`), and lives here anyway: `template/` ships it, `example/` uses it and `toolkit/skills/dartway-navigation` teaches its API. Published from here, as everything is |
| `packages/dartway_cli` | CLI: `quickstart` (the agent-facing setup brief — the framework's front door) / `doctor` (prerequisite checks) / `create` / `setup-ai` / `check` (the built-in convention checker) / `stats` / `deploy` |
| `template/` | **The skeleton** — the only thing `dartway create` copies. Auth, roles, navigation, admin panel, UI kit, zero domain models. Packages named `dartway_starter_*` (the CLI renames them to the project's name) |
| `example/` | The canonical project (a fitness club) — reference example, course project, Studio demo. **The CLI no longer hands it out**: read it, do not inherit from it |
| `toolkit/` | The Claude harness for application projects (`dartway-*` skills, `__*__` tokens, the installer) |
| `docs/` | Framework documentation and the single source of content for the dartway.dev site (see "Neighbours") |
| `packages/dartway_push/` | Push notifications, optional and in five packages: the Serverpod module (`_server` + `_client`) holding the delivery queue, and the app half — `_flutter` (the `dw.plugins.push` plugin, no vendor SDK) with the `_firebase` and `_rustore` transports beside it. The two halves are held together by the wire keys of the data payload, pinned by a test on each side |
| `packages/dartway_studio_bridge` | The open bridge between an application and Studio: screen-spec models (in the application's code) plus the runtime postMessage protocol (host in the application, client in Studio) |
| `js/studio-bridge` | The same bridge's application half for JavaScript apps (`@dartway/studio-bridge` on npm: core + React and Vue bindings). **Outside `packages/`**: that tree is the pub workspace (`packages/*`), and while pub does skip a folder without a `pubspec.yaml`, a JS package has no business sitting inside a Dart resolution. A second implementation of one protocol: it is held to the Dart one by golden wire strings in its tests, not by a shared schema |

This repository is self-contained: everything it holds lives here. There are no foreign repositories nested in the tree.

## Neighbours

Two separate repositories that adjoin the framework without being part of it. If checkouts exist on the machine, they sit beside this tree, not inside it.

| Repository | What it is | Relation to the monorepo |
|---|---|---|
| `dartway/dartway_studio` | **DartWay Studio** — the closed platform: live preview, screen passports, later feedback and agents | A consumer of `packages/dartway_studio_bridge`. The bridge is a contract with two sides: change the bridge and the Studio side has to catch up |
| `novikov-it/dartway.dev` | The documentation site (Docusaurus → GitHub Pages) | A consumer of `docs/`. **Note:** the `docs/` → site pipeline is not wired up yet; the site still pulls its content from the legacy `dartway_guidelines` repository |

Keeping them in sync is neither this repository's duty nor a reason to reach into someone else's tree. When you change the bridge or the docs, say so in your report; they will catch up on their own or on request.

## The synchronisation law (Definition of Done)

The monorepo exists so that its parts evolve together. A change to the **public API** of any package is not finished until the same PR also updates:

1. `example/` — compiles and uses the new API;
2. `template/` — compiles (this is what every new project receives; a rotted template is a broken `dartway create`, and you will hear about it from a stranger);
3. the affected skills in `toolkit/skills/` (a skill that has fallen behind the API is worse than a missing one — the agent confidently writes code that does not work);
4. `docs/` — the affected pages;
5. the package's `CHANGELOG.md`;
6. **the carets on that package in `example/` and `template/`, whenever the change bumps its version.** A minor bump of a `0.x` package puts it outside its own caret — `^0.6.0` means `>=0.6.0 <0.7.0`, so a package at `0.7.1` no longer satisfies the constraint the skeleton states for it. Nothing tells you: both trees carry a `dependency_overrides` block pointing at the local packages, and **for an overridden package pub does not check constraints at all** — the unsatisfiable line resolves quietly for as long as the block is there. `dartway create` then strips the block on the way out (deliberately — those paths do not exist in someone's project), and the constraint is finally read for the first time in a stranger's tree: either the resolution fails outright, or it succeeds against an older minor than the skeleton was written against. This is not hypothetical — it is how `dartway_studio_bridge` and `dartway_cli` sat one minor behind their own carets on master while five sibling packages were kept in step.

**The promotion ritual for `stable` now includes the template:** analyze/tests green + **example and template both build** + `dartway create` from a fresh clone produces a project that runs + `framework-finish` reporting no drift.

Run the `framework-finish` skill before committing framework changes — it looks for drift across the diff.

## Standards

- **Versioning:** semver. The four `dartway_serverpod_core_*` packages move in lockstep (one version across all four). Every other package is versioned independently.

  **A version is the number of the next release, not a count of pull requests.** It moves once per release cycle per package, and whether *this* PR is the one that moves it has a mechanical answer — compare the package's `version:` on `master` with the same line on `stable`, which is where releases are cut from:

  ```bash
  git show origin/stable:packages/<pkg>/pubspec.yaml | grep -m1 '^version:'
  ```

  - **the two are equal** → this change moves it, by whatever semver says the change is;
  - **master is already ahead** → the pending release carries a bump already. Leave `version:` alone, leave the carets alone, and add your entry to that version's section in the `CHANGELOG.md` rather than opening a new one.

  **What is already pending sets the floor, not the answer.** A pending `0.8.1` in front of a breaking change becomes `0.9.0` — under a `0.x` major a minor is what a major is elsewhere, so the escalation is the one case where a version moves twice in a cycle.

  Without this, twenty fixes in a week are twenty minors: the number stops meaning anything the `CHANGELOG` does not say better, and each step drags the caret updates in `example/` and `template/` along with it (see the synchronisation law, point 6) — twenty chances to get that wrong in exchange for nothing.
- **Workspace hygiene:** inside the monorepo, dependencies between packages resolve through the workspace (the root `pubspec.yaml`), **not** through git references to `dartway.git`.
- **The Serverpod version is `3.4.11`, and all generated code was produced by that same CLI version.** Before you generate (`serverpod generate` / `create-migration`), confirm that `dart pub global list` reports **exactly** that version: the CLI writes generated code for its own version, and a CLI that has drifted from the runtime produces silent bugs. Constraints: **framework packages use a caret** (`^3.4.11`) so they stay compatible with whatever serverpod patch an application has (an exact pin in a library makes it uninstallable next to someone else's patch); **`template/` uses an exact pin** so a new project starts on a combination known to match the generator. Build reproducibility across the monorepo is held by the committed `pubspec.lock`, not by narrowing constraints. Bumping serverpod means regenerating in **four** places (the core, the push module, example, template), verifying the protocol patch, and regenerating the aggregated migrations for example and template.
- **Language: everything that can end up in front of people is written in English.** One test decides it: **would an outsider see this by opening GitHub?** If yes, English — no exceptions, and regardless of whom it is addressed to.
  - The rule covers: docs, package READMEs, error strings, comments in package code, **commit messages, PR titles and descriptions, PR and issue comments, branch names** — and **`toolkit/` as well**: it ships into the `.claude/` of every project built on the framework and sits in a public repository, so it is already in front of people.
  - **This file too.** It is the repository's constitution, and outside contributors are held to it — the automated review enforces the synchronisation law, the protocol patch, and the toolkit invariant on their pull requests. Rules that judge a contributor have to be readable by that contributor.
  - **A conversation held in Russian does not make the artefact born from it Russian.** A PR description addresses Evgenii, yet it sits in a public repository and anyone reads it — that is publication, not a continuation of the conversation. This substitution is exactly how the rule got broken once already.
  - Russian remains only where an outsider never reaches: the private project-management repository and our chat.
  - Which language a project uses for **its own** feature passports and docs is that project's business — a project setting, not ours.
- **Commits:** conventional commits — `feat:` / `fix:` / `chore:` (an optional scope is welcome: `feat(session): ...`).
- **Git — see "Working with git"** below: branches, PRs, promotion to `stable`, parallel sessions.
- **The toolkit invariant:** `toolkit/` carries no project literals, only `__*__` tokens — it ships into the `.claude/` of every project on the framework, so a name borrowed from whichever project you happened to be looking at arrives in all of them. Held by reading the diff, not by a grep: a pattern listing the projects we remember today passes the leak that comes from the next one, and the only greppable form of it matched its own documentation.
- **Archives:** the `zarchive/`/`zarchiv/` folders are legacy awaiting removal; add nothing new to them, and when refactoring delete rather than extend.
- **Where a package lives, and how it is distributed, are two questions.** Everything of ours lives **here**; publishing to pub.dev under its own name and its own version is a separate matter and stays that way. There is no lifecycle step where a package graduates into a repository of its own.

  The test is not "does anything import it". `dartway_router` imports nothing of ours and was moved out on exactly that reading — while `template/` shipped it, `example/` used it and `toolkit/skills/dartway-navigation` taught its API. **What binds a package to this repository is the synchronisation law**, and three of the four mirrors it names — `example/`, `template/`, the skills — are not imports at all.

  So, in the checkable form: **a package whose API is taught by a skill in `toolkit/`, or that `template/` hands to a new project, belongs in this repository.** A skill that has fallen behind its package is worse than a missing one, and across two repositories they cannot land in one pull request — which is what the law asks for. The cost is not hypothetical: a silent bug on the main navigation path (`isActive` under a parameterized parent) had to wait for another repository, its release, and a caret bump here.
- **Security principle (the goal):** generic CRUD must be secure by default — access not configured ⇒ access denied. New code must not introduce "open to everyone" as a default.
- **Public API design lives in `docs/DESIGN.md` (law, not preference).** Before adding or changing a public symbol in any package, check it against: a single root, `dw.` for the core and `dw.plugins.<name>` for extensions; the "factory on `dw.` vs constructor on the type" test (three questions); one way to do a thing, not two; the core is a minimal contract (anything optional belongs in a plugin); validate against real projects (tvolkova/kerla3) rather than against the demo, and mind where a symbol came from. A package may carry its own `DESIGN.md` (for example `packages/dartway_flutter/DESIGN.md`) — **do not confuse the framework's philosophy with a package's**.

## Working with git

The rules are the same for everyone — for Evgenii, for Claude, for outside contributors. The repository is public and its history is part of the product.

**Branches.**

| Branch | Role |
|---|---|
| `master` | The development trunk. May be in pieces at any moment |
| `stable` | The last verified state. **Fast-forward from master only**, a history of its own is forbidden. Setup scripts and the CLI (the default channel) follow it, as do the git dependencies of external projects |
| `feat/*`, `fix/*`, `chore/*`, `docs/*` | Working branches. They live until merged, then they go |
| `kerla*`, `tvaity` | Project slices for specific applications. They are never merged into master, they live their own life, **do not delete them** |

No gitflow — no develop branch, no release branches.

**Code reaches master one way only: through a branch and a PR with squash merge.** On GitHub that is the only method left enabled — merge commits and rebase are off, so one PR equals one commit on master. Nobody pushes to master directly, for anything: changes to `docs/` and `toolkit/` travel by branch too. A single rule is cheaper than a threshold you have to reason about every time. A one-line fix closes in two steps: `gh pr create --fill` → `gh pr merge --squash`.

**The consequence that is easy to forget: a squash merge turns the PR title into the commit message on `master`.** The PR title is therefore not a caption on a discussion but a line of permanent public history — hence the requirement to write it in English (see "Language"). It cannot be corrected afterwards: `protect-trunk` forbids force-pushing the trunk, and the protection is not worth disabling for cosmetics. One such commit is already stuck in the history — `b9917ab`.

**Create the branch at the start of the task, not at the end.** Otherwise `framework-finish` inspects a dirty master instead of the branch's diff, and parallel work becomes impossible in principle.

**Parallel sessions run in `git worktree` and nowhere else.** Two sessions sharing one working directory share the index and the working tree, which means they overwrite each other; a branch split off at the end does not separate them. One session = one branch = one directory:

```bash
git worktree add ../dartway-wt/<slug> -b feat/<slug> master
```

Keep the worktree directory **outside** the repository tree. The price: every worktree carries its own `.dart_tool` and its own `dart pub get` across the workspace, and a session that runs `example` has to move its ports off the neighbour's. Create a worktree for genuinely parallel work, not for every task.

### Claude's protocol (hard rules)

These are not suggestions: each item closes off a way for one session to destroy another's work.

1. **`git status` first, before anything else.** Clean tree ⇒ `git switch -c <type>/<slug>` and work here. Dirty tree ⇒ **another session is already working in it**; do not work in the shared directory at all — create a worktree and move there. Asking whose changes those are is not an option: while the conversation happens, the other session keeps writing.
2. **In a shared tree holding someone else's changes, these are forbidden:** `git switch`, `git checkout <branch>`, `git stash`, `git reset`, `git restore`, `git clean`. Every one of them swaps files out from under a running session. The single exception is a switch where `git diff --name-only <from> <to>` is empty or lists only your own files — verified **before** the switch, not after.
3. **Stage your own files, by name:** `git add <path> <path>`. **`git add -A`, `git add .` and `git commit -a` are forbidden, always** — in a shared tree they silently drag someone else's unfinished work into your commit, and undoing that takes `rebase --onto`.
4. **Create the branch at the start of the task, not at the end.** While a branch has no commits, any collision between sessions is resolved by splitting files; after the first foreign commit lands on your branch, only `cherry-pick` and manual surgery remain.
5. **Never branch from someone else's HEAD.** Branch from an explicit point: `git switch -c <name> master`. Otherwise a foreign commit rides into your PR.
6. **Push and open PRs only when asked directly.** Never merge a PR, never push to `master` directly, never touch `stable` without an explicit instruction.
7. **Before offering a PR** — `framework-finish`, analyze and tests all green.
8. **Clean up your worktree:** `git worktree remove ../dartway-wt/<slug>` once the branch is merged. Abandoned worktrees hold branches checked out, and the next session cannot switch to them.
9. **Everything that travels to GitHub is written in English:** branch name, commit message, PR title and description, PR comments. Re-read the title before `gh pr create` — it becomes a commit on `master` and is not editable afterwards. That the task was discussed in Russian makes no difference — see "Language".

**The promotion ritual for `stable`:** analyze/tests green + **example and template both build** + `dartway create` from a fresh clone produces a project that runs + `framework-finish` reporting no drift → `git push origin master:stable`. We keep no local `stable` branch — promotion travels by refspec, and a stale local copy only confuses matters.

**Protection.** `master` and `stable` are covered by the `protect-trunk` ruleset: force-pushes and deletion are forbidden, with no bypass. A fast-forward push (promotion included) goes through normally. Needing to rewrite the trunk's history is a reason to stop and discuss, not to switch the rule off.

**Hygiene.** A branch is deleted automatically when its PR merges (`deleteBranchOnMerge`). Locally: `fetch.prune=true` (dead remote references stop piling up), `pull.rebase=true`, `rerere.enabled=true`. In this repository `user.email` is set locally to the work address, because the repository is public.

### CI

Three workflows in `.github/workflows/`:

| File | When | What it does |
|---|---|---|
| `claude-review.yml` | A PR is opened, updated, or taken out of draft | Reviews the diff automatically. Beyond ordinary bugs it checks three things specific to this repository: the synchronisation law, the presence of the hand-written `manualDeserialization` patch in the generated `protocol.dart`, and the absence of project literals in `toolkit/` |
| `telegram-notify.yml` | A review finishes | Sends the verdict and a link to the PR to Telegram — the one notification that asks for a decision. Signals meant for the team (merges, promotion to `stable`) are deliberately absent: that is a separate task addressing a different audience |
| `web-compile.yml` | A PR is opened or updated, and on push to `master` | Builds the web targets (`example/` and the `dartway_offline_flutter` harness). dart2js rejects code the VM accepts — an integer literal a JavaScript double cannot hold exactly is the standing case — and **unit tests on the VM cannot see that class of error at all**. A package no example and no template depends on is compiled nowhere else, which is how two such literals reached a consumer's release build |

The review does not run on PRs from forks: repository secrets are unavailable to them and the step would fail on authentication anyway. Such a PR also goes unannounced — every current contributor is a collaborator pushing branches into the repository, so the case is theoretical for now.

The review needs **two** things, not one. The `CLAUDE_CODE_OAUTH_TOKEN` secret (issued by `claude setup-token`) authenticates, while the right to write to the repository comes from the **[`claude` GitHub App](https://github.com/apps/claude)** installed on this repository. Without the app the OIDC token exchange fails with `401 — Claude Code is not installed on this repository`, even when the secret is in place.

The remaining secrets (Settings → Secrets and variables → Actions): `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`. Without them notifications stop; the review keeps working.

`workflow_run` is read from the default branch only — a change to `telegram-notify.yml` takes effect once merged into `master`, not in the PR that makes it.

## The trap: `serverpod generate` in the core erases a hand-written protocol patch

**This one is for Claude — Evgenii does not run generation.** Having run `serverpod generate` in `packages/dartway_serverpod_core/dartway_serverpod_core_server`, you are required to check and restore the patch in the generated `dartway_serverpod_core_client/lib/src/protocol/protocol.dart`.

**What the patch is.** Inside `Protocol.deserialize<T>`, immediately after `t ??= T;`, this block must be present:

```dart
if (data is Map<String, dynamic>) {
  final manualDeserialization =
      _iNN.DwApiResponse.manualDeserialization<T>(data);
  if (manualDeserialization != null) {
    return manualDeserialization;
  }
}
```

`_iNN` is **the import alias for `dw_api_response.dart` in the freshly generated file**, not a constant: the number changes from one generation to the next (currently `_i19`). Take it from the file's header rather than copying blindly.

**Why everything falls apart without it.** Serverpod's `extraClasses` does not understand generics: for `DwApiResponse<T>` the generator emits a check against the **raw** type — `if (t == _i19.DwApiResponse)`, meaning `DwApiResponse<dynamic>`. What actually arrives over the wire is `DwApiResponse<DwModelWrapper>`, `<List<DwModelWrapper>>`, `<int>`, `<bool>` — as a `Type` none of them equals the raw one, the branch therefore **never** fires, and every CRUD response fails to deserialise. The patch routes the call to `DwApiResponse.manualDeserialization<K>`, which unpacks the concrete instantiations by hand.

**The check to run after generating:**

```bash
grep -n 'manualDeserialization' packages/dartway_serverpod_core/dartway_serverpod_core_client/lib/src/protocol/protocol.dart
```

Empty output means the patch is gone and the application is broken at runtime — while still compiling, which is what makes it treacherous. Restore it, then confirm that example starts up and loads its lists.

Defusing the mine for good (queued, not done): an idempotent patcher script plus a regression test in `core_client` that turns red when the patch is missing. The radical option is to take generics off the wire, but that means reworking the CRUD endpoints, and Serverpod is being removed after v1 anyway.

## Workflow

A task arrives from outside — from the tracker or in conversation. What remains here is the work on the code: a branch for the task, the change, `framework-finish` before committing, the commit, and a PR when asked (see "Working with git").

Project management — strategy, roadmap, the task queue, board coordinates — lives **in a separate repository** (`dartway/dartway_manager`) and is not kept in this monorepo. It used to be mounted as a `project/` folder and read by a `/next` command; both the folder and the command are gone: the framework repository deals with the framework.
