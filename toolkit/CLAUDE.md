# The DartWay monorepo — project guide for Claude

A monorepo on the **Serverpod + DartWay + Flutter + Riverpod** stack. DartWay is a **highly opinionated** framework: less freedom in *how* to do things → more consistency and speed. Don't invent alternative approaches — follow the established patterns.

> This harness (methodology + skills + commands) ships from the DartWay monorepo (`toolkit/`, branch `stable`) and is installed into this repository's `.claude/` (committed). The files `CLAUDE.md`, `skills/dartway-*` and the `commit`/`dartway-checkup` commands are **managed**: don't edit them here, they get overwritten on update; customize by copying under your own name. The source of truth is the toolkit in the monorepo. The package structure is detected automatically; the paths below were substituted at install time.
>
> **A rule that let you down is not fixed here** — the fix would be overwritten on the next update. Write it down in `dartway_notes.md` at the project root instead; see "Notes back to the framework" below.

**This project writes in __PROJECT_LANGUAGE__.** That covers what the project owns — `DwFeatureSpec` texts, doc comments, `dartway_notes.md` — and is set at install time (`dartway setup-ai --language`). What ships to other people is English regardless: package APIs, error strings, and anything going back into the framework.

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
   - **behaviour two features share is one more feature.** A card drawn both by the block on the home screen and by the list screen goes into its own folder with a single public file;
   - a feature has **exactly one public entity**. A second one appeared (a page plus an embeddable block, a three-screen flow) — that is a group of several features.

   **A zone holds features and nothing else. A widget with no story of its own is a building block, and blocks live in `lib/shared/`** (its inner layout is the project's business). The line is not how many places use it but whether there is anything to tell: a card with rules about what it shows and when is a feature even with one consumer; a form field, a badge row, a layout wrapper is a block — its description is a doc comment over the class, not a `DwFeatureSpec`. Blocks in a zone were the old shape, and the cost showed up as passports that only restate the class name. Don't create a `common/`, `shared/` or `widgets/` folder *inside* a zone: that is a block asking for the wrong home.

   **Splitting into small features is the recommendation, not a tolerated evil** — and the reason is the passport. Every feature brings a `DwFeatureSpec`, so the finer the cut, the denser the description of the interface: one big feature is described in generalities, ten small ones each carry their own `behaviors`, `requirements` and `knownIssues`. That description is what error reports, Studio and the agent read, and merging features is how it gets lost. Checked by `dartway check` — it builds a "zone → group → feature" tree and grades every feature A–D.

   **Not a feature:** app-wide registries and infrastructure (the feature catalog, analytics, push initializers) — that is `lib/core/`; a building block, and an extension on a model is one — `lib/shared/`. If such a file sits in some feature's `logic/`, everyone else starts importing that feature's internals.
4. **3 levels of escalating logic** (in order of "last resort"): Event models → CRUD configuration (`SaveConfig`/`GetConfig`/...) → a custom endpoint (only when there is no other way; document it as an exception).
5. **Naming.** Classes — at least 2 words (`UserProfile`, not `User`). Variables are fully descriptive and match the type (`userProfile`, `userProfileId`). Fields relating to a user always carry the word Profile: `userProfileId`, `authorProfileId`, `updatedByProfileId`. Forbidden: `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x`.
6. **Done = audit + a description next to the code.** A feature is not finished until `dartway-finish` has been run: an audit of the diff against the cleanliness contract, and a reconciliation of the feature's description with the new behavior. **The description lives in the code, not in a separate doc:** a screen's behavior — in the `DwFeatureSpec` of the feature widget, the server-side agreements — in the doc comments above the CRUD config. We do not keep separate "a doc per feature" files: a description far from the code drifts from it on the very first edit, and it drifts silently — the code compiles while the doc lies. Verified on a production project: a feature's doc described an API that had not been in the code for a year, and the agent wrote non-working code from it.

## Code generation: not used by default

The only generator in the project is **`serverpod generate`** (models and client). It is a separate CLI, not `build_runner`, and it is unavoidable. Being a separate CLI is also why its output has to be re-formatted afterwards — it carries its own `dart_style`, and the sequence that keeps that from flooding every diff is in the Server section below (`serverpod generate` → `create-migration` → `dart format`, in that order).

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

**A new project gets no `docs/` folder, and most of what you would put in one belongs elsewhere.** A document nobody compiles is a document nobody notices going stale, and the ones about architecture rot fastest, because the code they describe changes under them without a single error.

The cases that used to justify one, and where they go instead:

| What it is | Where it lives now |
|---|---|
| A cross-cutting registry — analytics events, settings keys, roles | Code in `lib/core/`: an enum or a class of constants with doc comments. The compiler then knows the list, `dartway check` sees it, and a typo is an error rather than a discrepancy |
| The roles and access matrix | Doc comments above the `DwCrudConfig`s — the rule sits where it is enforced |
| An external integration's payload | Doc comments on the model or the endpoint that receives it |
| "How this app is put together" | The skills. That is what they are: the methodology ships from the framework and is updated with it, and a copy inside the project would only fall behind it |
| A checkup report | The chat. `/dartway-checkup` writes no report file on purpose: what belongs to a feature becomes a line in its `knownIssues`, what belongs to the project goes to `dev_notes.md`, and the rest was worth saying once |

Before starting any document, name what it would say that a `DwFeatureSpec`, a doc comment or a piece of code cannot. Usually the answer is that the spec is silent where it should not be, and the fix is in the spec.

**`docs/` is for what survives that question** — the documents this project genuinely needs. One kind is known to the framework and has rules, because it is the one that keeps being reinvented.

### `docs/adr/` — the decisions, and what they ruled out

An ADR records **the alternatives that were rejected, and why**. That is the one thing which cannot live beside the code: a rejected option has no file to sit next to. What the decision *produced* is in the code already.

**The admission test is one question:** is there an alternative someone will propose again in six months? If not, this is not an ADR, and what you wanted to write belongs in a spec or a doc comment.

`docs/adr/NNNN-slug.md` — four digits, flat, written in this project's language. Each one carries:

- **Status** — `accepted` or `superseded by NNNN` — and the date;
- **Context** — what forced a choice;
- **Decision** — what was chosen;
- **Rejected alternatives, each with its reason** — without this section the document is not an ADR;
- **Limitations accepted knowingly** — what you are choosing to live with.

**Never write "how it works now".** That is the part that rots, and it rots silently, because the code changes under it without an error. A real ADR described a `--dart-define` as the source of an app's URL while the README on the very same commit said that mechanism was gone.

**An ADR is never edited — it is superseded by a new one**, and the old one gets `superseded by NNNN` in its status. Editing destroys the only thing it is for: what was known at the moment of the choice. A record you may rewrite is not a record.

**Planning reads them.** `dartway-plan` looks in `docs/adr/` before proposing an approach, so a decision whose alternatives were already weighed is not re-argued from scratch — and a plan that itself makes such a choice proposes a new ADR as one of its steps.

## Cleanliness and finishing

For **any** Dart/Flutter code the clean-code contract applies: `.claude/skills/dartway-clean-code/SKILL.md` (the team's hard rules + SOLID/KISS/DRY/YAGNI + tests for the complex stuff). This is a style contract — check against it while writing, refactoring and reviewing.

**Finishing a task (Law 6):** when a feature/task is done, run `dartway-finish` before the commit/PR. It audits the diff against the contract, checks the feature's documentation for drift and the test coverage, and **shows suggestions and applies only what was confirmed**.

## Notes back to the framework (`dartway_notes.md`)

The harness is managed and gets overwritten on update, so a rule that let you down cannot be fixed
here. It also cannot be left unsaid: the rules are only ever proven wrong by real code, and this
project is the real code. `dartway_notes.md` at the project root is where such findings wait to be
carried into the DartWay monorepo. It is git-ignored — a working journal, not a shared document.

**Write there without being asked when:**

- the code broke a rule that does not exist, or exists too vaguely to have prevented it;
- the app had to work around a `dartway_*` API — an extra wrapper, a `hide`, a copied private helper;
- you are tempted to edit a managed file (`CLAUDE.md`, `skills/dartway-*`, the `commit` /
  `dartway-checkup` commands). That temptation *is* the note.

Write it the way it would have to be written in the toolkit: the example from the code, why the
existing rule did not catch it, and the concrete wording to add — not "something is off here". An
entry nobody can act on without re-deriving it is the same as no entry.

`dartway-finish` shows what is still open at the end of a task, so the journal gets carried over
rather than accumulated.

### Where an entry goes when it leaves this project

**Tracker:** `__NOTES_TRACKER__` — the GitHub repository this project's framework findings are filed
in as issues. An entry that has been filed records its issue instead of its status:

```markdown
- **Issue:** owner/repo#123
```

**The status field then goes away**, and that is the point rather than a shortcut. A status written
here is a second copy of a state that changes elsewhere, and it rots silently: one project's journal
listed eleven `open` entries two weeks after every one of them had shipped — including the entry that
asked for this mechanism. The issue holds the state, the decision and the link to the pull request
that closed it. The journal holds what an issue must not.

The one value that is not a repository is `none`, and it means this journal is the whole mechanism:
entries wait here with their statuses, and carrying them over is somebody remembering to. That is the
state the tracker exists to get out of, so it is chosen deliberately (`dartway setup-ai
--notes-tracker none`) and never arrived at by default.

That is the other half of the split, and it is what makes filing something other than a copy: **the
part that names this codebase does not travel.** Paths, class names, what the app did as a
workaround, where the marker sits — exactly what makes the entry actionable here, and exactly what
must not appear in a repository other people read.

So before an issue is created:

1. **Restate the entry for a stranger** — the rule that was missing, the API that forced the
   workaround, put so that it stands without this project's code. If nothing survives that, the
   entry was never about the framework and belongs in `dev_notes.md`.
2. **Write it in English** — the tracker is read by people who do not work on this project, so the
   language the journal itself is kept in does not follow the entry there.
3. **Search the tracker first.** Three projects meeting one API gap is one issue with three voices,
   not three issues.
4. **Label what it did to you** — the two labels below, and they are part of the text you show.
5. **Show the text and wait for a yes.** This is the only irreversible step the journal has — an
   issue exists publicly from the moment it is created, and deleting it does not un-index it.

#### The two labels

**`impact:` — what the finding did to this project, not how bad it feels.** The value is remembered,
not judged: an hour ago you either gave up on something, wrote a workaround, or simply noticed. A
scale of severities asks for an estimate instead, and an estimate drifts between one session and the
next until the field means nothing.

| Label | What actually happened |
|---|---|
| `impact:blocks` | It could not be worked around. Either the project cannot do what it has to, or the workaround cost more than the feature and the feature was dropped |
| `impact:workaround` | It was worked around, and the code carries the marker to prove it. The cost is known and dated: the day the fix lands upstream, that code starts duplicating the framework |
| `impact:friction` | It works, but the API pushes you to write the wrong thing, or the documentation says something untrue. Nobody was blocked and there was nothing to work around |

**`silent` — it breaks with no error attached.** Orthogonal to impact, and it is the label that
moves a decision: a `friction` that quietly corrupts data outranks a `blocks` that crashes on the
first run, because the loud one gets fixed the day it appears. It is visible; the other one is
found by eye, months later, if at all.

**A gap another project has already filed gets a comment, not a second issue** (rule 3 above): your
impact in one line, and the label rises to the worst voice on the issue if yours is worse. That is
also the whole of who-met-this — the account that wrote the line is who to talk to when it closes,
and GitHub records it without being asked. Nothing about your codebase travels with it, by rule 1.

### A workaround over a `dartway_*` API also leaves a marker in the code

The journal entry records that the workaround exists. It does not record whether it is still needed
— and that is the half which goes wrong, because the framework moves while the project's code does
not. The day the fix lands upstream nothing here changes: the workaround keeps running, now
duplicating the framework, and nobody is looking. It is not a cosmetic duplicate either. A real one
threw where the framework had chosen to degrade softly, so the app crashed on an offline start; the
project had been pinned to a commit that already carried the fix for weeks, and it was caught by eye.

So the code carries a marker naming the framework version the workaround was last confirmed against:

```dart
// TODO(dartway, checked: 518ae6d): <what we work around, what should appear upstream>
```

- **`checked:`** — the version of the framework this workaround was last verified against:
  the resolved git ref for a git dependency, the version number for a pub one. A short ref is fine.
- **The sentence** — what the app is doing instead, and what would have to exist upstream for the
  workaround to go. Without it the next reader cannot tell whether the framework has answered the
  problem or merely moved past it, and re-deriving that costs more than writing it did.

The marker and the `dartway_notes.md` entry are two halves of one record: the journal says what
should change in the monorepo, the marker says what to re-check here once it has. Write both.

`dartway-finish` compares `checked:` against the version resolved in `pubspec.lock` and raises the
marker **only when the two have diverged** — the question is asked exactly when its answer can have
changed, instead of on every task until it stops being read.

## Migrations: a project that lives by an older version of a law

A law is written for a clean start ("a zone holds only features"), and says nothing to a project that
already grew under the previous wording. Two rules cover that gap:

- **Legacy moves as you touch it, never as a sweep.** Refactored a feature — bring along what it drags
  with it. Converting a whole folder at once is a separate task a human asks for: it is a large diff,
  it breaks other people's branches, and nobody reviews it on the merits.
- **A gap you left is said out loud.** Decided not to touch the legacy — say so in the report. What
  must not happen is the agent quietly picking one of the two readings.

An entry below answers three things, in this order: **how to tell** the project still has the old
shape (something greppable, not "you'll know"), **what the target is**, and **what to do with what
has already accumulated**. A law changed without those three is a law that gets applied differently
in every project it reaches.

Live migrations (delete an entry once no project is on the old shape):

- **Blocks inside zones → `lib/shared/` (Law 3).** *You have the old shape if:* a zone contains a
  `common/`, `shared/` or `widgets/` folder, or `dartway check` reports `featureSpecMissing` for
  folders whose passport would only restate the class name. *Target:* only features in a zone,
  building blocks in `lib/shared/`, a block described by a doc comment. *A passport with nothing in it
  is deleted with the move, not reworded* — an empty spec means the thing was never a feature.

- **State and queries out of zones → `core/` and `shared/` (Law 3).** *You have the old shape if:*
  `dartway check` reports `notAFeature` — a folder in a zone whose entry point declares no widget.
  Until that check existed the "how to tell" was a reading, and a reading is what let one project
  gather ten such folders with every one graded A. *Target:* state that several features watch is
  wiring, so `lib/core/`; a query or helper with no story of its own is a building block, so
  `lib/shared/`. *What has accumulated:* move it as you touch the feature that reads it — and note
  that a provider named in tests through `overrideWith` stays a named provider, it just changes
  address.

## Skills and commands

- Skills (`.claude/skills/`): `dartway-run`, `dartway-requirements`, `dartway-plan`, `dartway-clean-code`, `dartway-navigation`, `dartway-feature-scaffold`, `dartway-crud-config`, `dartway-ui-kit`, `dartway-data-layer`, `dartway-models`, `dartway-push-delivery`, `dartway-finish` — loaded by relevance to the task.
- Commands (`.claude/commands/`): `/dartway-checkup` — the state of the project and what to take into work next (whole project by default, a path narrows it); `/commit` — a commit in the project's CI format.

**Task lifecycle:** `dartway-requirements` (analyze the spec → questions → options) → `dartway-plan` (a step-by-step plan + risks) → implementation (the layer skills) → `dartway-finish` (audit + reconciling the specs and doc comments with the code + tests before the PR).

**Bringing the project up locally** (a fresh clone, "it won't start", after a model change) — `dartway-run`: DB, migrations, the first administrator, server, app, plus diagnostics for the typical failures. A liveness check is mandatory — report it as a fact (the API response code, the applied migrations), not as an assumption.

## Git

PRs and diffs go against the `__BASE_BRANCH__` branch. The first line of a commit: `<type>: <description in English> #<TICKET>` (`type` = `feat`/`fix`/`chore`); the ticket is passed as an argument to `/commit`, and the project's CI checks the exact format.

---

## Server (`__SERVER_PKG__`)

**The main law:** all logic goes through **CRUD configs**, not through arbitrary endpoints. Domain-first.

**The top level of `lib/src/` is a closed list** — `app/` (session-aware workflows) · `crud/` (CRUD configs — all the logic is here) · `dartway/` (internal utilities) · `domain/` (pure extensions, no Session/IO/DB) · `endpoints/` (last resort: upload, webhooks) · `generated/` (**do not edit**) · `models/` (the YAML schema) · `web/` — and `lib/` itself holds `server.dart` and `src/`, nothing else. The boundary: **domain** — pure rules, **app** — session-aware side effects. `app/` and `domain/` may be absent (create one when such code appears); a folder outside the list is an error, and `dartway check` reports it as `invalidTopLevelLayout`.

- **Models:** nullable only if the value really can be absent in the domain. **Base vs Event:** Base is the current state (`UserProfile`), Event is a change on top of the base (`BalanceEvent`); for money/transactions use Event (don't change a field like `balance` directly). Relations are explicit in the YAML, bidirectional ones share the same `relation(name=...)`. Playbook — `dartway-models`.
- **An existing row is rebuilt with `copyWith`, never by listing its fields in the constructor.** This holds on both sides of the stack. A field with `default=`, and any nullable field, is an **optional** argument of the generated constructor, so a method that rebuilds a model by naming its fields keeps compiling when the model grows a field — and silently writes that field's default into every row it touches. One project reset the `priority` its backlog was sorted by on every edit of the record, for months, with a doc comment above the method asking for the opposite. Clearing a nullable field is `copyWith`'s job too: the generated one distinguishes "passed null" from "not passed", so nothing is lost. Enforced in the Flutter package by `model_rebuild_by_constructor` (`dartway_lints`).
- **CRUD:** one `DwCrudConfig<T>` per model (`allowSave` → `validateSave` → transaction: `beforeSaveTransaction` → write → `afterSaveTransaction` → outside the transaction: `afterSaveTransform` → `afterSaveSideEffects`; all hooks take `(session, saveContext)`; `getModelConfigs`/`getListConfig`/`deleteConfig`, and read configs require `accessFilter`); without a config the API returns `notConfigured`; responses come in `DwModelWrapper`. Playbook — `dartway-crud-config`.
- **Model workflow:** edit the YAML → `serverpod generate` (updates `generated` + the client package) → `create-migration` → **`dart format` over both generated paths** → `DwCrudConfig` + registration in `crudConfigurations` → migrations on startup → tests.
- **Generated code is committed formatted, in both packages, and the formatting step comes last.** `serverpod generate` writes its output through the `dart_style` bundled with the Serverpod CLI, which is not the `dart format` of the project's SDK — so a generation run rewrites files the change never touched, and one nullable field arrives at review as tens of files and thousands of lines. The fix is one command, but its position is not free: **`create-migration` re-runs the generation**, so formatting before it is thrown away and the sequence turns into a loop. Hence, from `__SERVER_PKG__`: `serverpod generate` → `serverpod create-migration` → `dart format lib/src/generated ../__CLIENT_PKG__/lib/src/protocol` (**`serverpod`, not `dart run serverpod`** — the generator is the globally activated `serverpod_cli`, and the `serverpod` package a server depends on has no `bin/` to run; see `dartway-models`). **Both paths or neither** — a repository that keeps the server tree formatted and the client tree raw hands the next honest `dart format` to whoever runs it, as dozens of files in an unrelated pull request. `dartway check` reports the drift as `generatedCodeUnformatted`, and after generating, `git diff --stat` should name only the models the task touched.
- **Auth:** the user is **our own** `UserProfile` model; `serverpod_auth` is **not used** (recent versions ship their own `UserProfile` → a name clash). Authentication goes through DartWay (`DwPhoneAuthConfig` and the like).

## Flutter (`__FLUTTER_PKG__`)

**The top level of `lib/` is a closed list: two files, four zones, four layers.** Files — `main.dart` (the environment: backend URL, version label) and `__FLUTTER_APP_FILE__` (all the wiring). Zones, which hold features and are the only places asked for a `DwFeatureSpec` — `app/` (the app itself) · `admin/` (the admin panel) · `auth/` (signing in) · `common/` (features more than one zone draws on). Layers — `core/` (router, `dw_core`, app settings, `studio/`) · `shared/` (building blocks: widgets and helpers with no story of their own, extensions on models included) · `ui_kit/` · `l10n/`.

Nothing else may sit at the top level, and nothing may carry one of those names lower down: `app/admin/` is not the admin panel, it is a group that has quietly left every check written for zones. There is **no `data/`** (the data layer is `dw.repo`) and **no `domain/`** (the rules live in CRUD configs on the server; what is left here is a helper, so `shared/`). A fifth navigation zone in the router does not earn a folder — it is a group inside `app/`. `dartway check` enforces all of this as `invalidTopLevelLayout`.

- **Features:** a feature = an entry point (one public file) + `widgets/` + `logic/`. From outside, import **only the entry point**. Cross-feature logic goes to `lib/shared/`. The entry-point widget declares the feature spec (`implements DwFeature` with a `DwFeatureSpec`) right in its own file — the description lives next to the code, not in a separate registry; it is read by error reports, Studio and the agent. Skill — `dartway-feature-scaffold`.
- **Data (the data layer):** access only through `dw.repo` — reads are providers under the native `ref.watch`/`read`/`refresh` (`dw.repo.model`/`maybeModel`/`modelList`), writes are `dw.repo.saveModel`/`deleteModel`. Lists — `dwBuildListAsync(loadingItemsCount:)`; narrowing by query — `backendFilter`, local filtering you do yourself with `.where` in the widget. The contract — `dartway-data-layer`, creating a feature — `dartway-feature-scaffold`.
- **`ProviderScope` is not written by the app.** The only one belongs to `DwAppRunner`; tests may create their own with `overrides:`. A nested scope in the widget tree looks like it works — widgets under it do read the override — but a provider reaching the same provider through `Ref` starts from the root container and silently gets the base value instead: no exception, no warning, just a different value. **A value that must differ per subtree travels as a family key or a constructor argument**, not through a scope. Enforced by `forbidden_provider_scope` (`dartway_lints`) — `riverpod_lint`'s own rule for this cannot help, it only understands generated providers.
- **The UI Kit is the only source of styles:** in the zones and in `shared/`, direct `Color`/`TextStyle`/`BorderRadius`/`context.textTheme`/`context.colorScheme` are forbidden; the only import is `ui_kit.dart`. Skill — `dartway-ui-kit`.
- **Every project is localized, and user-visible text is never written in code.** The skeleton arrives with it wired: `l10n/*.arb`, `appLocaleProvider` (system locale by default, switchable at runtime and by Studio over the bridge), `context.l10n` in widgets and `appL10n` for code outside the tree — notification bodies, error toasts. A project with one language keeps one `.arb` and pays nothing; adding localization later means walking every screen, which is why it is not a choice made per project.

  The reason is one sentence and it covers both places the rule bites: **a string the user reads is content, not decoration** — so `ui_kit` may not hold it (the kit does not own meaning) and a feature may not hardcode it (the feature does not own the language). `AppText.body(context.l10n.issuesTitle)`, never `AppText.body('Issues')`.

  Not mechanically enforced outside the kit, and deliberately so: telling `'Issues'` from `'issues/board'` or `'dd.MM'` takes reading the meaning, which no regex or lint rule does. `/dartway-checkup` looks for it. Inside `ui_kit/` the guess is safe — a kit file has no content to speak of — and `dartway check` reports it as `uiKitContainsText`.
- **Navigation:** the DartWay Router — enum routes, enum parameters, transitions through context extensions (`context.goNamed`/`pushTo`/`replaceWith`, not `router.go()`), guards centralized. Skill — `dartway-navigation`.
- **Specials:** notifications — `dw.notify.*` (not `SnackBar`); the profile — `ref.watchUserProfile`/`readUserProfile` (not `watchModel<UserProfile>`); actions from the UI — `dw.action`; sign-out — `signOut()`.

## Shared (the optional `*_shared`)

Not to be confused with `lib/shared/` in the Flutter package: that one holds building blocks — widgets
with no story of their own. This is a separate Dart **package**, for code that must behave identically
on the server and in Flutter.

**The skeleton does not include this package** — create it once code appears that has to behave **identically** on the backend and the frontend (format validation, shared enums, computations over fields without IO). Until such code exists there is nothing to duplicate and the package is not needed.

✅ Allowed: pure Dart, a dependency on the client package. ❌ Not allowed: Flutter, server APIs, `Session`, IO, the DB. The public API goes in `lib/<package_name>.dart`, the implementation in `lib/src/`.

## Client (`__CLIENT_PKG__`)

The generated Serverpod protocol (models + client). **Never edit by hand** — it is recreated from the server's YAML via `serverpod generate`. A dependency of shared / flutter / server.
