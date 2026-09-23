# DartWay — the framework monorepo

This is the repository of **the DartWay framework itself** (fullstack Dart: a `dart:io` server, a Flutter app, and one shared contract between them), not of an application built on it. The methodology for applications lives in `toolkit/` and is installed into their `.claude/` by the CLI — do not confuse the two CLAUDE.md files: this one is about developing the framework.

## The rewrite

DartWay 1.0 is the framework rebuilt on a stack it owns end to end, on one branch (`dartway-1.0`), all at once: packages, `example/` and `template/` together; active projects move onto it in their own branches, and the release is global. "1.0" names the rewrite, not a version — the packages stay `0.x` (D-031).

`docs/1.0/` is the rewrite's own record and is not user documentation:

| File | What it is | How to read it |
|---|---|---|
| `SPEC.md` | the original specification, sections marked Decided / Proposal / Open | intent; several proposals were never built |
| `CONTRACTS.md` | the seams between packages; "Revision 2" and its "As built" notes on top | only the top section is current — the sections below it use pre-rename names |
| `DECISIONS.md` | every decision taken while building, D-001 onwards | **the latest entry wins**: many early ones were reversed |

**When the code and these documents disagree, the code is what is true, and the document is what gets fixed.** A decision taken while building is appended to `DECISIONS.md` in the same commit that implements it — never rewritten into an earlier entry.

## Monorepo map

The core family moves in lockstep (one version, `0.20.0-dev.3`, across all six); every other package is a satellite with a version of its own (D-030, D-032).

| Folder | Role |
|---|---|
| `packages/dartway_core_shared` | **Family.** The contract, pure Dart, for every side: the DTO kinds (`DwDataObject`, the request kinds, `DwActionCommand`), results and refusals, live channels, the wire protocol (`DwHttpContract`, `DwApiResponse`, `DwUpdateTransport`, live messages, `dwProtocolVersion`), the framework's own auth and file DTOs |
| `packages/dartway_core_server` | **Family.** The application server on `dart:io` (`DwAppServer`): calls per DTO over HTTP, the live update socket, handlers and access, the call context, accounts/identities/keys, idempotent commands, channels, jobs, uploads to two buckets, routes for external doors, alerts. Re-exports shared and `dartway_orm`; `testing.dart` holds `DwTestServer` and friends |
| `packages/dartway_core_flutter` | **Family.** The one framework package an app imports: `DwFlutterCore` (`dw.request` / `pages` / `table` / `window` / `command`, uploads), the app skeleton (bootstrap, `dw.action`, notifications, error reporting, features, plugins), `DwWindowListView`. Re-exports shared, `dartway_client` and `dartway_router`. Ships no design |
| `packages/dartway_orm` | **Family, internal** (re-exported by the server). Row classes, typed queries, transactions, locks, schema, migrations (`DwMigrationCli`) |
| `packages/dartway_client` | **Family, internal** (re-exported by the Flutter package). Pure-Dart client: calls, the live socket, the session, the live state of watched requests; `testing.dart` holds the in-memory `DwFakeServer` |
| `packages/dartway_generator` | **Family, dev tool.** DTO codecs and the protocol registry for `*_shared`, tables and the schema for `*_server`. A dev dependency of a project's server package, run by `dartway generate`. **Not a workspace member**: it pins its own `analyzer` (D-009) |
| `packages/dartway_router` | Satellite. Navigation over `go_router`: zones, route descriptors, typed parameters. Depends on nothing of ours, and lives here anyway (see "Where a package lives") |
| `packages/dartway_shared_preferences` | Satellite. Local storage under `dw.plugins.prefs`, and the plugin that claims the key-value store role the core keeps the session in |
| `packages/dartway_telegram` | Satellite. Telegram Mini App integration (`dw.plugins.telegram`) |
| `packages/dartway_lints` | Satellite. Convention rules for `custom_lint`; its `example/` is its suite and is not a workspace member |
| `packages/dartway_studio_bridge` | Satellite. The open bridge between an app and DartWay Studio: screen-spec models and the runtime `postMessage` protocol. The app-side binding is not ported to the rewrite yet (D-010, D-033) |
| `packages/dartway_cli` | Satellite. `dartway quickstart` · `doctor` · `create` · `setup-ai` · `update` · `generate` · `check` · `dev` · `test` · `deploy` · `stats` |
| `packages/dartway_push_*` | Push notifications, being ported to the rewrite (D-010, D-033) |
| `template/` | **The skeleton** — the only thing `dartway create` copies. Sign-in by code with consents, a profile with a photo and identifiers, roles, an admin panel, settings, a UI kit, tests on both sides, zero domain models. Packages named `dartway_starter_*` (the CLI renames them) |
| `example/` | The reference project (a fitness club: schedule, bookings, a staff chat on `DwWindowListView`, news, admin). **The CLI does not hand it out**: read it, do not inherit from it |
| `toolkit/` | The Claude harness for application projects: `CLAUDE.md` (the project constitution), `dartway-*` skills, commands, `__*__` tokens |
| `docs/` | The public documentation, the source of dartway.dev; `docs/1.0/` is the rewrite's record (above); `docs/migrations/` is addressed to projects that are behind |
| `tool/` | Scripts this repository runs on itself: `checks.sh` (the CI gate), `self_check.dart`, `caret_check.dart`, `lock_check.dart`, `git_config_check.dart`, `release.dart`, `release_notes.dart`, `vendor_framework.dart` |
| `js/studio-bridge` | The bridge's application half for JavaScript apps (`@dartway/studio-bridge` on npm). Outside `packages/`, which is the pub workspace; held to the Dart side by golden wire strings in its tests |
| `.claude/skills/framework-finish` | The synchronisation audit for changes to this repository |

This repository is self-contained: everything it holds lives here. There are no foreign repositories nested in the tree.

## Neighbours

Two separate repositories adjoin the framework without being part of it. If checkouts exist on the machine, they sit beside this tree, not inside it.

| Repository | What it is | Relation to the monorepo |
|---|---|---|
| `dartway/dartway_studio` | **DartWay Studio** — the closed platform: live preview, screen passports, feedback and agents | A consumer of `packages/dartway_studio_bridge`. Change the bridge and the Studio side has to catch up |
| `novikov-it/dartway.dev` | The documentation site | A consumer of `docs/` |

Keeping them in sync is neither this repository's duty nor a reason to reach into someone else's tree. When you change the bridge or the docs, say so in your report.

## The synchronisation law (Definition of Done)

The monorepo exists so that its parts evolve together. A change to the **public API** of any package — what its `lib/<library>.dart` exports — is not finished until the same pull request also brings along:

1. **`example/`** — compiles, uses the new API, its suites are green;
2. **`template/`** — compiles and its suites are green. This is what every new project receives; a rotted template is a broken `dartway create`, and you hear about it from a stranger;
3. **generated code** — regenerated in `example/` and `template/` wherever the change reaches the generator's input or output, and `--check` clean (see "Generation");
4. **the affected skills in `toolkit/`** and `toolkit/CLAUDE.md` — a skill that has fallen behind the API is worse than a missing one: the agent confidently writes code that does not work;
5. **`docs/`** — the affected pages;
6. **the package's `CHANGELOG.md`**;
7. **the carets**, by the versioning rules below: the family in lockstep, satellites by D-032;
8. **the wire** — a change to how anything travels bumps `dwProtocolVersion` and refreshes the wire golden (see "The wire is a protocol");
9. **`docs/migrations/`** — a note whenever the change asks a project to edit its own code, written in the same pull request, with no exemption for the rewrite (D-080). A note is shown to a project below the version it names, so such a change also **raises the version** that delivers it: the family's prerelease in lockstep (`0.20.0-dev.N`), or the satellite's own, with the carets in `template/` and `example/`. The one journey without a note is a project coming from 0.x — it is recreated on the rewrite rather than migrated (D-031).

Four of these are held by checks rather than by memory, and they are the reason the list can be trusted:

| Mirror | Check |
|---|---|
| generated code | `dartway generate --check` in `example/` and `template/`, and `generatedCodeStale` in `dartway check` |
| the wire | `packages/dartway_core_shared/test/wire_golden_test.dart` |
| names in docs, skills and these files | `packages/dartway_cli/test/docs_identifiers_test.dart` — every `Dw…` type and `dw.` member named in the prose exists in a public library; every relative link in `docs/` resolves |
| the toolkit's lists | `toolkit_skill_list_test.dart` (the skills named are the skills shipped) and `toolkit_law_list_test.dart` (the law table is the checker's error set) |

**A migration note, once releases exist** (`docs/migrations/`): the test is whether a project doing nothing wrong has to touch its own code — a renamed symbol, a required parameter, a changed default, a new wiring step, a schema change it inherits. A change that asks for nothing writes nothing. Keyed by package version rather than by commit, because the CLI reads this repository from a shallow clone with no history to diff; the form is `docs/migrations/README.md`, `migration_notes_test.dart` fails on a note naming a package that does not exist or a version that never arrives, and `dartway update` in a project reads them out.

Run the `framework-finish` skill before committing framework changes — it looks for drift across the diff.

## Generation

- **One generator, `dartway_generator`, run as `dartway generate`** — a dev dependency of the project's server package, pinned by the lock file (D-019). No global generator, no `build_runner`. The CLI finds the generator the project resolved and runs that one, so the generator always matches the `dartway_core_shared` and `dartway_orm` the project builds against.
- **It reads and writes the shared and the server package in one run** — DTO parts (`*.dw.dart`) and `lib/generated/dw_protocol.dart` in `*_shared`, row parts and `lib/generated/dw_schema.dart` in `*_server`. Regenerate both together; half a regeneration is a server whose registry disagrees with its app.
- **Generated files are never edited by hand.** The output is deterministic and formatted; a hand edit is overwritten by the next run and reported as stale by `--check` until then. The one exception proves the rule: `packages/dartway_core_shared/test/fixtures/club_booking.dw.dart` is hand-written in the generator's exact shape so the shared package tests the contract without the generator, and `packages/dartway_generator/test/dto_test.dart` regenerates it and fails on any difference — change the two together.
- **In this repository** the generator resolves inside `example/` and `template/` through their `dependency_overrides`: from a project's server package, `dart run dartway_generator --project ..` (add `--check` to verify), or `dartway generate` from the project root with a CLI activated from this tree.
- **A row class change is a migration**: `dart run bin/migrate.dart create <name>` in the server package, with `DW_DATABASE_*` set, then review the draft. The framework's own tables migrate in `packages/dartway_core_server/lib/src/migrations/dw_framework_migrations.dart` under the `dw` namespace, **appended, never rewritten** — an applied migration whose checksum changes stops every server that has applied it (D-050). The one exception is a migration that could not apply on databases holding rows: it is corrected with the same outcome where it did apply, and declares the text it replaces in `supersededChecksums` (D-056).

### The wire is a protocol

**A change of how calls, `DwApiResponse`, update transports, live messages or generated DTO JSON look on the wire bumps `dwProtocolVersion`** (D-052). An installed app keeps speaking the wire it was compiled with; with the bump it is answered `426` and shows "update the app", without it it fails to decode.

`packages/dartway_core_shared/test/wire_golden_test.dart` records the canonical encoding of every wire shape together with the protocol version it was taken at (`test/goldens/wire_golden.dart`), and reads each recorded encoding back. It fails when an encoding differs while the version is unchanged. The procedure, in order:

1. bump `dwProtocolVersion` in `packages/dartway_core_shared/lib/src/protocol/dw_http_contract.dart`;
2. `DW_UPDATE_GOLDENS=1 dart test test/wire_golden_test.dart` in `packages/dartway_core_shared` — it refuses to overwrite a changed encoding without step 1;
3. `dart test -p vm,node` in the same package — the wire has to read the same in a browser.

A new shape is recorded without a bump; a framework DTO without a recorded shape fails the test.

## Testing tiers

| Tier | What | Where it runs |
|---|---|---|
| 1 | `tool/checks.sh` — `dart analyze` over every resolution root and every suite that needs no services; `tool/checks.sh services` — the ORM, server and push suites against a Postgres and a MinIO | both locally before a PR, and `checks.yml` on every PR (one job per mode) |
| 2 | Pure-Dart packages on node: `dart test -p vm,node` in `dartway_core_shared` and `dartway_client` — dart2js rejects what the VM accepts | by hand when the wire or the client changes |
| 3 | Database and storage suites of the projects: `dartway test` in `example/` and `template/` (a Postgres and a MinIO per run, on ports Docker picks, removed afterwards) | `database.yml` nightly; locally when a change reaches a project's server |
| 4 | Docker proofs in the CLI: `dart test -t docker --run-skipped test/deploy_local_stack_test.dart` — builds the images and runs the rendered stack | by hand, when deploy changes; `images.yml` builds the template's images from what `dartway create` produces |

**`dartway_orm` and `dartway_core_server` need services for their own suites**: a Postgres through `DW_DATABASE_*` (the ORM's suites default to `127.0.0.1:55460`, user and password `dartway`) and, for the file suites, a MinIO through `DW_STORAGE_ENDPOINT` / `_ACCESS_KEY` / `_SECRET_KEY` (`packages/dartway_core_server/test/support/files.dart` has the `docker run` line). A suite that cannot reach them fails in `setUpAll` — a tier that silently skips is a tier that does not exist. They run as `tool/checks.sh services` (with `dartway_push_server`), which refuses to start unless every `DW_DATABASE_*` and `DW_STORAGE_*` variable is set and both ports answer; the plain `tool/checks.sh` leaves them to that mode and says so, so it needs no Docker. The script's header has the `docker run` and `export` lines.

**"I ran the tests" means tier 1 green, both modes**, plus tier 2 for a wire or client change and tier 3 for a change that reaches a project's server. Running only the suites you touched is what lets a broken one reach the trunk.

## Standards

- **Versioning: `0.x`, for at least a month after the rewrite runs in two projects and Studio (D-031).**
  - **The family moves in lockstep**: `dartway_core_shared`, `dartway_core_server`, `dartway_core_flutter`, `dartway_orm`, `dartway_client` and `dartway_generator` carry one version, and a project's pubspecs name one caret for it.
  - **Satellites version independently** (D-032). The family raises its caret on a satellite only in its own next minor; a project that needs a newer satellite earlier uses `dependency_overrides`. That `dartway check` warns when such an override outlives the framework's own raise is decided but not built yet.
  - **A version is the number of the next release, not a count of pull requests.** It moves once per release cycle per package. Whether *this* PR moves it has a mechanical answer — compare the package's `version:` with the same line on `stable`, where releases are cut from: equal → this change moves it; already ahead → leave the version and the carets alone and add to that version's `CHANGELOG` section. What is pending sets the floor: a pending patch in front of a breaking change becomes a minor — under a zero major a minor is what a major is elsewhere.
  - **The trap of a `0.x` caret**: `^0.6.0` is `>=0.6.0 <0.7.0`. Inside this repository `dependency_overrides` hide every constraint (pub does not check an overridden package's), `dartway create` strips them, and the caret is read for the first time in a stranger's tree. `dart run tool/caret_check.dart` asks pub.dev whether the skeleton's carets resolve; a finding is closed by publishing, not by lowering the caret.
- **Zero major: we promise nothing, so we preserve nothing.** No released shape is guaranteed to survive the next minor. A change fixes the shape going forward and stops there: no deprecated aliases kept "for a while", no second branch for the way it used to be, no code that recognises state written by an older version and heals it, no default chosen to spare an existing installation. What exists catches up by re-running the current procedure. For the rewrite this is total: nothing of 0.x is preserved, in the framework or in the projects moving onto it — their databases are recreated (D-031). Owner's decision, 2026-09-09.
- **Naming: no public name shorter than two words** — the `Dw` prefix is not a word (CONTRACTS R2.1). `DwTableRow`, `DwCallContext`, `DwLiveChannel`. The rule covers what the framework asks of projects too: `<Entity>Row`, data objects as two-word nouns, reads `Get…`/`List…`, changes verb + object, `<Project>Channel`, `<Project>Refusal`.
- **Rules live in types and checks, not in prose** (SPEC §0.1). A rule that can be a type, a required parameter, a startup failure or a failing check is expressed that way; a rule that is only written down is expected to be broken. **Silence is a bug**: a refusal reaches the user, a failure reaches the operator, a failed migration stops the process, a failed check fails the build.
- **The framework knows no domain.** It knows that someone signed in, not who they are to the project: accounts, identities and keys are the framework's; profiles, roles, texts, languages and channels are the project's, declared in its shared package.
- **Secure by default.** A registered request or command without a handler stops the server from starting; every handler declares its access rule, and there is no default; a channel kind without a rule refuses every subscription, and every subscription needs a signed-in connection; an upload purpose without a rule refuses every upload. New code must not introduce "open to everyone" as a default.
- **Workspace hygiene.** Inside the monorepo, packages resolve through the workspace (the root `pubspec.yaml`), never through git references to `dartway.git`. Not members, on purpose: `dartway_generator` (its analyzer pin) and `dartway_lints/example` (custom_lint needs its own package config); `example/` and `template/` resolve the framework by `dependency_overrides` onto `packages/`.
- **Language: everything that can end up in front of people is written in English.** One test decides it: **would an outsider see this by opening GitHub?** If yes, English — no exceptions, and regardless of whom it is addressed to.
  - The rule covers docs, package READMEs, error strings, comments in package code, **commit messages, PR titles and descriptions, PR and issue comments, branch names** — and **`toolkit/`**, which ships into the `.claude/` of every project on the framework.
  - **This file too.** It is the repository's constitution, and outside contributors are held to it by the automated review. Rules that judge a contributor have to be readable by that contributor.
  - **A conversation held in Russian does not make the artefact born from it Russian.** A PR description addresses Evgenii, yet it sits in a public repository — that is publication, not a continuation of the conversation.
  - Russian remains only where an outsider never reaches: the private project-management repository and our chat.
  - Which language a project uses for **its own** texts is that project's setting (`dartway setup-ai --language`), not ours.
- **Commits:** conventional commits — `feat:` / `fix:` / `chore:` / `docs:`, an optional scope (`feat(server): …`), and `!` before the colon for a breaking change (`feat(server)!: …`). The release notes list breaking changes first by that marker, so a breaking change without it is invisible there.
- **The toolkit invariant:** `toolkit/` carries no project literals, only `__*__` tokens — it ships into every project on the framework, so a name borrowed from whichever project you were looking at arrives in all of them. Held by reading the diff, not by a grep: a pattern listing the projects we remember today passes the leak that comes from the next one.
- **Where a package lives, and how it is distributed, are two questions.** Everything of ours lives **here**; publishing to pub.dev under its own name and version is separate. **A package whose API is taught by a skill in `toolkit/`, or that `template/` hands to a new project, belongs in this repository** — the synchronisation law binds it, and three of its mirrors (`example/`, `template/`, the skills) are not imports at all. `dartway_router` imports nothing of ours and lives here for exactly that reason.
- **Public API design lives in `docs/DESIGN.md` (law, not preference).** Before adding or changing a public symbol, check it against: a single root, `dw.` for the core and `dw.plugins.<name>` for extensions; the "factory on `dw.` vs constructor on the type" test; one way to do a thing, not two; the core is a minimal contract; validate against the active projects on the rewrite, not against the demo. A package may carry its own `DESIGN.md` (`packages/dartway_core_flutter/DESIGN.md`) — do not confuse the framework's philosophy with a package's.

## Working with git

The rules are the same for everyone — for Evgenii, for Claude, for outside contributors. The repository is public and its history is part of the product.

**Branches.**

| Branch | Role |
|---|---|
| `master` | The development trunk. May be in pieces at any moment |
| `stable` | The last verified state. **Fast-forward from master only**, a history of its own is forbidden. The CLI's default channel follows it, as do the git dependencies of external projects |
| `dartway-1.0` | The rewrite, until its global release (above). Work on the rewrite branches from it |
| `feat/*`, `fix/*`, `chore/*`, `docs/*` | Working branches. They live until merged, then they go |

No gitflow — no develop branch, no release branches.

**Code reaches master one way only: through a branch and a PR with squash merge.** On GitHub that is the only method enabled, so one PR equals one commit on master. Nobody pushes to master directly, for anything — `docs/` and `toolkit/` travel by branch too.

**A squash merge turns the PR title into the commit message on `master`.** The PR title is therefore a line of permanent public history — English, conventional, and it cannot be corrected afterwards: `protect-trunk` forbids force-pushing the trunk.

**Parallel sessions run in `git worktree` and nowhere else.** Two sessions sharing one working directory share the index and the working tree, and overwrite each other. One session = one branch = one directory:

```bash
git worktree add ../dartway-wt/<slug> -b feat/<slug> master
```

Keep the worktree directory **outside** the repository tree. Every worktree carries its own `.dart_tool` and its own `pub get`, and a session that runs `example` has to move its ports off the neighbour's.

### Claude's protocol (hard rules)

Each item closes off a way for one session to destroy another's work.

1. **`git status` first, before anything else.** Clean tree ⇒ `git switch -c <type>/<slug>` and work here. Dirty tree ⇒ **another session is already working in it**; create a worktree and move there. Asking whose changes those are is not an option: while the conversation happens, the other session keeps writing.
2. **In a shared tree holding someone else's changes, these are forbidden:** `git switch`, `git checkout <branch>`, `git stash`, `git reset`, `git restore`, `git clean`. Every one of them swaps files out from under a running session. The single exception is a switch where `git diff --name-only <from> <to>` is empty or lists only your own files — verified **before** the switch.
3. **Stage your own files, by name:** `git add <path> <path>`. **`git add -A`, `git add .` and `git commit -a` are forbidden, always** — in a shared tree they drag someone else's unfinished work into your commit.
4. **Create the branch at the start of the task, not at the end.** While a branch has no commits, a collision between sessions is resolved by splitting files; after the first foreign commit lands on your branch, only `cherry-pick` and manual surgery remain.
5. **Never branch from someone else's HEAD.** Branch from an explicit point: `git switch -c <name> master` (or `dartway-1.0` for the rewrite).
6. **Push and open PRs only when asked directly.** Never merge a PR, never push to `master` directly, never touch `stable` without an explicit instruction.
7. **Before offering a PR** — `framework-finish`, then the testing tiers the change reaches (above), all green. `tool/checks.sh` is what CI runs, so running it here is the gate itself, answered earlier.
8. **Clean up your worktree:** `git worktree remove ../dartway-wt/<slug>` once the branch is merged. Abandoned worktrees hold branches checked out.
9. **Everything that travels to GitHub is written in English:** branch name, commit message, PR title and description, PR comments. Re-read the title before `gh pr create`.

**A release is two acts: moving `stable`, and publishing to pub.dev** — skipping the second breaks the repository for exactly one person, a stranger, because `dartway create` strips the overrides and reads the carets against pub.dev. **`dart run tool/release.dart`** answers what is behind and in what order it may go out (a package cannot be published before one it states a caret on); `--publish` carries it out, and refuses from a branch, a dirty tree, or a commit that is not `origin/master`. The family packages other than `dartway_core_flutter` are `publish_to: none` until the rewrite is released. **A first publication is a different act from an update** — it claims the name permanently — and is agreed package by package.

**A release is tagged `git tag -a stable-YYYY-MM-DD[.N]` — annotated, on the `master` commit, and applied last**, after publishing: the tag is what the next release measures from, and only an annotated tag records when it was applied. **`dart run tool/release_notes.dart`** writes the notes from the window since the previous tag, breaking changes first.

**The promotion ritual for `stable`:** the testing tiers green + **example and template both build** + `dartway create` from a fresh clone produces a project that runs + `framework-finish` reporting no drift → publish → `git push origin master:stable`. No local `stable` branch — promotion travels by refspec.

**Protection.** `master` and `stable` are covered by the `protect-trunk` ruleset: force-pushes and deletion are forbidden, with no bypass. **Hygiene.** A branch is deleted when its PR merges. `user.email` is set locally to the work address, because the repository is public. Three local settings are expected; they live in `.git/config`, per clone:

```bash
git config fetch.prune true      # dead remote references stop piling up
git config pull.rebase true      # no merge commits from a pull
git config rerere.enabled true   # a conflict resolved once is remembered
```

`dart run tool/self_check.dart` notices when they are missing, together with stale lockfiles and carets pub.dev cannot satisfy (`--offline` skips the pub.dev question).

### CI

Six workflows in `.github/workflows/`:

| File | When | What it does |
|---|---|---|
| `checks.yml` | A PR is opened, updated or taken out of draft; push to `master` | `tool/checks.sh analyze`, `tool/checks.sh test`, and `tool/checks.sh services` with a Postgres service container and a MinIO |
| `database.yml` | Nightly, by hand, and when this workflow's file changes | `dartway test` in `example/` and `template/`, with the CLI activated from the commit. Not on every PR: these suites test races, and a flaky red is how a gate stops being read |
| `images.yml` | `template/` or the CLI changes, nightly, by hand | Builds the two images of a project **as `dartway create` produces it**, with this tree's packages vendored in (`tool/vendor_framework.dart`) |
| `web-compile.yml` | A PR is opened or updated; push to `master` | `flutter build web --release` for the targets in its matrix: dart2js rejects code the VM accepts. Its matrix still names the removed offline harness beside `example/` |
| `claude-review.yml` | A PR is opened, updated or taken out of draft | Reviews the diff; beyond ordinary bugs it holds the synchronisation law, generated code being up to date, a wire change bumping the protocol, and the toolkit invariant |
| `telegram-notify.yml` | A review finishes | Sends the verdict and a link to the PR to Telegram |

The review does not run on PRs from forks: repository secrets are unavailable to them. It needs the `CLAUDE_CODE_OAUTH_TOKEN` secret (issued by `claude setup-token`) **and** the [`claude` GitHub App](https://github.com/apps/claude) installed on the repository; without the app the OIDC exchange fails with `401 — Claude Code is not installed on this repository`. Notifications need `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. `workflow_run` is read from the default branch only — a change to `telegram-notify.yml` takes effect once merged into `master`.

## Workflow

A task arrives from outside — from the tracker or in conversation. What remains here is the work on the code: a branch for the task, the change, `framework-finish` before committing, the commit, and a PR when asked.

Project management — strategy, roadmap, the task queue — lives **in a separate repository** (`dartway/dartway_manager`), not in this monorepo.
