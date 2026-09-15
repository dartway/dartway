# A DartWay project — the guide for Claude

A fullstack Dart project on **DartWay**: a server and a Flutter app that speak one contract, declared once in a shared package. DartWay is a **highly opinionated** framework: less freedom in *how* to do things → more consistency and speed. Don't invent alternative approaches — follow the established patterns.

> This harness (methodology + skills + commands) ships from the DartWay monorepo (`toolkit/`) and is installed into this repository's `.claude/` (committed). The files `CLAUDE.md`, `skills/dartway-*` and the `commit`/`dartway-checkup` commands are **managed**: don't edit them here, they get overwritten on update; customize by copying under your own name. The package names below were substituted at install time.
>
> **A rule that let you down is not fixed here** — the fix would be overwritten on the next update. File it as an issue in the framework tracker instead; see "Notes back to the framework" below.

**This project writes in __PROJECT_LANGUAGE__.** That covers what the project owns — `DwFeatureSpec` texts, doc comments, `docs/dev_notes/` — and is set at install time (`dartway setup-ai --language`). What ships to other people is English regardless: package APIs, error strings, and anything going back into the framework.

## The project

Three Dart packages; the role is determined by the name suffix:

| Package | Role | What it holds |
|---|---|---|
| `__SHARED_PKG__` | the contract | Pure Dart. Data objects, requests, commands, live channel kinds, refusal codes, upload purposes, and the rules both sides apply identically. Generated codecs and the protocol registry |
| `__SERVER_PKG__` | the server | Row classes, one handler per request and command with its access rule, channel rules, the auth configuration, upload rules, migrations, `bin/server.dart`, `bin/migrate.dart`, `bin/seed_dev.dart` |
| `__FLUTTER_PKG__` | the app | Features in zones, navigation, the UI kit, localization; reads with `dw.request`, changes with `dw.command` |

There is no client package: the shared package *is* the client contract, and both the app and the server import it.

## Cross-stack laws (they hold everywhere)

1. **The contract is the only way across.** Everything the app and the server exchange is a DTO declared in `__SHARED_PKG__`: a **data object** the server returns and publishes, a **request** that reads, a **command** that changes. No hand-written HTTP for the app, no JSON maps, no second API. A `DwRoute` is a door for callers that are not the app — a webhook, a tool — and nothing else.
2. **Rows never leave the server.** A row class (`<Entity>Row`) is the server's shape of a table; a data object is what a reader may see. The server maps one to the other explicitly, in batch. A data object is designed for its readers — not a copy of the table, and never carrying what they may not see.
3. **A feature is end-to-end.** A feature is a flow running through the contract (its DTOs), the server (their handlers) and Flutter (entry point + widgets + logic). From outside the feature, **only** its entry point is imported — at any nesting depth.

   **What a feature is gets decided by the folder's contents — nothing has to be declared:**
   - a **feature** is a folder with **exactly one** `.dart` at its root. That file is its entire public surface;
   - the **internals** are only `widgets/` and `logic/`; nobody imports them from outside;
   - a **group** is a folder **without** root-level `.dart` files. It only groups features, encapsulates nothing, and has no `widgets/`/`logic/` of its own. Grouping **does not affect visibility**: the router is allowed to import `app/learning/lesson/lesson_page.dart`, because `lesson` is a feature and `learning` is a group;
   - **behaviour two features share is one more feature.** A card drawn both by the block on the home screen and by the list screen goes into its own folder with a single public file;
   - a feature has **exactly one public entity**. A second one appeared (a page plus an embeddable block, a three-screen flow) — that is a group of several features.

   **A zone holds features and nothing else. A widget with no story of its own is a building block, and blocks live in `lib/shared/`** (its inner layout is the project's business). The line is not how many places use it but whether there is anything to tell: a card with rules about what it shows and when is a feature even with one consumer; a form field, a badge row, a layout wrapper is a block — its description is a doc comment over the class, not a `DwFeatureSpec`. Don't create a `common/`, `shared/` or `widgets/` folder *inside* a zone: that is a block asking for the wrong home.

   **Splitting into small features is the recommendation, not a tolerated evil** — and the reason is the passport. Every feature brings a `DwFeatureSpec`, so the finer the cut, the denser the description of the interface: one big feature is described in generalities, ten small ones each carry their own `behaviors`, `requirements` and `knownIssues`. That description is what error reports, Studio and the agent read. `dartway check` builds a "zone → group → feature" tree and grades every feature A–D.

   **Not a feature:** app-wide wiring (the router, the `dw` core, the signed-in profile, app settings) — that is `lib/core/`; a building block, and an extension on a data object is one — `lib/shared/`. If such a file sits in some feature's `logic/`, everyone else starts importing that feature's internals.
4. **The server decides, and says no with a code.** Every request and command has exactly one handler with an explicit access rule; every channel kind has a rule for who may listen; every upload purpose has a rule for who may upload. **A refusal is a code with parameters, never a sentence** — the words are the app's, in its localization. Who the caller is gets decided on the server only; the client validates a form for speed, the server validates again.
5. **Naming.** Every class name has at least two words (`UserProfile`, not `User`). Row classes are `<Entity>Row`; data objects are nouns (`InvoiceLine`); reads are `Get…` / `List…` (`ListMyInvoices`); changes are verb + object (`PayInvoice`); the project's channel kinds and refusal codes are `<Project>Channel` and `<Project>Refusal`. Variables are fully descriptive and match the type (`userProfile`, `userProfileId`). A field that refers to a profile carries the word Profile (`authorProfileId`); one that refers to a framework account says so (`accountId`). Forbidden: `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x` as the whole name.
6. **Derived code is derived.** Codecs, the protocol registry, table definitions and the schema come from `dartway generate`; the database schema comes from migrations generated from the row classes and reviewed. Neither is edited into agreement by hand, and both are checked.
7. **Done = audit + a description next to the code.** A feature is not finished until `dartway-finish` has been run: an audit of the diff against the cleanliness contract, and a reconciliation of the feature's description with the new behaviour. **The description lives in the code, not in a separate doc:** a screen's behaviour in the `DwFeatureSpec` of the feature widget; what a DTO means, above the DTO; who may call it and what it changes and publishes, above its handler. A description far from the code drifts on the first edit, and drifts silently — the code compiles while the doc lies.

## Law and default — and which one a project may override

Two kinds of rule live in this file and read alike: the same prose, the same voice, the same apparent weight. So an agent obeys them alike — including where the rule was never DartWay's to make. A commit format once demanded a ticket number, a project had no tracker, and the agent stopped mid-task on a question that had no answer.

**Law is what makes it DartWay.** The seven numbered rules above. Break one and the thing you are building stops being a DartWay project — a second architecture grows inside the first, confidently and fast. **A project does not override a law.**

**Default is what DartWay proposes because something has to be proposed.** Everything else here and in the skills: how a commit message is shaped, the base branch, how a decision is recorded, the language a project writes its own texts in. **A project may replace a default with its own rule.**

**Precedence, once, so nobody has to guess:** a default yields to the project's own root `CLAUDE.md`; a law does not. Where the two are silent, this file stands.

**A project records its override in its own root `CLAUDE.md`, under "Project conventions", with the reason.** Not in a README inside the folder the rule is about — that is where an override goes to die: nothing points a reader there, and an agent working from this file alone keeps following the rule the project decided against.

- **`.claude/CLAUDE.md` is managed and overwritten on update.** A project's own rule written into it disappears at the next `dartway setup-ai`. The root `CLAUDE.md` is the project's and is never touched by the installer.
- **An override is a decision, not a preference, so it carries its reason:** what was tried, what it cost, what replaced it.

**How the boundary stays honest: law is what fails.** Much of it fails before any check runs, because it is built into the types and into the server's startup: a row class cannot be registered in the protocol (only DTOs travel), a handler cannot be declared without an access rule, a refusal cannot be built from a string, a registered request or command without a handler stops the server from starting. The rest is held by `dartway check`, which has **three** severities, not two — and several checks are warnings **precisely because they have a second legitimate reading**: `uiKitConstStyle` is fine for a project with one theme, `frameworkRefsDiverged` cannot tell a pin from an oversight. A check that deliberately declines to fail is not a rule a project is forbidden to decide for itself. So the `error` severity is law; a warning is a strong default, and the `info` is a nudge.

**The law list is therefore derived rather than sorted** — it is `DwCheckType.severity` in `dartway_cli`, one `switch` statement, and reading it off is the whole method. Thirteen checks fail today:

| What it holds | Checks that fail |
|---|---|
| The feature boundary (feature law) | `invalidFeatureStructure`, `notAFeature`, `barrelFile`, `forbiddenFeatureImport` |
| The UI kit boundary | `uiKitPartMissing`, `forbiddenUiUsage`, `forbiddenUiKitImport` |
| The widget's contract with its parent | `widgetSizesItself` |
| The declared top-level layout | `invalidTopLevelLayout` |
| What ships broken with nothing to notice | `assetPathMissing`, `l10nNotWired` |
| Derived code is derived (law 6) | `generatedCodeStale`, `migrationsDrift` |

Seven further checks are warnings and one is a nudge; those are defaults, however firmly the prose around them is written. **Anything this table and the types do not hold is a default by construction** — no rule in this file or in the skills becomes law by being phrased definitely, and promoting one costs a failing check rather than a sentence.

**The gap this leaves is named rather than smoothed over.** The naming law has no check at all; the contract law is held against JSON maps and stray DTOs by the types, but nothing fails on a `DwRoute` the app calls instead of a request; "done" has only a warning (`featureSpecMissing`). `migrationsDrift` needs a Postgres (`DW_DATABASE_*`) and says it did not run rather than passing without one.

## Code generation: two generators, and no `build_runner`

The project has exactly two: **`dartway generate`** (codecs and the protocol registry in `__SHARED_PKG__`, table definitions and the schema in `__SERVER_PKG__`) and **`flutter gen-l10n`** (the typed `AppLocalizations` from `lib/l10n/*.arb`). Both are unavoidable — the first because the wire is generated, the second because the localization law is not obeyable without it — and they share three properties.

- **A separate command, not `build_runner`.** Neither watches the tree, and neither is part of the edit loop: `dartway generate` runs when a DTO or a row class changes, `flutter gen-l10n` when an `.arb` changes. Nothing runs on save. `dartway generate` runs the generator the server package resolved as a dev dependency, so it always matches the framework version the project builds against.
- **The output is committed**: `*.dw.dart` parts, `lib/generated/`, `lib/l10n/gen/`. A tree that compiles only after somebody remembers to run a generator is broken for whoever cloned it, with an error that blames their code.
- **They are run by hand, so they can be forgotten.** A field added to a data object without a `dartway generate` compiles and travels *without that field*; a new request missing from the registry is refused as unknown by a server that has its handler. `dartway generate --check` and `dartway check` (`generatedCodeStale`) say so; `flutter gen-l10n` forgotten gives `undefined getter` on a key that is plainly there.

Everything beyond those two is written by hand:

- **providers and state** — plain `Provider` / `NotifierProvider`, no `riverpod_generator`. Server data needs no provider of your own at all: `ref.watch(dw.request(const ListMyInvoices()))` is the provider, keyed by the request value, shared by every widget watching an equal request. A family key of your own is a record or a small class with `==` and `hashCode`;
- **state data classes** — a plain immutable class with `copyWith` and `==`, no `freezed`. Data objects already arrive generated with both;
- **assets** — constants in the kit, no `flutter_gen`. That a path leads to an existing file is checked by `dartway check`.

**Why against the current** (the Riverpod documentation is written around codegen): `build_runner` inserts itself into the daily edit cycle — on a production project a single provider edit cost more than four minutes of waiting. Worse, it is a trap for the agent: forgot to run the generator — got `undefined name` and started "fixing" working code.

**Families are written by hand too** — including a family notifier with methods: `NotifierProvider.family` is declared as `NotifierT Function(ArgT arg)`, that is, **the argument arrives in the factory**, and the notifier takes it through its constructor.

A project is free to decide otherwise (a large asset library, union types where `freezed` really pays off) — but that is a deliberate exception, not a default.

## Documentation: the description lives in the code

**There are no separate "a file per feature" docs in the project.** To learn about a feature, ask its code:

| What you need to know | Where to look |
|---|---|
| what the feature does, what to expect from it, where the traps are | `DwFeatureSpec` in its public file |
| what is wrong with the feature and worth picking up | `knownIssues` in that same spec |
| what a request or command means, its fields and their invariants | the doc comments on the DTO in `__SHARED_PKG__` |
| who may call it, what it changes, what it publishes and where | the doc comment above its handler in `__SERVER_PKG__` |
| who may listen to a channel, and what travels on it | the doc comments on the channel kind and on its rule |

**Why so.** A doc sitting apart from the code drifts from it silently: the compiler does not check it, the checker does not see it, and the agent reads it and believes it. On a production project such a doc described an API deleted a year earlier, and non-working code was written from it. A spec in the feature's file and a comment above the handler survive a code edit because they lie in the same diff.

**A new project gets no `docs/` folder for architecture, and most of what you would put in one belongs elsewhere.**

| What it is | Where it lives |
|---|---|
| A cross-cutting registry — analytics events, settings keys, roles | Code: an enum in `__SHARED_PKG__` when both sides use it, in `lib/core/` of the app otherwise, with doc comments. The compiler knows the list, and a typo is an error rather than a discrepancy |
| The roles and access matrix | The doc comments above the handlers and rules — the rule sits where it is enforced |
| An external integration's payload | Doc comments on the route (`DwRoute`) that receives it |
| "How this app is put together" | The skills. The methodology ships from the framework and is updated with it; a copy inside the project would only fall behind |
| A checkup report | The chat. `/dartway-checkup` writes no report file on purpose: what belongs to a feature becomes a line in its `knownIssues`, what belongs to the project goes to `docs/dev_notes/`, and the rest was worth saying once |

Before starting any document, name what it would say that a `DwFeatureSpec`, a doc comment or a piece of code cannot. Usually the answer is that the spec is silent where it should not be, and the fix is in the spec.

**`docs/` is for what survives that question.** Two kinds are known to the framework and have rules, because they are the ones that keep being reinvented.

### `docs/adr/` — the decisions, and what they ruled out

An ADR records **the alternatives that were rejected, and why**. That is the one thing which cannot live beside the code: a rejected option has no file to sit next to. What the decision *produced* is in the code already.

**The admission test is one question:** is there an alternative someone will propose again in six months? If not, this is not an ADR, and what you wanted to write belongs in a spec or a doc comment.

`docs/adr/NNNN-slug.md` — four digits, flat, written in this project's language. Each one carries:

- **Status** — `accepted` or `superseded by NNNN` — and the date;
- **Context** — what forced a choice;
- **Decision** — what was chosen;
- **Rejected alternatives, each with its reason** — without this section the document is not an ADR;
- **Limitations accepted knowingly** — what you are choosing to live with.

**Never write "how it works now".** That is the part that rots, and it rots silently, because the code changes under it without an error.

**An ADR is never edited — it is superseded by a new one**, and the old one gets `superseded by NNNN` in its status. Editing destroys the only thing it is for: what was known at the moment of the choice.

**This is a default, and a project may replace it** — see "Law and default" above. What must not be destroyed is *what was known at the moment of the choice*; a new number preserves that, and so does a change log at the end of one long-lived file. If the project has decided otherwise, its decision belongs in its root `CLAUDE.md` with the reason — **check there before opening a number**.

**Planning reads them.** `dartway-plan` looks in `docs/adr/` before proposing an approach, so a decision whose alternatives were already weighed is not re-argued from scratch — and a plan that itself makes such a choice proposes a new ADR as one of its steps.

### `docs/dev_notes/` — the findings with no address in code

A finding this project made that **does not fit the task at hand and is not confined to a single feature**: CI that runs less than it declares, a pin that trails, a config written down twice, a tendency you keep seeing.

**The admission test is whether the finding has an address in code.** Take the first line that fits:

| The finding… | Goes to |
|---|---|
| is being fixed right now | fix it — no entry anywhere |
| belongs to one feature or screen | that feature's `knownIssues` in its `DwFeatureSpec` |
| **has no address in code** — cross-cutting, infrastructural, a decision with a price | `docs/dev_notes/` |

If the finding has an address, it lives at that address, where the compiler, `dartway check`, Studio and the next reader all pass by it — one product-level sentence in `knownIssues`, deleted when the fix lands. What that field is for is written on the field itself, in `DwFeatureSpec`'s doc comment; it is not restated here.

**The defect itself lives in the tracker; a `knownIssues` line and a `docs/dev_notes/` entry only reference it.** The issue holds the status, the discussion and the pull request that closes it, and an entry repeating any of that is a second copy of a state that changes elsewhere. When the issue closes, delete the file.

`docs/dev_notes/<slug>.md`, one file per finding, no numbering, written in this project's language. Each one is short — where, what is wrong, what we did about it, and the issue:

```markdown
# <short title>

- **Issue:** owner/repo#123
- **Where:** `path/file.dart:12` — or the area, if it is not one place
- **What is wrong:** one or two sentences
- **What we did about it:** the workaround that is in place, or nothing yet
- **Possible direction:** optional, one line
```

**Committed, not git-ignored, and that is the whole design:** an ignored journal travels out through no pull request, appears in no review, and `git worktree remove` deletes it without a word. **One file per finding rather than one file appended to**, because parallel branches appending to one journal conflict on the same lines; separate files have nothing to conflict on.

`docs/dev_notes/_coverage.md` sits beside the entries and is not one: it is the table `/dartway-checkup` keeps of which features have had a deep pass, and when.

## Cleanliness and finishing

For **any** Dart/Flutter code the clean-code contract applies: `.claude/skills/dartway-clean-code/SKILL.md`. This is a style contract — check against it while writing, refactoring and reviewing.

**Clean-code decides what deserves a test; `dartway-testing` decides where it goes and how to write it** — a rule of the contract is a test in `__SHARED_PKG__`, a handler's rule is an acceptance test on a real database (`dartway test`), a feature is a widget test on the in-memory server. The skeleton ships a worked example of each.

**Finishing a task (law 7):** when a feature/task is done, run `dartway-finish` before the commit/PR. It runs the checks, audits the diff against the contract, checks the descriptions for drift and the test coverage, and **shows suggestions and applies only what was confirmed**.

## Notes back to the framework

The harness is managed and gets overwritten on update, so a rule that let you down cannot be fixed here. It also cannot be left unsaid: the rules are only ever proven wrong by real code, and this project is the real code. Such a finding is **filed as an issue in the framework tracker** — there is no local journal in between.

**Tracker:** `__NOTES_TRACKER__` — the GitHub repository this project's framework findings are filed in as issues.

**File one without being asked when:**

- the code broke a rule that does not exist, or exists too vaguely to have prevented it;
- the app had to work around a `dartway_*` API — an extra wrapper, a `hide`, a copied private helper;
- you are tempted to edit a managed file (`CLAUDE.md`, `skills/dartway-*`, the `commit` / `dartway-checkup` commands). That temptation *is* the finding.

Write it the way it would have to be written in the toolkit: the example from the code, why the existing rule did not catch it, and the concrete wording to add — not "something is off here".

### What travels, and what must not

**The part that names this codebase does not travel.** Paths, class names, what the app did as a workaround — exactly what makes the finding actionable here, and exactly what must not appear in a repository other people read. That is why a workaround leaves a record in **both** places: the issue says what should change in the framework, `docs/dev_notes/` and the marker in the code say what this project is carrying meanwhile.

So before an issue is created:

1. **Restate the finding for a stranger** — the rule that was missing, the API that forced the workaround, put so that it stands without this project's code. If nothing survives that, the finding was never about the framework and belongs in `docs/dev_notes/`.
2. **Write it in English** — the tracker is read by people who do not work on this project.
3. **Search the tracker first.** Three projects meeting one API gap is one issue with three voices, not three issues.
4. **Label what it did to you** — the two labels below, and they are part of the text you show.
5. **Show the text and wait for a yes.** This is the only irreversible step here — an issue exists publicly from the moment it is created.

**The one tracker value that is not a repository is `none`**, chosen deliberately (`dartway setup-ai --notes-tracker none`) by a project that must not push into a repository other people read. Nothing then reaches the network: the finding is written into `docs/dev_notes/` in the same form, without the issue line.

#### The two labels

**`impact:` — what the finding did to this project, not how bad it feels.** The value is remembered, not judged.

| Label | What actually happened |
|---|---|
| `impact:blocks` | It could not be worked around. Either the project cannot do what it has to, or the workaround cost more than the feature and the feature was dropped |
| `impact:workaround` | It was worked around, and the code carries the marker to prove it. The day the fix lands upstream, that code starts duplicating the framework |
| `impact:friction` | It works, but the API pushes you to write the wrong thing, or the documentation says something untrue. Nobody was blocked and there was nothing to work around |

**`silent` — it breaks with no error attached.** Orthogonal to impact. Nothing announced the defect — no exception, no red test, no line in a log — so it was found by eye, months later, if at all.

**None of this ranks your finding against anyone else's.** The labels record what happened to this project; which issue is picked up first is decided where the queue lives. **A gap another project has already filed gets a comment, not a second issue**: your impact in one line, and the label rises to the worst voice on the issue if yours is worse.

### A workaround over a `dartway_*` API also leaves a marker in the code

The issue records that the framework should change. It does not record whether this project's workaround is still needed — and that is the half which goes wrong, because the framework moves while the project's code does not. The day the fix lands upstream the workaround keeps running, now duplicating the framework, and nobody is looking.

So the code carries a marker naming the framework version the workaround was last confirmed against:

```dart
// TODO(dartway, checked: 0.20.0): <what we work around, what should appear upstream>
```

- **`checked:`** — the version of the framework this workaround was last verified against: the version number for a pub dependency, the resolved ref for a git one.
- **The sentence** — what the app is doing instead, and what would have to exist upstream for the workaround to go.

The marker and the `docs/dev_notes/` entry are two halves of one record. Write both. `dartway-finish` compares `checked:` against the version resolved in `pubspec.lock` and raises the marker **only when the two have diverged**.

## Migrations: a project that lives by an older version of a law

A law is written for a clean start, and says nothing to a project that already grew under the previous wording. Two rules cover that gap:

- **Legacy moves as you touch it, never as a sweep.** Refactored a feature — bring along what it drags with it. Converting a whole folder at once is a separate task a human asks for.
- **A gap you left is said out loud.** Decided not to touch the legacy — say so in the report.

An entry below answers three things, in this order: **how to tell** the project still has the old shape (something greppable), **what the target is**, and **what to do with what has already accumulated**. Delete an entry once no project is on the old shape.

- **Blocks inside zones → `lib/shared/` (feature law).** *You have the old shape if:* a zone contains a `common/`, `shared/` or `widgets/` folder, or `dartway check` reports `featureSpecMissing` for folders whose passport would only restate the class name. *Target:* only features in a zone, building blocks in `lib/shared/`, a block described by a doc comment. *A passport with nothing in it is deleted with the move, not reworded.*

- **State and queries out of zones → `core/` and `shared/` (feature law).** *You have the old shape if:* `dartway check` reports `notAFeature` — a folder in a zone whose entry point declares no widget. *Target:* state that several features watch is wiring, so `lib/core/`; a helper with no story of its own is a building block, so `lib/shared/`. *What has accumulated:* move it as you touch the feature that reads it — a provider named in tests through `overrideWith` stays a named provider, it just changes address.

- **An unlocalized app → the localization law (Flutter section).** *You have the old shape if:* `dartway check` reports `l10nNotWired`, or `grep -r 'context\.l10n' __FLUTTER_PKG__/lib` finds nothing while the widgets are full of readable strings. *Target:* the wiring the law lists, and every user-visible string coming from `context.l10n` or `appL10n`. *What has accumulated:* **the wiring goes in one commit, the strings screen by screen.** Every widget test that builds its own `MaterialApp` starts failing at the first lookup — fix it in the shared test harness, not in each test. The first `.arb` is written in whatever language the app's strings are already in, or the migration turns into an unasked-for translation.

- **The two root journals → `docs/dev_notes/` and the tracker.** *You have the old shape if:* `ls dartway_notes.md dev_notes.md` finds either one at the project root. *Target:* a finding about the framework is an issue in the tracker; a finding of this project's own is one tracked file under `docs/dev_notes/`. *What has accumulated:* both journals were git-ignored, so **read them before anything else touches the working copy** — they are the one copy that exists. Every open `dartway_notes.md` entry becomes an issue under the filing rules above (entries that already carry an `**Issue:**` line only need their issue's state checked); every open `dev_notes.md` entry becomes a file under `docs/dev_notes/`, and its coverage table moves into `docs/dev_notes/_coverage.md`. Then delete both files and their `.gitignore` lines. `dartway setup-ai` reports the journals while they are still there.

## Skills and commands

- Skills (`.claude/skills/`): `dartway-requirements`, `dartway-plan`, `dartway-run`, `dartway-feature-scaffold`, `dartway-contract`, `dartway-server`, `dartway-data-layer`, `dartway-realtime`, `dartway-access`, `dartway-migrations`, `dartway-uploads`, `dartway-testing`, `dartway-navigation`, `dartway-ui-kit`, `dartway-clean-code`, `dartway-on-device`, `dartway-push-delivery`, `dartway-finish`, `dartway-update` — loaded by relevance to the task.
- Commands (`.claude/commands/`): `/dartway-checkup` — the state of the project and what to take into work next (whole project by default, a path narrows it); `/commit` — a commit in the project's format.

**Task lifecycle:** `dartway-requirements` (analyze the spec → questions → options) → `dartway-plan` (a step-by-step plan + risks) → implementation (`dartway-feature-scaffold`, and the layer skills: `dartway-contract` → `dartway-server` → `dartway-data-layer`, with `dartway-realtime`, `dartway-access`, `dartway-migrations`, `dartway-uploads` where the feature reaches them) → `dartway-finish` (checks, audit, descriptions reconciled with the code, tests) before the PR.

**Moving onto a newer framework** is its own job, not part of a task: `dartway-update` installs the toolkit, reads the framework's migration notes, makes the edits they ask for and only then moves the package versions. Run it when `dartway update` says this project is behind.

**"It works in the simulator and not on my phone"** — `dartway-on-device`: what the iOS simulator, a desktop browser and a widget test all fail to reproduce. Read it by the symptom — the keyboard not coming up, the screen jumping when a field is tapped, a sheet that blinks and reopens.

**Bringing the project up locally** (a fresh clone, "it won't start", after a row change) — `dartway-run`: the database and storage, the server with its migrations, the first administrator, the app, and the typical failures. A liveness check is mandatory — report it as a fact (`/health` answering `200`, the applied migrations), not as an assumption.

## Git

PRs and diffs go against the `__BASE_BRANCH__` branch. The first line of a commit: `<type>(<scope>): <description in English>` — `type` = `feat`/`fix`/`chore`, the scope optional. Whether commits also carry a ticket, and whether anything checks the format, is this project's own convention and is stated in its root `CLAUDE.md` rather than assumed by the toolkit.

---

## Shared (`__SHARED_PKG__`)

**The contract, and nothing but pure Dart.** It depends on the framework's shared package and on nothing that knows a platform: ❌ Flutter, the server, IO, a database. The app and the server both import it, so anything else here makes it usable by one side only — which is the opposite of what it is for.

- **What goes here:** data objects (`DwDataObject`), requests (`DwSingleRequest`, `DwMaybeRequest`, `DwListRequest`, `DwPageRequest`, `DwTableRequest`, `DwWindowRequest`), commands (`DwActionCommand`); the enum of live channel kinds (`with DwChannelKind`), of refusal codes (`with DwRefusalCodes`), of upload purposes (`with DwUploadPurpose`); validation both sides run (`DwSelfValidating`); computations over fields without IO. The public API is `lib/__SHARED_PKG__.dart`, the implementation `lib/src/`, the generated registry `lib/generated/`. Playbook — `dartway-contract`.
- **A request's fields are its complete filter**, and a request is a value: the client caches and shares its live state under the request itself. `channels`, `matches`, `sort` and `positionOf` are pure functions of the object and the fields — `DateTime.now()` inside them is a bug.
- **A command never carries what the server decides** — the owner, timestamps, a status, a storage key. The handler derives them from the context.
- **"My …" requests carry no account id**: the server reads the caller, and the channel is `DwLiveChannel.ofCaller(kind)`.
- **A DTO change is a change to installed apps.** An app build keeps calling with the contract it was compiled with: adding a field with a default is safe; renaming or removing a field, a DTO or a refusal code breaks the builds already installed — raise the server's minimum app build (`DwServerSettings.minAppBuild`) so they are shown "update the app" instead of failing.
- **Adding a path dependency means adding it to both Dockerfiles.** The images are built from the project root and copy package directories by name; one that is never named does not enter the build context, and `pub get` inside the image fails three layers from the cause.

## Server (`__SERVER_PKG__`)

**The top level of `lib/` is a closed list:** `__SERVER_PKG__.dart` (the library), `generated/` (**do not edit**) and `src/`. Inside `src/` the project arranges handlers, rows and domain areas as its domain asks, except `src/migrations/`, which `bin/migrate.dart` reads and writes by that path. `dartway check` enforces it as `invalidTopLevelLayout`.

- **Handlers:** one `DwCallHandler` per request and command, each with an explicit `DwAccessRule` (`signedIn`, `anonymous` only for what a stranger may do, `check` for rules on the call's real parameters). Commands are transactional by default: lock the rows a decision depends on (`DwRowLock.forUpdate`) before deciding. Refuse with `ctx.refuse(<Project>Refusal.…)`; someone else's row does not exist for the caller. Playbook — `dartway-server`.
- **Rows → data objects in batch**: related rows load with `findByIds`, one query per relation for the whole batch, never per row — there are no joins. The mapping is written once and used by reads and by what commands publish.
- **The caller's notions are the project's**: the profile and its role come from a `DwCallContext` extension cached with `memo`, read once per call.
- **Publish what a command changed** to every channel that shows it, after commit (`ctx.publish`); publish to someone's "my" channel with `DwLiveChannel.forAccount`; close access that was removed with `ctx.revoke`. A request never publishes. Playbook — `dartway-realtime`, access in `dartway-access`.
- **Accounts, identities and session keys are the framework's.** The profile row references the account; it is created in `onAccountCreated`, in the same transaction as the account. A project never queries `dw_*` tables: `DwAccountService` (`ctx.accounts`) is the whole surface.
- **The schema moves by migrations**: a row class changes → `dartway generate` → `dart run bin/migrate.dart create <name>` → review the draft → `check`. The server applies pending migrations as it starts and refuses to start on a missing, changed or dirty one. Playbook — `dartway-migrations`.
- **Configuration is the environment** (`DW_DATABASE_*`, `DW_STORAGE_*`, the project's own); there is no configuration file, and secrets are never printed.

## Flutter (`__FLUTTER_PKG__`)

**The top level of `lib/` is a closed list: two files, four zones, four layers.** Files — `main.dart` (the environment: backend URL, version) and `__FLUTTER_APP_FILE__` (all the wiring). Zones, which hold features and are the only places asked for a `DwFeatureSpec` — `app/` (the app itself) · `admin/` (the admin panel) · `auth/` (signing in) · `common/` (features more than one zone draws on). Layers — `core/` (router, the `dw` core, the signed-in profile, app settings, refusal texts, and `core/platform/` for a conditional-import trio: `x.dart` exporting `x_stub.dart` / `x_web.dart`) · `shared/` (building blocks: widgets and helpers with no story of their own, extensions on data objects included) · `ui_kit/` · `l10n/`.

Nothing else may sit at the top level, and nothing may carry one of those names lower down: `app/admin/` is not the admin panel, it is a group that has quietly left every check written for zones. There is **no `data/`** (the data layer is `dw.request` and `dw.command` over the contract) and **no `domain/`** (the rules live in the shared package, where both sides apply them, and in the server's handlers). A fifth navigation zone in the router does not earn a folder — it is a group inside `app/`. `dartway check` enforces all of this as `invalidTopLevelLayout`.

- **Features:** a feature = an entry point (one public file) + `widgets/` + `logic/`. From outside, import **only the entry point**. The entry-point widget declares the feature spec (`implements DwFeature` with a `DwFeatureSpec`) right in its own file. Skill — `dartway-feature-scaffold`.
- **Data:** reads are `ref.watch(dw.request(request))` (`dw.pages`, `dw.table`, `dw.window` for the paginated kinds), live by their channels; changes are `dw.command(command)` inside `dw.action`, which shows a refusal through the project's refusal texts. No repository classes, no hand-written HTTP, no copies of server state in a notifier. A read the screen exists for renders its error state — a failed read must not look like an empty one. The contract — `dartway-data-layer`.
- **`ProviderScope` is not written by the app.** The only one belongs to `DwAppRunner`; tests may create their own with `overrides:`. A nested scope looks like it works — widgets under it do read the override — but a provider reaching the same provider through `Ref` starts from the root container and silently gets the base value. **A value that must differ per subtree travels as a family key or a constructor argument.** Enforced by `forbidden_provider_scope` (`dartway_lints`).
- **The UI Kit is the only source of styles:** in the zones and in `shared/`, direct `Color`/`TextStyle`/`BorderRadius`/`context.textTheme`/`context.colorScheme` are forbidden; the only import is `ui_kit.dart`. Skill — `dartway-ui-kit`.
- **Every project is localized, and user-visible text is never written in code.** This is a requirement on the project, not a report on how it began. What has to be present: `flutter_localizations` and `generate: true` in the Flutter pubspec, `l10n.yaml` and `lib/l10n/*.arb` with its generated output committed beside them, `appLocaleProvider` (the system locale when supported, the first supported one otherwise), `context.l10n` in widgets and `appL10n` for code outside the tree — an error toast, a refusal text. `dartway check` reports a missing piece as `l10nNotWired`, an error.

  **Refusals are texts of the app.** The server sends codes with parameters; `lib/core/` maps every code — the project's `<Project>Refusal`, the framework's `dw.*` codes — to a localized string, and `DwConfig.refusalText` hands that mapping to the core. A code without a text is a user staring at a code.

  **The law reaches as far as the app does, and no further.** Text composed on the *server* — a sign-in code message, an e-mail — is outside it: there is no `appL10n` there. That text has no rule yet, which is a gap named rather than covered; a project sending server-composed text in more than one language decides for itself how, and says so where its next reader will look.

  A project with one language keeps one `.arb` and pays nothing. New strings are added to **every** `.arb`, then `flutter gen-l10n` is run and its output committed.

  **A widget test mounts three things, not two:** `localizationsDelegates`, `supportedLocales`, **and an explicit `locale:`**. Without the third the test resolves against the locale of the machine it runs on, so an assertion on the skeleton's text passes for the author and fails for whoever else runs the suite. The skeleton's `test/support/` harness does it in one place; the rest is in `dartway-testing`.

  **A string the user reads is content, not decoration** — so `ui_kit` may not hold it and a feature may not hardcode it. `AppText.body(context.l10n.issuesTitle)`, never `AppText.body('Issues')`. Outside the kit this is not mechanically enforced (telling `'Issues'` from `'issues/board'` takes reading the meaning); `/dartway-checkup` looks for it. Inside `ui_kit/` `dartway check` reports it as `uiKitContainsText`; strings in the `fontFamily` and `fontFamilyFallback` positions are exempt.
- **Navigation:** the DartWay Router — enum routes, enum parameters, guards centralized. One exception, and it is a fact rather than a preference: a transition nobody started from the tree — a tapped notification, a deep link — has no context to go through, and takes the navigation function from the router in one seam per application, in `core/`. Skill — `dartway-navigation`.
- **Specials:** notifications — `dw.notify.*` (not `SnackBar`); actions from the UI — `dw.action`; sign-out — `dw.signOut()`; the signed-in account — `dw.accountId`; "update the app" — `DwConfig.updateRequiredScreen`, shown by the core when the server refuses this build.
- **The web shell (`web/index.html`) is part of the app, not scaffolding.** It is outside `lib/`, which is the only reason it reads as something the build generates. The skeleton ships it with a scroll lock the app depends on: without that block, focusing a text field on iOS takes the app off the screen, silently and only on a real phone. Anything that regenerates the shell drops it — `grep -q 'focusin' web/index.html` is the check, and `dartway-on-device` has the mechanism.
