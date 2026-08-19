---
name: dartway-models
description: >-
  Server-side Serverpod YAML models in DartWay: .spy.yaml files in lib/src/models/<domain>/,
  enums in enums/. Base vs Event models (current state vs changes on top of the base — for money/
  transactions), field types and nullable discipline (nullable only if the value is genuinely absent
  in the domain), 1-1/1-N/N-N relations via relation(name=...) (bidirectional — the same name on both
  sides), onDelete=Cascade, indexes/unique, default= (and why it makes copyWith the only way to
  rebuild a stored model), enum models (serialized: byName). Workflow:
  edit YAML → serverpod generate → create-migration → dart format over the generated paths (in that
  order: create-migration regenerates, and the generator's dart_style is not the project's) →
  DwCrudConfig + registration in crudConfigurations → migrations at startup. Use when creating or
  changing models, fields, relations, enums and the DB schema.
---

# DartWay — models (Serverpod, server)

**Domain-first:** every feature starts with its model(s) (Law 2). A model reflects domain reality, not the momentary needs of the UI. The schema is the single source; Flutter models are generated from it, never duplicated by hand. See also `__SERVER_PKG__/CLAUDE.md` and `dartway-crud-config`.

## Where models live

- Files — **`lib/src/models/<domain>/<model>.spy.yaml`** (the extension is `.spy.yaml`, not just `.yaml`).
- Domain enums — in an `enums/` subfolder next to them (`.spy.yaml` with `enum:`).
- A class name is at least 2 words (`UserProfile`, `AnalyticsEvent`), `table` is snake_case.

## Model structure

```yaml
class: UserProfile
table: user_profile
fields:
  createdAt: DateTime
  userIdentifier: String
  telegramId: String?              # nullable — the value genuinely may be absent
  isAdmin: bool, default=false     # default for a non-nullable with a sensible value
  email: String?
  quizFinancialGoal: FinancialGoal?    # reference to an enum model
  courses: List<UserCourse>?, relation(name=user_profile_courses)   # 1-N
  completedLessonsIds: List<int>?      # primitive list — no relation
indexes:
  user_profile_email_index:
    fields: email
    unique: true
```

## Nullable discipline (important)

**Why:** nullable fields infect the whole stack with `?`/`!` checks. Make a field nullable **only if the value genuinely may be absent in the domain**.

```yaml
# ❌ nullable "for the convenience of editing a form"
title: String?      # even though the entity always has a title
# ✅ for form state on Flutter — a separate form model; in the domain model the field is required
title: String
# ✅ a default instead of nullable, when there is a meaningful default value
isDeleted: bool, default=false
```

**What `default=` does to the generated code — and why the rebuild rule follows from it.** A field
with a default (and any nullable field) becomes an **optional** argument of the generated
constructor. So a method that rebuilds an existing model by naming its fields keeps compiling when
you add a field here, and silently writes the default into it — a real project reset a `priority`
field on every single edit that way, and nothing but an audit could see it. Hence: **a stored model
is rebuilt with `copyWith`, never by listing its fields.** See `dartway-clean-code` §1.10;
`model_rebuild_by_constructor` (`dartway_lints`) reports the shape in the editor.

**Exception — relation object fields.** For them `?` means not "may be absent in the domain" but "the object may not be loaded" (without `include` it does not arrive at all). Do not apply the rule above to them: almost always write `?`.

```yaml
service: ClubService?, relation      # ✅ this is exactly right, even if the service is mandatory
coachProfile: UserProfile?, relation
```

Whether a relation is mandatory is defined not by `?` but by the generated FK: from the declaration above the generator produces a **required** `serviceId` / `coachProfileId`. That is, `ClubSession(serviceId: ..., coachProfileId: ...)` cannot be constructed without them, while `clubSession.service` stays null until you query with `include`. Two orthogonal notions: `?` is about loading, the FK is about the domain.

## Base vs Event models

**Why:** for transactional/money flows it is dangerous to change a base model's field directly (races, no audit trail, rules smeared around). An Event model records **a change on top of the base**.

- **Base** — the entity's current state (`UserProfile`).
- **Event** — an event/change (`AnalyticsEvent`, `BalanceEvent`). Do not change `UserProfile.balance` directly — create a `BalanceEvent`: safety from races, an audit trail, a single place for business rules (of the 3 levels of increasing logic complexity, Event models come first, before CRUD configuration and long before custom endpoints).

## Relations (always explicit)

**Why:** relations are described in the schema, not derived from ids by hand. A bidirectional relation means **the same `relation(name=...)` on both sides**.

```yaml
# UserProfile (one side of 1-N)
courses: List<UserCourse>?, relation(name=user_profile_courses)

# UserCourse (the other side — the same name)
userProfile: UserProfile?, relation(name=user_profile_courses, onDelete=Cascade)
course: LearningCourse?, relation(onDelete=Cascade)   # one-way reference — name is not required
```

- 1-1 / 1-N / N-N — all explicit. `onDelete=Cascade` — cascading deletion of dependents.
- Fields relating to the user carry the word **Profile** in the name (`userProfileId`, `authorProfileId`) — naming law 5.

## Enum models

```yaml
enum: AnalyticsAccessType
serialized: byName        # byName — resilient to reordering values (preferred)
values:
  - free
  - paid
  - trial
```

**A `default=` may not name a value that is closed.** When a path is retired — legally, commercially, or because it was replaced — the enum keeps the value for the rows that already carry it, and the default moves the same day. Otherwise every record created from then on is stamped with the way you decided not to do things, and nothing complains: it compiles, it saves, it looks deliberate. A real project kept `default=subscription` on its agent-auth enum for the whole time that path was known to be unusable, and the discrepancy surfaced in an audit rather than in a test. Retiring a value: change the default in the same change that closes the path, then migrate the existing rows, then remove the value once nothing references it.

## Model change workflow

1. Edit/add a `.spy.yaml` in `lib/src/models/<domain>/`.
2. `serverpod generate` — updates the generated code + `__CLIENT_PKG__`.
3. `serverpod create-migration` (`--force` only in early MVP, if the old migrations can be overwritten).
4. `dart format lib/src/generated ../__CLIENT_PKG__/lib/src/protocol` — **the order of 2–4 is fixed, see below.**
5. Set up `DwCrudConfig` in `/crud` (see `dartway-crud-config`) and **register it in `crudConfigurations`** at `DwCore.init` — otherwise the API returns `notConfigured`.
6. Logic: `/domain` (pure) or `/app` (session-aware).
7. Migrations are applied at startup (`--apply-migrations`) or via `serverpod migrate`.
8. Tests (unit tests for the config and Event models).

**`serverpod` is a command, not a `dart run` target.** The `serverpod` package the server depends
on is the runtime and carries no `bin/serverpod.dart`; the generator is a separate package,
`serverpod_cli`, activated globally (`dart pub global activate serverpod_cli`). `dart run serverpod
generate` therefore answers `Could not find bin/serverpod.dart in package serverpod`, which reads
like a broken project rather than a wrong command. **Its version has to match the `serverpod`
constraint in `__SERVER_PKG__`** — `dart pub global list` says which one is installed. The CLI
writes generated code for its own version, bundling its own `dart_style`, so a CLI that has
drifted from the runtime produces code that compiles and misbehaves.

### Why formatting is a step, and why it is the last one

**The generator does not format its output the way the project does.** `serverpod generate` runs the
`dart_style` bundled with the Serverpod CLI; the code in the repository was written by the
`dart format` of the project's SDK. The two disagree about things like whether a trailing comma
keeps an argument list split — so the moment you generate, files nobody touched come back rewritten.
Making one field nullable is a two-line change to the schema and, without step 4, a diff of **29
files and ~1900 lines**. On review that reads as "rewrote the whole protocol", and the two lines that
matter are unfindable inside it.

**`create-migration` regenerates too.** It is not a separate tool reading what step 2 left behind —
it re-runs the generation to diff the schema, and rewrites the same files with the same formatter.
Format between steps 2 and 3 and step 3 quietly undoes it. That is the second half of the trap, and
it is what turns the mistake into a loop: generate → format → generate → format again.

Hence: **generate, migrate, and only then format** — one pass, in that order, every time.

**Both packages, always.** The server's `lib/src/generated/` and the client's `lib/src/protocol/`
are one artefact written by one command, and they are held to one rule: formatted. Formatting only
the half you were looking at is worse than formatting neither — the next person to run `dart format`
over both picks up your other half as their diff. One project had exactly that: a server tree kept
formatted, a client tree left raw, and the first honest `dart format` added 33 unrelated files to
someone else's pull request.

`dartway check` verifies this (`generatedCodeUnformatted`) — see `dartway-finish`.

## Model checklist

- [ ] A `.spy.yaml` file in `lib/src/models/<domain>/`; enums in `enums/`.
- [ ] Class name ≥2 words; `table` snake_case.
- [ ] Nullable only if the value is genuinely absent in the domain (not "for the form's sake"); where appropriate — `default=`.
- [ ] Existing rows are rebuilt with `copyWith`, not by listing the fields in the constructor — `default=` and nullable make those arguments optional, so a forgotten field is a silent default (`dartway-clean-code` §1.10).
- [ ] Relations are explicit; bidirectional ones use the same `relation(name=...)` on both sides; fields relating to the user carry the word `Profile`.
- [ ] Transactional/money logic goes through an Event model, not a direct field update.
- [ ] After editing: `serverpod generate` → `create-migration` → `dart format` over both generated paths; the new model is added to `crudConfigurations` with a `DwCrudConfig`.
- [ ] After generation `git diff --stat` shows only the models the task touched — if it lists files the change has nothing to do with, the formatting step was skipped or ran before `create-migration`.
- [ ] Enum — `serialized: byName`.
