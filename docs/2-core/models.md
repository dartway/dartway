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

## An existing row is rebuilt with `copyWith`, never field by field

This one follows from the section above, and it is the most expensive consequence of it. A field with
`default=`, and any nullable field, becomes an **optional argument** of the generated constructor. So
a method that rebuilds a model by naming its fields keeps compiling when the model grows a field —
and quietly writes that field's default into every row it touches.

```dart
// ❌ add `priority` to the model and this silently resets it on every save
repository.save(FeatureRequest(
  id: request.id,
  title: request.title,
  status: RequestStatus.approved,
));

// ✅ a field nobody mentioned keeps its value, whatever the model grows next
repository.save(request.copyWith(status: RequestStatus.approved));
```

One project reset a `priority` field to its default on every single edit of the record it belonged
to — for months, on the field its backlog was sorted by. Nothing could see it: the code compiled, the
tests passed, the review read fine. The method even carried a doc comment asking for the opposite;
the field had been added by a different task that never opened that file.

**Nothing is lost by the rule.** The one argument for rebuilding by hand — *"`copyWith` reads null as
'not passed', and I need to clear a nullable field"* — is not true of the generated one. It takes
`Object? field = _Undefined` and tests `field is T? ? field : this.field`, so:

```dart
request.copyWith(assigneeProfileId: null);   // cleared
request.copyWith(status: RequestStatus.approved);  // assignee untouched
```

`model_rebuild_by_constructor` ([`dartway_lints`](../5-tooling/conventions-checker.md), warning) says
this in the editor: a model constructor passed a non-null `id:` is a rebuild, because a row being
created has no id yet — it comes back from the database.

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
serverpod create-migration   # a migration from the schema diff — regenerates as well
dart format lib/src/generated ../my_app_client/lib/src/protocol
dart bin/main.dart --apply-migrations
```

The third line is part of the sequence, not a tidy-up, and it has to be the third line. The
generator formats what it writes with the `dart_style` bundled with the Serverpod CLI, while the
code already in the repository was formatted by the `dart format` of the project's SDK. The two
disagree — over trailing commas and line splitting — so a generation run comes back having rewritten
files the change never went near. Making one field nullable is two lines of schema and, without the
format pass, a diff of 29 files and about 1900 lines: on review that reads as a rewritten protocol,
and the two lines that matter cannot be found inside it.

Why it goes after `create-migration` rather than straight after `generate`: `create-migration` is not
a separate tool reading what generation left behind — it regenerates in order to diff the schema,
and rewrites the same files with the same formatter. Format in between and the migration step undoes
it, which is how this turns from a missing step into a loop.

Format **both** paths, always. The server's `lib/src/generated/` and the client's
`lib/src/protocol/` are one artefact written by one command; a repository that keeps one of them
formatted and the other raw simply defers the diff to whoever next runs `dart format` honestly —
in one project that was 33 unrelated files landing in someone else's pull request. `dartway check`
holds the rule (`generatedCodeUnformatted`), and `git diff --stat` after generating is the quick
version: it should name the models you touched and nothing else.

Then write the `DwCrudConfig` in `lib/src/crud/` and **register it in `crudConfigurations`** at
`DwCore.init`. A generated model with no registered config is invisible to the API: every call
answers `notConfigured`. That is the single most common "my new model does not work" — the schema is
fine, the client is generated, and the config was never added to the list.

Run `serverpod generate` with the CLI version the project is pinned to. A CLI that is newer than the
runtime writes generated code for its own version, and the mismatch surfaces as silent
deserialization bugs rather than a build failure.
