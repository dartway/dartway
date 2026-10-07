# A DartWay project — the guide for coding agents

A fullstack Dart project on **DartWay**: a server and a Flutter app that speak one contract, declared once in a shared package. The framework is opinionated on purpose: follow the established pattern, do not invent a second one.

> `.agents/DARTWAY.md`, `skills/dartway-*` and the `commit`/`dartway-checkup` commands are **managed** — installed from the framework's `toolkit/` and overwritten on update. Do not edit them here: a project's variant of a managed skill is a copy under its own name, and a rule that let you down is filed back to the framework (`dartway-framework-notes`).

**This project writes in __PROJECT_LANGUAGE__**: `DwFeatureSpec` texts, doc comments, `docs/dev_notes/` (a doc comment in another script is `docCommentLanguage`). What ships to other people — package APIs, log and error strings, issues to the framework — is English.

Project conventions in either root `AGENTS.md` or root `CLAUDE.md` apply regardless of the agent; inspect their project-specific sections when present.

## The project

| Package | Role |
|---|---|
| `__SHARED_PKG__` | The contract, pure Dart: data objects, requests, commands, channel kinds, refusal codes, upload purposes, rules both sides apply. `dartway-contract` |
| `__SERVER_PKG__` | The server: one folder per feature (rows, handlers with access rules, publications, jobs), migrations, `bin/`. `dartway-server` |
| `__FLUTTER_PKG__` | The app: features in zones, `core/`, `shared/`, `ui_kit/`, `l10n/`. `dartway-feature-scaffold` |

The shared package *is* the client contract; there is no client package. A new path dependency between them is named in both Dockerfiles, or `pub get` inside the image fails.

## Laws

1. **The contract is the only way across.** Everything the app and the server exchange is a DTO of `__SHARED_PKG__`: a data object, a request that reads, a command that changes. No hand-written HTTP, no JSON maps; a `DwHttpRoute` is a door for callers that are not the app.
2. **Rows never leave the server.** A handler maps a row to a data object designed for its readers — never carrying what they may not see — in batch.
3. **A feature is end to end** — its DTOs, its handlers, its Flutter folder — and from outside only its entry point is imported.
4. **The server decides, and says no with a code.** Every request and command has exactly one handler with an explicit access rule; every channel kind and upload purpose has a rule. A refusal is a code with parameters; the words are the app's.
5. **Naming.** Every class name has at least two words (`Dw` is not one): `<Entity>Row`; data objects are nouns; reads `Get…`/`List…`; changes verb + object; `<Package>Refusal`/`Channel`/`Upload`, where `<Package>` is `__SHARED_PKG__` without `_shared` in PascalCase. Variables say what they hold and match the type (`userProfileId`); a field referring to a profile says Profile, to a framework account says account. Never `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x` as a whole name.
6. **Derived code is derived.** Codecs, the protocol registry and the schema come from the generator; the database schema from reviewed migrations. Neither is edited into agreement by hand.
7. **Done = checks + a description next to the code.** A task ends with `dartway-finish`; a feature's behaviour lives in its `DwFeatureSpec`, a DTO's meaning above the DTO, a handler's rule above the handler (`dartway-documentation`).

## Law and default

**Law is the seven rules above and the checks below** — held in the types, at the server's start, or as an `error` of `dart run dartway_cli:dartway check`. A project does not override a law. **Everything else is a default** (commit format, base branch, how a decision is recorded) and a project may replace it in its root instruction file (`AGENTS.md` or `CLAUDE.md`), under "Project conventions", with the reason; a default yields to it, a law does not.

The law list is therefore derived from `DwCheckType.severity`, not from how firmly a sentence is worded. Forty-two checks fail today; twelve more are warnings and one is a nudge, each named in the skill that owns its topic. Each check's message says what to write instead; the skill named beside it shows the pattern where the message is not enough.

| Rule | Checks that fail | Skill |
|---|---|---|
| A feature folder has one root file; only that file is imported from outside; a zone holds features only; no re-export files | `invalidFeatureStructure`, `notAFeature`, `forbiddenFeatureImport`, `barrelFile` | `dartway-feature-scaffold` |
| Each package's top level is the declared list | `invalidTopLevelLayout` | `dartway-feature-scaffold`, `dartway-server` |
| State is hooks or a `<Thing>Controller` Notifier — no `StatefulWidget`, `ChangeNotifier`, no setState | `forbiddenStateHolder` | `dartway-feature-scaffold` |
| Styles live in `ui_kit/`, imported through `ui_kit.dart`, each kit file a part of it; spacing is `AppSpace`; a widget never sizes itself; asset paths exist | `uiKitPartMissing`, `forbiddenUiUsage`, `forbiddenUiKitImport`, `rawSpacing`, `widgetSizesItself`, `assetPathMissing` | `dartway-ui-kit` |
| The app is localized | `l10nNotWired` | `dartway-ui-kit` |
| A screen shows a read through `DwReadBuilder` / `DwPagedListView` / `DwWindowListView` | `forbiddenRequestRead` | `dartway-data-layer` |
| The one spinner is the kit's | `forbiddenProgressIndicator` | `dartway-ui-kit` |
| `dw.command` runs in the feature's `logic/`, inside `dw.action` | `forbiddenCommandCall` | `dartway-data-layer` |
| A screen is a route; dialogs through the kit; "new" is a route, never id 0; route names are global; the router disposes itself | `forbiddenNavigationCall`, `sentinelId`, `routeNameDuplicated`, `routerDisposedByApp` | `dartway-navigation` |
| A server feature is a closed file set; features form a graph without cycles, import each other's surface only, write only their own rows; `core/` imports no feature | `invalidServerFeatureFile`, `misplacedServerCode`, `featureImportCycle`, `featureImportOutsideSurface`, `foreignRowWrite`, `coreImportsFeature` | `dartway-server` |
| Time is `ctx.now`; the environment is read in `core/environment.dart`; other services through `ctx.http` | `forbiddenDateTimeNow`, `forbiddenEnvironmentRead`, `forbiddenHttpClient` | `dartway-server` |
| Startup work is a step before the port opens; settings are a typed object; a `!` on a row id is an error | `workAfterServerStart`, `settingsKeyValueTable`, `redundantBangAllowed` | `dartway-server` |
| The shared package mirrors the server's features; DTO names follow law 5; a patch is read through its helpers | `invalidSharedLayout`, `contractNameInvalid`, `fieldPatchMatched` | `dartway-contract` |
| Generated code matches its sources | `generatedCodeStale` | `dartway-contract` |
| Migrations produce the declared schema and change rows only through `m.backfill` | `migrationsDrift`, `migrationChangesData` | `dartway-migrations` |
| A test mirrors a `lib/` path and starts through `test/support/` | `testLayout`, `testHarnessBypassed` | `dartway-testing` |
| `lib/` imports by `package:` only (`check --fix` rewrites) | `relativeImport` | — |
| The framework's lint plugin is on | `lintsPluginMissing` | `dartway-update` |

Not held by any check: naming beyond DTO class names, "done", and a `DwHttpRoute` the app calls. `migrationsDrift` needs a database — `DW_DATABASE_*`, or `deploy/config.yaml > local` — and says when it did not run.

## Commands and generators

`generate`, `check`, `test`, `dev`, `deploy` and `stats` run the CLI the project pins: **`dart run dartway_cli:dartway <command>`, from `__FLUTTER_PKG__`**. `create`, `quickstart`, `update`, `setup-ai` and `doctor` are the global CLI's.

Two generators, both run by hand when their input changes, output committed: `dart run dartway_cli:dartway generate` (DTOs and row classes) and `flutter gen-l10n` (`.arb`). No `build_runner`: providers, `copyWith`/`==` of state classes and asset constants are written by hand.

## Skills and commands

- Skills (`.agents/skills/` for Codex; `.claude/skills/` for Claude): `dartway-requirements`, `dartway-plan`, `dartway-feature-scaffold`, `dartway-contract`, `dartway-server`, `dartway-access`, `dartway-realtime`, `dartway-migrations`, `dartway-uploads`, `dartway-data-layer`, `dartway-navigation`, `dartway-ui-kit`, `dartway-testing`, `dartway-documentation`, `dartway-finish`, `dartway-run`, `dartway-on-device`, `dartway-update`, `dartway-push-delivery`, `dartway-analytics`, `dartway-media`, `dartway-framework-notes`, `dartway-commit`, `dartway-checkup` — load the ones the task touches.
- Procedures (shared `dartway-checkup` and `dartway-commit` skills; Claude command wrappers in `.claude/commands/`): `/dartway-checkup` — the project's state and what to fix next; `/commit` — a commit in the project's format.

**A task:** `dartway-requirements` → `dartway-plan` → build with `dartway-feature-scaffold` and the layer skills (contract → server → app) → `dartway-finish` before the PR. Bringing the project up: `dartway-run`. A newer framework: `dartway-update`, as its own change. "Works in the simulator, not on the phone": `dartway-on-device`.

**Legacy moves as you touch it, never as a sweep; a gap you leave is said out loud.** Old shapes and how to recognise them: `dartway-update`.

**A rule that did not exist, an API the app had to work around, the urge to edit a managed file** — each is a finding for the framework: `dartway-framework-notes`, before creating any issue.

**Git:** PRs and diffs go against `__BASE_BRANCH__`; the commit format is `/commit`.
