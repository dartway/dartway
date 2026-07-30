# The DartWay monorepo — project guide for Claude

A monorepo on the **Serverpod + DartWay + Flutter + Riverpod** stack. DartWay is a **highly opinionated** framework: less freedom in *how* to do things → more consistency and speed. Don't invent alternative approaches — follow the established patterns.

> This harness (methodology + skills + commands) ships from the DartWay monorepo (`toolkit/`, branch `stable`) and is installed into this repository's `.claude/` (committed). The files `CLAUDE.md`, `skills/dartway-*` and the `commit`/`dartway-audit` commands are **managed**: don't edit them here, they get overwritten on update; customize by copying under your own name. The source of truth is the toolkit in the monorepo. The package structure is detected automatically; the paths below were substituted at install time.

## Monorepo structure

Dart packages (the role is determined by the name suffix):

| Package | Role | What it does |
|---|---|---|
| `__SERVER_PKG__` | server | The Serverpod backend: YAML models, CRUD configs, server logic and workflows |
| `__CLIENT_PKG__` | client | The generated Serverpod protocol. **Never edit by hand** |
| `__FLUTTER_PKG__` | flutter | The Flutter app: features, UI Kit, navigation, data layer |

A project may add a fourth one, `*_shared` — pure Dart for code that has to behave identically on the server and in Flutter (see "Shared" below). The skeleton has none: until such code shows up, the package is not needed.

## Cross-stack laws (they hold everywhere)

1. **CRUD is the foundation of everything.** All Flutter ↔ Server interaction goes through CRUD operations on models. No arbitrary endpoints unless there is really no other way. Create and Update are merged into a single `save`.
2. **Domain-first.** Every feature starts with its model(s). A model reflects domain reality, not the momentary needs of the UI. Data lives in models — the UI is only a projection.
3. **A feature is end-to-end.** A feature is a flow running through the server (models + CRUD configs) and Flutter (entry point + widgets + logic). From outside the feature, **only** its entry point is imported — at any nesting depth.

   **What a feature is gets decided by the folder's contents — nothing has to be declared:**
   - a **feature** is a folder with **exactly one** `.dart` at its root. That file is its entire public surface;
   - the **internals** are only `widgets/` and `logic/`; nobody imports them from outside;
   - a **group** is a folder **without** root-level `.dart` files. It only groups features, encapsulates nothing, and has no `widgets/`/`logic/` of its own. Grouping **does not affect visibility**: the router is allowed to import `app/learning/lesson/lesson_page.dart`, because `lesson` is a feature and `learning` is a group;
   - **what two features share is one more feature**, not a `shared/` folder. A card drawn both by the block on the home screen and by the list screen goes into its own folder with a single public file;
   - a feature has **exactly one public entity**. A second one appeared (a page plus an embeddable block, a three-screen flow) — that is a group of several features.

   Many small folders are fine: atomicity matters more than a short tree. Checked by `dartway check` — it builds a "zone → group → feature" tree and grades every feature A–D.

   **Not a feature:** app-wide registries and infrastructure (the feature catalog, analytics, push initializers) — that is `lib/core/`; cross-feature domain logic — `lib/domain/`. If such a file sits in some feature's `logic/`, everyone else starts importing that feature's internals.
4. **3 levels of escalating logic** (in order of "last resort"): Event models → CRUD configuration (`SaveConfig`/`GetConfig`/...) → a custom endpoint (only when there is no other way; document it as an exception).
5. **Naming.** Classes — at least 2 words (`UserProfile`, not `User`). Variables are fully descriptive and match the type (`userProfile`, `userProfileId`). Fields relating to a user always carry the word Profile: `userProfileId`, `authorProfileId`, `updatedByProfileId`. Forbidden: `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x`.
6. **Done = audit + a description next to the code.** A feature is not finished until `dartway-finish` has been run: an audit of the diff against the cleanliness contract, and a reconciliation of the feature's description with the new behavior. **The description lives in the code, not in a separate doc:** a screen's behavior — in the `DwFeatureSpec` of the feature widget, the server-side agreements — in the doc comments above the CRUD config. We do not keep separate "a doc per feature" files: a description far from the code drifts from it on the very first edit, and it drifts silently — the code compiles while the doc lies. Verified on a production project: a feature's doc described an API that had not been in the code for a year, and the agent wrote non-working code from it.

## Code generation: not used by default

The only generator in the project is **`serverpod generate`** (models and client). It is a separate CLI, not `build_runner`, and it is unavoidable.

Everything else is written by hand:

- **providers and state** — plain `Provider` / `NotifierProvider`, no `riverpod_generator`. A family key is a record (`({int courseId, int? parentId})`): it has meaningful equality by construction, which is exactly what the generator is wanted for;
- **state data classes** — a plain immutable class with `copyWith` and `==`, no `freezed`. Domain models already arrive generated from Serverpod;
- **assets** — constants in the kit, no `flutter_gen`. That a path leads to an existing file is checked by `dartway check`.

**Why against the current** (the Riverpod documentation is written around codegen): `build_runner` inserts itself into the daily edit cycle — on a production project a single provider edit cost more than four minutes of waiting. Worse, it is a trap for the agent: forgot to run the generator — got `undefined name` and started "fixing" working code. Saving a few lines of `Provider.family` is not worth it.

**Families are written by hand too** — including a family notifier with methods: `NotifierProvider.family` is declared as `NotifierT Function(ArgT arg)`, that is, **the argument arrives in the factory**, and the notifier takes it through its constructor. The internal `ref.$arg` that codegen uses is not needed by a handwritten class. The framework itself is built that way: `DwModelListState(this.config)` + `AsyncNotifierProvider.family(...)`.

A family key is a value with meaningful equality: a record if fields without defaults are enough, otherwise a small class with `==` and `hashCode`. Riverpod uses it to decide whether this is the same provider or a new one.

A project is free to decide otherwise (a large asset library, union types where `freezed` really pays off) — but that is a deliberate exception, not a default.

## Documentation: the description lives in the code

**There are no separate "a file per feature" docs in the project.** To learn about a feature, ask its code:

| What you need to know | Where to look |
|---|---|
| what the feature does, what to expect from it, where the traps are | `DwFeatureSpec` in its public file |
| what is wrong with the feature and worth picking up | `knownIssues` in that same spec |
| access rules, validations, side effects | the doc comments above the model's `DwCrudConfig` |
| a field's invariants and meaning | the doc comment above the field in the YAML model |

**Why so.** A doc sitting apart from the code drifts from it silently: the compiler does not check it, the checker does not see it, and the agent reads it and believes it. On a production project such a doc described an API deleted a year earlier, and non-working code was written from it. A spec in the feature's file and a comment above the config survive a code edit because they lie in the same diff — they are impossible to miss.

What stays in `docs/`:

- **`docs/1_general/`** — architecture and infrastructure (`FLUTTER_ARCHITECTURE.md`, `SERVER_ARCHITECTURE.md`, release playbooks) and the **cross-cutting references** that have no feature of their own: the analytics event registry, the settings key catalog, the roles and access matrix, an external integration's payload. The sign of such a file — it describes not a screen but a convention that holds across the whole app.
- **`docs/audits/`** — `/dartway-audit` reports.

Don't create a file in `docs/` that could be named after a feature. If you're tempted, it means the description did not fit into the spec, and the question is not "where to put the doc" but "why doesn't the spec answer it".

## Cleanliness and finishing

For **any** Dart/Flutter code the clean-code contract applies: `.claude/skills/dartway-clean-code/SKILL.md` (the team's hard rules + SOLID/KISS/DRY/YAGNI + tests for the complex stuff). This is a style contract — check against it while writing, refactoring and reviewing.

**Finishing a task (Law 6):** when a feature/task is done, run `dartway-finish` before the commit/PR. It audits the diff against the contract, checks the feature's documentation for drift and the test coverage, and **shows suggestions and applies only what was confirmed**.

## Skills and commands

- Skills (`.claude/skills/`): `dartway-run`, `dartway-requirements`, `dartway-plan`, `dartway-clean-code`, `dartway-navigation`, `dartway-feature-scaffold`, `dartway-crud-config`, `dartway-ui-kit`, `dartway-data-layer`, `dartway-models`, `dartway-push-delivery`, `dartway-finish` — loaded by relevance to the task.
- Commands (`.claude/commands/`): `/dartway-audit` — a deep audit of a module; `/commit` — a commit in the project's CI format.

**Task lifecycle:** `dartway-requirements` (analyze the spec → questions → options) → `dartway-plan` (a step-by-step plan + risks) → implementation (the layer skills) → `dartway-finish` (audit + docs sync + tests before the PR).

**Bringing the project up locally** (a fresh clone, "it won't start", after a model change) — `dartway-run`: DB, migrations, seed, server, app, plus diagnostics for the typical failures. A liveness check is mandatory — report it as a fact (the API response code, the applied migrations), not as an assumption.

## Git

PRs and diffs go against the `__BASE_BRANCH__` branch. The first line of a commit: `<type>: <description in English> #<TICKET>` (`type` = `feat`/`fix`/`chore`); the ticket is passed as an argument to `/commit`, and the project's CI checks the exact format.

---

## Server (`__SERVER_PKG__`)

**The main law:** all logic goes through **CRUD configs**, not through arbitrary endpoints. Domain-first.

The `lib/src/` structure: `app/` (session-aware workflows) · `crud/` (CRUD configs — all the logic is here) · `dartway/` (internal utilities) · `domain/` (pure extensions, no Session/IO/DB) · `endpoints/` (last resort: upload, webhooks) · `generated/` (**do not edit**) · `models/` (the YAML schema) · `web/`. The boundary: **domain** — pure rules, **app** — session-aware side effects.

- **Models:** nullable only if the value really can be absent in the domain. **Base vs Event:** Base is the current state (`UserProfile`), Event is a change on top of the base (`BalanceEvent`); for money/transactions use Event (don't change a field like `balance` directly). Relations are explicit in the YAML, bidirectional ones share the same `relation(name=...)`. Playbook — `dartway-models`.
- **CRUD:** one `DwCrudConfig<T>` per model (`allowSave` → `validateSave` → transaction: `beforeSaveTransaction` → write → `afterSaveTransaction` → outside the transaction: `afterSaveTransform` → `afterSaveSideEffects`; all hooks take `(session, saveContext)`; `getModelConfigs`/`getListConfig`/`deleteConfig`, and read configs require `accessFilter`); without a config the API returns `notConfigured`; responses come in `DwModelWrapper`. Playbook — `dartway-crud-config`.
- **Model workflow:** edit the YAML → `serverpod generate` (updates `generated` + the client package) → `create-migration` → `DwCrudConfig` + registration in `crudConfigurations` → migrations on startup → tests.
- **Auth:** the user is **our own** `UserProfile` model; `serverpod_auth` is **not used** (recent versions ship their own `UserProfile` → a name clash). Authentication goes through DartWay (`DwPhoneAuthConfig` and the like).

## Flutter (`__FLUTTER_PKG__`)

The `lib/` structure: `admin/` · `app/` (the main features) · `auth/` · `common/` · `core/` (router, dw_core) · `data/` (the data layer) · `domain/` (cross-feature extensions) · `ui_kit/`.

- **Features:** a feature = an entry point (one public file) + `widgets/` + `logic/`. From outside, import **only the entry point**. Cross-feature logic goes to `lib/domain/`. The entry-point widget declares the feature spec (`implements DwFeature` with a `DwFeatureSpec`) right in its own file — the description lives next to the code, not in a separate registry; it is read by error reports, Studio and the agent. Skill — `dartway-feature-scaffold`.
- **Data (the data layer):** access only through `dw.repo` — reads are providers under the native `ref.watch`/`read`/`refresh` (`dw.repo.model`/`maybeModel`/`modelList`), writes are `dw.repo.saveModel`/`deleteModel`. Lists — `dwBuildListAsync(loadingItemsCount:)`; narrowing by query — `backendFilter`, local filtering you do yourself with `.where` in the widget. The contract — `dartway-data-layer`, creating a feature — `dartway-feature-scaffold`.
- **The UI Kit is the only source of styles:** in `app/`/`auth/`/`common/` direct `Color`/`TextStyle`/`BorderRadius`/`context.textTheme`/`context.colorScheme` are forbidden; the only import is `ui_kit.dart`. Skill — `dartway-ui-kit`.
- **Navigation:** the DartWay Router — enum routes, enum parameters, transitions through context extensions (`context.goNamed`/`pushTo`/`replaceWith`, not `router.go()`), guards centralized. Skill — `dartway-navigation`.
- **Specials:** notifications — `dw.notify.*` (not `SnackBar`); the profile — `ref.watchUserProfile`/`readUserProfile` (not `watchModel<UserProfile>`); actions from the UI — `dw.action`; sign-out — `signOut()`.

## Shared (the optional `*_shared`)

**The skeleton does not include this package** — create it once code appears that has to behave **identically** on the backend and the frontend (format validation, shared enums, computations over fields without IO). Until such code exists there is nothing to duplicate and the package is not needed.

✅ Allowed: pure Dart, a dependency on the client package. ❌ Not allowed: Flutter, server APIs, `Session`, IO, the DB. The public API goes in `lib/<package_name>.dart`, the implementation in `lib/src/`.

## Client (`__CLIENT_PKG__`)

The generated Serverpod protocol (models + client). **Never edit by hand** — it is recreated from the server's YAML via `serverpod generate`. A dependency of shared / flutter / server.
