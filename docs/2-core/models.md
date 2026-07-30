# Where does the data model live?

In one place: a `.spy.yaml` file on the server. Serverpod generates the table, the typed query API,
the server class and the client class from it, so the Flutter side never declares a model of its
own. There is no DTO layer to keep in step, and no mapper to forget — the schema is the single
source, and a mismatch between client and server is a compile error rather than a runtime surprise.

That is also why a DartWay feature starts with its model rather than its screen. The CRUD config,
the live list and the widgets all hang off the generated type; until it exists there is nothing to
configure or watch.

## The file

```
lib/src/models/<domain>/<model>.spy.yaml
lib/src/models/<domain>/enums/<enum>.spy.yaml
```

`lib/src/models` is one of the roots Serverpod scans. The extension is `.spy.yaml`: a plain `.yaml`
is accepted too, but every DartWay project uses the `.spy` form, so a schema is never confused with
a configuration file sitting nearby. Grouping by domain folder is a DartWay convention:
`models/booking/`, `models/chat/`, `models/schedule/`. Class names
are PascalCase and, by convention, at least two words (`ClubSession`, `NewsPost`, `AppSetting`);
`table` is snake_case.

```yaml
class: ClubSession
table: club_session
fields:
  service: ClubService?, relation
  coachProfile: UserProfile?, relation
  startsAt: DateTime
  # 1 = personal appointment, N = group class capacity.
  capacity: int
```

## Nullable is a domain statement, not a convenience

Every `?` you add propagates: null checks in the config, `!` in the widget, a branch in every
`copyWith`. Make a field nullable only when the value is **genuinely absent in the domain** — a
middle name, an optional image.

```yaml
title: String                  # the entity always has one
imageUrl: String?              # it may genuinely have none
role: UserRole, default=client # a default beats a nullable when a sensible one exists
```

`default=` also accepts database-side expressions: `createdAt: DateTime, default = now`, as in the
framework's own `DwAuthRequest`.

If a form needs a half-filled state, that is a *form* model on the Flutter side, not a loosened
domain model. Loosen the schema for the form and every consumer of the model pays for it forever.

## Relations: `?` means "not loaded", the FK means "required"

The one exception to the nullable rule. On a relation field, `?` says the object **may not have been
fetched**, not that it may be absent in the domain — so relation fields are written with `?` almost
without exception.

```yaml
service: ClubService?, relation
```

From that single line the generator produces two members with opposite obligations:

```dart
factory ClubSession({
  int? id,
  required int serviceId,        // the FK — mandatory, this is the domain rule
  ClubService? service,          // the object — null until you query with include
  ...
});
```

You write the id, you read the object. `service` stays `null` until a read config asks for it:

```dart
include: ClubSession.include(
  service: ClubService.include(),
  coachProfile: UserProfile.include(),
),
```

Forget the `include` and nothing breaks loudly — the field is simply null, and the UI renders a gap.
`include` belongs in the CRUD config, so it is decided once per model rather than per call site.

Other relation options carry real semantics: `onDelete=Cascade` removes dependents with the parent,
`field=` names the FK column explicitly, and a bidirectional (list) relation requires the same
`relation(name=...)` on both sides.

```yaml
message: DwPushMessage?, relation(field=messageId, onDelete=Cascade)
```

Two naming rules earn their place. Fields pointing at a user carry the word **Profile** —
`authorProfileId`, `clientProfileId`, `coachProfileId` — which keeps them distinct from Serverpod's
own auth user id. And avoid the field name `session`: the generated helpers already take a `session`
parameter, so the example's booking calls its link `clubSession`.

## Enums

```yaml
enum: BookingStatus
serialized: byName
values:
  - booked
  - cancelled
  - attended
```

`serialized: byName` stores the name rather than the ordinal, so inserting a value in the middle of
the list later does not silently rewrite the meaning of every existing row.

## Scopes: fields the client must never see

```yaml
testVerificationCode: String?, scope=serverOnly
password: String?, !persist
```

`scope=serverOnly` keeps the field out of the generated **client** class entirely — it is not
withheld at runtime, it does not exist there, so no accidental read is possible. `!persist` is the
opposite direction: the field travels over the wire but is never written to a column, which is how
`DwAuthRequest` carries a password to the server without it ever landing in the database.

## Base and Event models

A base model holds current state — `UserProfile`, `ClubSession`. An **event** model records a change
on top of it: an attempt, a movement, a transition.

The distinction matters for anything transactional. Updating `UserProfile.balance` in place gives
you a lost update under concurrency, no audit trail, and rules smeared across every place that
touches the field. Recording a `BalanceEvent` row instead gives one insert whose save config owns
every rule, and a history you can replay.

DartWay's own auth is built this way: the client saves a `DwAuthRequest` — one row per attempt, with
`createdAt`, `status` and `failReason` — and the flow lives in that model's save config. Nothing is
mutated in place, so a rate limit is a query over recent rows rather than a counter someone has to
keep correct.

The same instinct applies to deletion. A booking in `example/` is never deleted; it moves to
`BookingStatus.cancelled` — the transition is auditable, and it can be made race-safe, which a
delete cannot ([crud-configs.md](crud-configs.md#deleting)).

## The workflow, and where it usually goes wrong

```bash
serverpod generate           # models, table classes, client package
serverpod create-migration   # a migration from the schema diff
dart bin/main.dart --apply-migrations
```

Then write the `DwCrudConfig` in `lib/src/crud/` and **register it in `crudConfigurations`** at
`DwCore.init`. A generated model with no registered config is invisible to the API: every call
answers `notConfigured`. That is the single most common "my new model does not work" — the schema is
fine, the client is generated, and the config was never added to the list.

Run `serverpod generate` with the CLI version the project is pinned to. A CLI that is newer than the
runtime writes generated code for its own version, and the mismatch surfaces as silent
deserialization bugs rather than a build failure.
