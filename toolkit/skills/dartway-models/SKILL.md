---
name: dartway-models
description: >-
  Server-side Serverpod YAML models in DartWay: .spy.yaml files in lib/src/models/<domain>/,
  enums in enums/. Base vs Event models (current state vs changes on top of the base — for money/
  transactions), field types and nullable discipline (nullable only if the value is genuinely absent
  in the domain), 1-1/1-N/N-N relations via relation(name=...) (bidirectional — the same name on both
  sides), onDelete=Cascade, indexes/unique, default=, enum models (serialized: byName). Workflow:
  edit YAML → serverpod generate → create-migration → DwCrudConfig + registration in crudConfigurations
  → migrations at startup. Use when creating or changing models, fields, relations, enums and the DB schema.
---

# DartWay — models (Serverpod, server)

**Domain-first:** every feature starts with its model(s) (Law 2). A model reflects domain reality, not the momentary needs of the UI. The schema is the single source; Flutter models are generated from it, never duplicated by hand. See also `__SERVER_PKG__/CLAUDE.md`, `dartway-crud-config`, and `docs/1_general/SERVER_ARCHITECTURE.md` if the project keeps one.

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

## Model change workflow

1. Edit/add a `.spy.yaml` in `lib/src/models/<domain>/`.
2. `dart run serverpod generate` — updates the generated code + `__CLIENT_PKG__`.
3. `dart run serverpod create-migration` (`--force` only in early MVP, if the old migrations can be overwritten).
4. Set up `DwCrudConfig` in `/crud` (see `dartway-crud-config`) and **register it in `crudConfigurations`** at `DwCore.init` — otherwise the API returns `notConfigured`.
5. Logic: `/domain` (pure) or `/app` (session-aware).
6. Migrations are applied at startup (`--apply-migrations`) or via `dart run serverpod migrate`.
7. Tests (unit tests for the config and Event models).

## Model checklist

- [ ] A `.spy.yaml` file in `lib/src/models/<domain>/`; enums in `enums/`.
- [ ] Class name ≥2 words; `table` snake_case.
- [ ] Nullable only if the value is genuinely absent in the domain (not "for the form's sake"); where appropriate — `default=`.
- [ ] Relations are explicit; bidirectional ones use the same `relation(name=...)` on both sides; fields relating to the user carry the word `Profile`.
- [ ] Transactional/money logic goes through an Event model, not a direct field update.
- [ ] After editing: `serverpod generate` → `create-migration`; the new model is added to `crudConfigurations` with a `DwCrudConfig`.
- [ ] Enum — `serialized: byName`.
