# A DartWay project — the guide for Claude

A fullstack Dart project on **DartWay**: a server and a Flutter app that speak one contract, declared once in a shared package. DartWay is a **highly opinionated** framework: less freedom in *how* to do things → more consistency and speed. Don't invent alternative approaches — follow the established patterns.

> This harness (methodology + skills + commands) ships from the DartWay monorepo (`toolkit/`) and is installed into this repository's `.claude/` (committed). The files `CLAUDE.md`, `skills/dartway-*` and the `commit`/`dartway-checkup` commands are **managed**: don't edit them here, they get overwritten on update; customize by copying under your own name. The package names below were substituted at install time.
>
> **A rule that let you down is not fixed here** — the fix would be overwritten on the next update. File it as an issue in the framework tracker instead (`dartway-framework-notes`).

**This project writes in __PROJECT_LANGUAGE__.** That covers what the project owns — `DwFeatureSpec` texts, doc comments, `docs/dev_notes/` — and is set at install time (`dartway setup-ai --language`). What ships to other people is English regardless: package APIs, error strings, and anything going back into the framework.

## The project

Three Dart packages; the role is determined by the name suffix:

| Package | Role | What it holds |
|---|---|---|
| `__SHARED_PKG__` | the contract | Pure Dart. Data objects, requests, commands, live channel kinds, refusal codes, upload purposes, and the rules both sides apply identically. Generated codecs and the protocol registry |
| `__SERVER_PKG__` | the server | One folder per feature (its `DwServerFeature`, row classes, one handler per request and command with its access rule, channel rules), the auth configuration, upload rules, migrations, `bin/server.dart`, `bin/migrate.dart`, `bin/seed_dev.dart` |
| `__FLUTTER_PKG__` | the app | Features in zones, navigation, the UI kit, localization; reads with `dw.request`, changes with `dw.command` |

There is no client package: the shared package *is* the client contract, and both the app and the server import it.

## Cross-stack laws (they hold everywhere)

1. **The contract is the only way across.** Everything the app and the server exchange is a DTO declared in `__SHARED_PKG__`: a **data object** the server returns and publishes, a **request** that reads, a **command** that changes. No hand-written HTTP for the app, no JSON maps, no second API. A `DwHttpRoute` is a door for callers that are not the app — a webhook, a tool — and nothing else.
2. **Rows never leave the server.** A row class (`<Entity>Row`) is the server's shape of a table; a data object is what a reader may see. The server maps one to the other explicitly, in batch. A data object is designed for its readers — not a copy of the table, and never carrying what they may not see.
3. **A feature is end-to-end.** A feature is a flow running through the contract (its DTOs), the server (their handlers) and Flutter (entry point + widgets + logic). From outside the feature, **only** its entry point is imported — at any nesting depth.

   **What a feature is gets decided by the folder's contents — nothing has to be declared:**
   - a **feature** is a folder with **exactly one** `.dart` at its root. That file is its entire public surface;
   - the **internals** are only `widgets/` and `logic/`; nobody imports them from outside;
   - a **group** is a folder **without** root-level `.dart` files. It only groups features, encapsulates nothing, and has no `widgets/`/`logic/` of its own. Grouping **does not affect visibility**: the router is allowed to import `app/learning/lesson/lesson_page.dart`, because `lesson` is a feature and `learning` is a group;
   - **behaviour two features share is one more feature.** A card drawn both by the block on the home screen and by the list screen goes into its own folder with a single public file;
   - a feature has **exactly one public entity**. A second one appeared (a page plus an embeddable block, a three-screen flow) — that is a group of several features.

   **A zone holds features and nothing else. A widget with no story of its own is a building block, and blocks live in `lib/shared/`** (its inner layout is the project's business). The line is not how many places use it but whether there is anything to tell: a card with rules about what it shows and when is a feature even with one consumer; a form field, a badge row, a layout wrapper is a block — its description is a doc comment over the class, not a `DwFeatureSpec`. Don't create a `common/`, `shared/` or `widgets/` folder *inside* a zone: that is a block asking for the wrong home.

   **Splitting into small features is the recommendation, not a tolerated evil** — and the reason is the passport. Every feature brings a `DwFeatureSpec`, so the finer the cut, the denser the description of the interface: one big feature is described in generalities, ten small ones each carry their own `behaviors`, `requirements` and `knownIssues`. That description is what error reports, Studio and the agent read. `dart run dartway_cli:dartway check` builds a "zone → group → feature" tree and grades every feature A–D.

   **Not a feature:** app-wide wiring (the router, the `dw` core, the signed-in profile, app settings) — that is `lib/core/`; a building block, and an extension on a data object is one — `lib/shared/`. If such a file sits in some feature's `logic/`, everyone else starts importing that feature's internals.
4. **The server decides, and says no with a code.** Every request and command has exactly one handler with an explicit access rule; every channel kind has a rule for who may listen; every upload purpose has a rule for who may upload. **A refusal is a code with parameters, never a sentence** — the words are the app's, in its localization. Who the caller is gets decided on the server only; the client validates a form for speed, the server validates again.
5. **Naming.** Every class name has at least two words (`UserProfile`, not `User`). Row classes are `<Entity>Row`; data objects are nouns (`InvoiceLine`); reads are `Get…` / `List…` (`ListMyInvoices`); changes are verb + object (`PayInvoice`); the project's channel kinds and refusal codes are `<Project>Channel` and `<Project>Refusal`. Variables are fully descriptive and match the type (`userProfile`, `userProfileId`). A field that refers to a profile carries the word Profile (`authorProfileId`); one that refers to a framework account says so (`accountId`). Forbidden: `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x` as the whole name.
6. **Derived code is derived.** Codecs, the protocol registry, table definitions and the schema come from `dart run dartway_cli:dartway generate`; the database schema comes from migrations generated from the row classes and reviewed. Neither is edited into agreement by hand, and both are checked.
7. **Done = audit + a description next to the code.** A feature is not finished until `dartway-finish` has been run: an audit of the diff against the cleanliness contract, and a reconciliation of the feature's description with the new behaviour. **The description lives in the code, not in a separate doc:** a screen's behaviour in the `DwFeatureSpec` of the feature widget; what a DTO means, above the DTO; who may call it and what it changes and publishes, above its handler. A description far from the code drifts on the first edit, and drifts silently — the code compiles while the doc lies.

## Law and default — and which one a project may override

**Law is what makes it DartWay** — the seven rules above; a project does not override a law. **Default is everything else** here and in the skills — the commit format, the base branch, how a decision is recorded, the language of the project's own texts — and a project may replace it. **Precedence:** a default yields to the project's own root `CLAUDE.md`; a law does not; where both are silent, this file stands. A project records an override in its root `CLAUDE.md`, under "Project conventions", **with the reason** — `.claude/CLAUDE.md` is overwritten on update, and a README beside the code is where an override goes to die.

**Law is what fails**: much of it in the types and at the server's start, the rest as an `error` of `dart run dartway_cli:dartway check`. A warning is a strong default, an `info` a nudge. The law list is therefore derived — `DwCheckType.severity`, not how firmly a sentence is written. Fifteen checks fail today:

| What it holds | Checks that fail |
|---|---|
| The feature boundary (feature law) | `invalidFeatureStructure`, `notAFeature`, `barrelFile`, `forbiddenFeatureImport` |
| The UI kit boundary | `uiKitPartMissing`, `forbiddenUiUsage`, `forbiddenUiKitImport` |
| The widget's contract with its parent | `widgetSizesItself` |
| The declared top-level layout | `invalidTopLevelLayout` |
| What the router refuses on the first frame | `routeNameDuplicated` |
| The contract's names are its wire names (law 5) | `contractNameInvalid` |
| What ships broken with nothing to notice | `assetPathMissing`, `l10nNotWired` |
| Derived code is derived (law 6) | `generatedCodeStale`, `migrationsDrift` |

Ten further checks are warnings and one is a nudge. Anything this table and the types do not hold is a default. Not held yet: the naming law beyond the contract's DTO names, a `DwHttpRoute` the app calls instead of a request, and "done" (only the `featureSpecMissing` warning); `migrationsDrift` needs a Postgres and says when it did not run.

## The project's `dartway` is `dart run dartway_cli:dartway`

`generate`, `check`, `test`, `dev`, `deploy` and `stats` run the CLI the project pins — a dev
dependency of `__FLUTTER_PKG__`, at the version of the framework it builds against — as
**`dart run dartway_cli:dartway <command>`, in `__FLUTTER_PKG__`**; each finds the project from
there. A globally activated `dartway` refuses them when it is another version and names this form.
Every command in this toolkit is written that way; `dartway create`, `quickstart`, `update`,
`setup-ai` and `doctor` are the global CLI's and run anywhere.

## Code generation: two generators, and no `build_runner`

Exactly two: **`dart run dartway_cli:dartway generate`** (codecs and the protocol registry in `__SHARED_PKG__`, tables and the schema in `__SERVER_PKG__`) and **`flutter gen-l10n`** (`AppLocalizations` from `lib/l10n/*.arb`). Both are **run by hand** when their input changes — a DTO or a row class, an `.arb` — never on save; their **output is committed**; and they **can be forgotten**: a field added without `generate` compiles and travels *without that field*. `dart run dartway_cli:dartway generate --check` and `check` (`generatedCodeStale`) say so.

Everything else is written by hand: providers (`Provider` / `NotifierProvider`, families included — the argument arrives in the factory and the notifier takes it through its constructor; server data needs no provider of your own, `ref.watch(dw.request(...))` is one), state classes with `copyWith` and `==` (no `freezed`), assets as constants in the kit (no `flutter_gen`). `build_runner` in the edit loop cost minutes per provider edit and sent the agent "fixing" working code after a forgotten run. A project may decide otherwise, deliberately.

## Documentation: the description lives in the code

**There are no separate "a file per feature" docs.** A feature's behaviour, and what is wrong with it, is its `DwFeatureSpec` (`knownIssues`); what a DTO means, above the DTO; who may call a handler and what it changes and publishes, above the handler; a cross-cutting registry is an enum. A doc apart from the code drifts silently, and the agent reads it and believes it. `docs/` holds only what survives the question "what would this say that a spec or a doc comment cannot": `docs/adr/` — decisions and the alternatives they ruled out — and `docs/dev_notes/` — findings with no address in code. **Before writing or changing any of it — a spec, `knownIssues`, an ADR, a dev note — load `dartway-documentation`**: it has the admission tests and the forms.

## Cleanliness and finishing

For **any** Dart/Flutter code the cleanliness contract applies: naming, single responsibility, no `BuildContext`/`WidgetRef` in services, no `_buildXxx()` (widget or data), a re-read only as a user command, `copyWith` over field-by-field rebuilds, no environment default for a deployment credential, and the rest — spelled out in full, with the detectors that check it, in `dartway-finish` and `/dartway-checkup`, plus a boundary's own silent-rejection rule in `dartway-server`. This is a style contract — check against it while writing, refactoring and reviewing.

**`dartway-testing` decides what deserves a test and where it goes** — a rule of the contract is a test in `__SHARED_PKG__`, a handler's rule is an acceptance test on a real database (`dart run dartway_cli:dartway test`), a feature is a widget test on the in-memory server. The skeleton ships a worked example of each.

**Finishing a task (law 7):** when a feature/task is done, run `dartway-finish` before the commit/PR. It runs the checks, audits the diff against the contract, checks the descriptions for drift and the test coverage, and **shows suggestions and applies only what was confirmed**.

## Notes back to the framework

`.claude/` is managed and overwritten on update, so a rule that let you down is not fixed here: it is **filed as an issue in `__NOTES_TRACKER__`**. File one without being asked when the code broke a rule that does not exist or is too vague, when the app had to work around a `dartway_*` API, or when you are tempted to edit a managed file — that temptation *is* the finding. **Load `dartway-framework-notes` before creating the issue**: it says what must not travel, the labels, the `TODO(dartway, checked: …)` marker a workaround leaves in the code, and that the text is shown and waits for a yes.

## A project that lives by an older version of a law

**Legacy moves as you touch it, never as a sweep; a gap you leave is said out loud.** The old shapes a project may still carry — blocks inside zones, state in zones, an unlocalized app, root journals — are listed in `dartway-update` ("Old shapes"), each with how to tell and what to do; load it when `dart run dartway_cli:dartway check` reports `featureSpecMissing`, `notAFeature` or `l10nNotWired` on code you did not write.

## Skills and commands

- Skills (`.claude/skills/`): `dartway-requirements`, `dartway-plan`, `dartway-run`, `dartway-feature-scaffold`, `dartway-contract`, `dartway-server`, `dartway-data-layer`, `dartway-realtime`, `dartway-access`, `dartway-migrations`, `dartway-uploads`, `dartway-testing`, `dartway-navigation`, `dartway-ui-kit`, `dartway-on-device`, `dartway-push-delivery`, `dartway-analytics`, `dartway-documentation`, `dartway-framework-notes`, `dartway-finish`, `dartway-update` — loaded by relevance to the task.
- Commands (`.claude/commands/`): `/dartway-checkup` — the state of the project and what to take into work next (whole project by default, a path narrows it); `/commit` — a commit in the project's format.

**Task lifecycle:** `dartway-requirements` (analyze the spec → questions → options) → `dartway-plan` (a step-by-step plan + risks) → implementation (`dartway-feature-scaffold`, and the layer skills: `dartway-contract` → `dartway-server` → `dartway-data-layer`, with `dartway-realtime`, `dartway-access`, `dartway-migrations`, `dartway-uploads` where the feature reaches them) → `dartway-finish` (checks, audit, descriptions reconciled with the code, tests) before the PR.

**Moving onto a newer framework** is its own job, not part of a task: `dartway-update` installs the toolkit, reads the framework's migration notes, makes the edits they ask for and only then moves the package versions. Run it when `dartway update` says this project is behind.

**"Works in the simulator, not on my phone"** — `dartway-on-device`. **Bringing the project up locally** — `dartway-run`; report liveness as a fact (`/health` answering `200`), not an assumption.

## Git

PRs and diffs go against the `__BASE_BRANCH__` branch. The first line of a commit: `<type>(<scope>): <description in English>` — `type` = `feat`/`fix`/`chore`, the scope optional. Whether commits also carry a ticket, and whether anything checks the format, is this project's own convention and is stated in its root `CLAUDE.md` rather than assumed by the toolkit.

---

## Shared (`__SHARED_PKG__`)

**The contract, and nothing but pure Dart** — no Flutter, server, IO or database: both sides import it.

- **What goes here:** data objects, requests (`DwSingleRequest` … `DwWindowRequest`), commands, the enums of channel kinds, refusal codes and upload purposes, validation both sides run (`DwSelfValidating`). Playbook — `dartway-contract`.
- **A request's fields are its complete filter**, and a request is a value: the client caches and shares its live state under the request itself. `channels`, `matches`, `sort` and `positionOf` are pure functions of the object and the fields — `DateTime.now()` inside them is a bug.
- **A command never carries what the server decides** — the owner, timestamps, a status, a storage key. The handler derives them from the context.
- **"My …" requests carry no account id**: the server reads the caller, and the channel is `DwLiveChannel.ofCaller(kind)`.
- **A DTO change is a change to installed apps.** Adding a field with a default is safe; renaming or removing a field, a DTO or a refusal code raises the breaking line of `__SHARED_PKG__`'s `version:` (the minor below 1.0, the major after) in the same change, so installed builds are shown "update the app" instead of failing. A new enum value needs no raise (`dartway-contract`).
- **A new path dependency is named in both Dockerfiles**, or `pub get` inside the image fails three layers from the cause.

## Server (`__SERVER_PKG__`)

**The top level of `lib/` is a closed list:** `__SERVER_PKG__.dart`, `generated/` (**do not edit**) and `src/`. **`src/` is folders only: `core/` (auth, the caller and access rules, channel addresses, upload rules, startup), `migrations/`, and one folder per feature** declaring its `DwServerFeature` in `<feature>_feature.dart` — its rows, handlers, objects and publications beside it. No layer folders (`handlers/`, `rows/`, `domain/`) (`invalidTopLevelLayout`).

- **Handlers:** one per request and command, each with an explicit `DwAccessRule`; commands are transactional — lock the rows a decision depends on before deciding; refuse with `ctx.refuse(<Project>Refusal.…)`; someone else's row does not exist for the caller. Playbook — `dartway-server`.
- **Rows → data objects in batch**: one query per relation for the whole batch (`findByIds`), never per row; one mapping for reads and publications.
- **The caller's notions are the project's**: the profile and its role come from a `DwCallContext` extension cached with `memo`, read once per call.
- **Publish what a command changed** to every channel that shows it (`ctx.publish`), close removed access with `ctx.revoke`; a request never publishes. Playbooks — `dartway-realtime`, `dartway-access`.
- **Accounts, identities and session keys are the framework's**: the profile row is created in `onAccountCreated`; a project never queries `dw_*` tables — `ctx.accounts`, `ctx.files` are the surface.
- **The schema moves by migrations**: row class → `generate` → `dart run bin/migrate.dart create <name>` → review → `check`; an applied migration is never edited. Playbook — `dartway-migrations`.
- **Configuration is the environment**; secrets are never printed. Locally the entry points overlay `deploy/config.yaml > local` and `deploy/secrets.yaml > local` (git-ignored, never read by you); `dartway secret list --env local` says what is missing.

## Flutter (`__FLUTTER_PKG__`)

**The top level of `lib/` is a closed list: two files, four zones, four layers.** Files — `main.dart` (the environment: backend URL, version) and `__FLUTTER_APP_FILE__` (all the wiring). Zones, which hold features and are the only places asked for a `DwFeatureSpec` — `app/` (the app itself) · `admin/` (the admin panel) · `auth/` (signing in) · `common/` (features more than one zone draws on). Layers — `core/` (router, the `dw` core, the signed-in profile, app settings, refusal texts, and `core/platform/` for a conditional-import trio: `x.dart` exporting `x_stub.dart` / `x_web.dart`) · `shared/` (building blocks: widgets and helpers with no story of their own, extensions on data objects included) · `ui_kit/` · `l10n/`.

Nothing else sits at the top level, and none of those names appears lower down (`app/admin/` is a group, not the admin panel). **No `data/`, no `domain/`** — the data layer is `dw.request`/`dw.command`, the rules live in the shared package and the handlers (`invalidTopLevelLayout`).

- **Features:** a feature = an entry point (one public file) + `widgets/` + `logic/`. From outside, import **only the entry point**. The entry-point widget declares the feature spec (`implements DwFeatureWidget` with a `DwFeatureSpec`) right in its own file. Skill — `dartway-feature-scaffold`.
- **Data:** reads are `ref.watch(dw.request(request))` (`dw.pages`/`dw.table`/`dw.window`), changes `dw.command` inside `dw.action`. No repositories, no hand-written HTTP, no copies of server state; a failed read must not look like an empty one. `dartway-data-layer`.
- **`ProviderScope` is not written by the app** — `DwAppRunner` owns it, tests build their own; a nested override is silently invisible to providers reading through `Ref`. A value that differs per subtree is a family key or a constructor argument (`forbidden_provider_scope`).
- **The UI Kit is the only source of styles:** in the zones and in `shared/`, direct `Color`/`TextStyle`/`BorderRadius`/`context.textTheme`/`context.colorScheme` are forbidden; the only import is `ui_kit.dart`. Skill — `dartway-ui-kit`.
- **Every project is localized, and user-visible text is never written in code** — `context.l10n` in widgets, `appL10n` outside the tree; a new string goes into **every** `.arb`, then `flutter gen-l10n`, output committed. **Refusals are texts of the app**: `lib/core/` maps every code, the project's and the framework's `dw.*`, to a localized string for `DwFlutterConfig.refusalText`. `dart run dartway_cli:dartway check` reports missing wiring as `l10nNotWired` and text inside the kit as `uiKitContainsText`. The wiring list, server-composed text, the widget test's explicit `locale:` and what counts as content — `dartway-ui-kit`, "Localization".
- **Navigation:** the DartWay Router — enum routes, enum parameters, guards in the zones; a tapped notification or deep link navigates through one seam in `core/`. `dartway-navigation`.
- **Specials:** notifications — `dw.notify.*` (not `SnackBar`); actions from the UI — `dw.action`; sign-out — `dw.signOut()`; the signed-in account — `dw.accountId`; "update the app" — `DwFlutterConfig.updateRequiredScreen`, shown by the core when the server refuses this build.
- **`web/index.html` is part of the app**: its scroll lock keeps iOS from taking the app off screen when a field is focused, and anything that regenerates the shell drops it — `grep -q 'focusin' web/index.html`; `dartway-on-device`.
