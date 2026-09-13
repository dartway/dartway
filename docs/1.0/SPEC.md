# DartWay 1.0 — specification

Status: **draft for review**. Every section is marked:

- **Decided** — settled by the owner; implement as written.
- **Proposal** — the author's design for a question not yet discussed; review and correct before implementation.
- **Open** — needs a decision before the phase that depends on it.

This document is the single source for the 1.0 rewrite. The implementation lives on the `dartway-1.0` branch and follows it; when the two disagree, the document is fixed first.

---

## 0. What 1.0 is

DartWay 1.0 is the framework rebuilt as if Serverpod had never existed: the same promise — one language, a secure-by-default server, a client that needs no hand-written repository — on a stack the framework owns end to end.

It is built on one branch, all at once, not migrated in steps. `example/` and `template/` are rebuilt on the branch alongside the packages. Active projects (Molodey first, then U90) move onto it in their own branches, are debugged there, and the release is global.

### 0.1 Principles (Decided)

1. **Engineering perfection.** No redundant operation, no redundant update, no byte on the wire the receiver did not ask for. A design that is simpler because it sends or computes more than necessary is not the default.
2. **The framework knows no domain.** It does not know the project's user model, its roles, its texts, its languages or its channels. Everything project-specific is declared in the project's shared package; the framework ships interfaces, mixins and mechanisms. The template shows how a project fills them.
3. **Only what is needed.** 1.0 implements only options that are unambiguously needed or used by active projects (U90, Molodey) or by the template. Everything else is out, and is added when a project needs it.
4. **Rules live in types and checks, not in prose.** A rule that can be expressed as a type, a required parameter or a failing check is expressed that way. A rule that is only written down is expected to be broken (see the history audit that motivated 1.0: 59 of 101 issues were silent failures).
5. **Silence is a bug.** Every failure has a type and reaches someone: a refusal reaches the user, a failure reaches the operator, a failed migration stops the process, a failed check fails the build.
6. **One source per fact.** Derived artefacts are generated from one source, never kept in sync by a test that compares copies.
7. **Zero-major licence still applies inside the branch.** 1.0 preserves nothing from 0.x: no compatibility shims, no deprecated aliases. What projects owe is written once, as a migration guide for the move to 1.0.

### 0.2 Out of scope for 1.0 (Decided)

- Serverpod, its generator, its modules, its migrations, its test tools.
- Generic CRUD configurations (`DwCrudConfig` and relatives).
- The offline family (`dartway_offline_*`) — postponed, to be added promptly after 1.0.
- Parent–child relation update configs (`relationUpdatesConfigs`), `customUpdatesListener`.
- Cross-instance realtime fan-out and a multi-process job cluster — added when a project needs more than one server process.

---

## 1. Three kinds of DTO (Decided)

All client↔server communication is DTOs declared in the project's **shared** package. There are exactly three kinds:

| Kind | Purpose | Side effects | Retried freely | Cached / subscribed |
|---|---|---|---|---|
| `DwDataObject` | Data the server returns and publishes | — | — | is the unit of client state |
| `DwRequest<R>` | Reads data | none | yes | yes — the request is the state key |
| `DwCommand<R>` | Changes something | yes | only with its idempotency key | no |

A **server entity** (ORM row) is never a DTO and never leaves the server. The server maps entities to `DwDataObject`s explicitly.

### 1.1 Requests

A request is a DTO whose fields are its parameters; its type parameter is its result. The kind of result is expressed by the base class — one per pagination shape actually used by active projects:

```dart
class GetBooking   extends DwSingleRequest<BookingView?> { ... }  // one; nullable = may be absent
class ListRooms    extends DwListRequest<RoomView>       { ... }  // the whole list
class FeedPosts    extends DwPageRequest<PostView>       { ... }  // offset pages
class ChatMessages extends DwCursorRequest<MessageView>  { ... }  // cursor: load older
```

Used today and therefore in scope: no pagination, offset pagination (U90 feed and notifications), cursor-before-id pagination (U90 chat and comments), single-or-absent (U90, `maybeModel`), client-side ordering of live updates (U90 feed and notifications).

**A request's fields are its complete filter.** A client cannot filter by anything the request does not declare, which closes the class of #260 (a filter addressing a hidden column) by construction. One request per meaning; variations are optional fields of that request, not new request types.

### 1.2 Commands

A command is a DTO whose fields are its input; its type parameter is its result DTO. A command carries a client-generated **idempotency key**; the server stores the outcome per key and answers a repeat with the stored outcome instead of executing again (#105).

An input DTO never contains a field the server decides — owner id, timestamps, status, storage keys (#12, #60, #214, #229). The handler derives them from the context.

### 1.3 Absent versus null (Proposal)

A command that edits a nullable field must distinguish "leave unchanged" from "set to null" (#244). Proposal: such fields are declared `DwPatch<T>` (`DwPatch.keep()` / `DwPatch.set(value)` / `DwPatch.clear()`), so the distinction is a type and not a JSON convention. Commands that replace a whole value use plain fields.

### 1.4 Validation (Proposal)

A DTO may declare `validate()` returning refusals (§3). It runs on the client before sending (forms) and again on the server before the handler, automatically — the same code on both sides, no duplicated validation.

---

## 2. Protocol (Proposal)

One WebSocket per client carries everything between the app and its server: requests, commands, channel subscriptions and published updates, multiplexed by message id. Authentication happens once per connection. Plain HTTP exists only for external doors (§9).

Messages (all DTO bodies serialised by the generated codec):

| Direction | Message | Answer |
|---|---|---|
| → | `request(id, dto)` | `result(id, DwResult<R>)` |
| → | `command(id, idempotencyKey, dto)` | `result(id, DwResult<R>)` |
| → | `subscribe(channel)` / `unsubscribe(channel)` | `subscribed` / `refused(code)` |
| ← | `update(channel, [DwDataObject | DwDeleted])` | — |
| ← | `closed(channel, reason)` | — |

Client behaviour:

- Calls made before the socket is connected are queued, not failed.
- Requests are retried after reconnect; commands are re-sent with the same idempotency key.
- After a reconnect the client re-subscribes to active channels and **re-runs every active request** (Decided) — updates missed during the gap are not lost.

Server behaviour:

- Every connection has an outbound queue with a ceiling; a client that cannot keep up is disconnected with a reason rather than growing server memory (relic does not provide backpressure).

---

## 3. Results and refusals (Decided in principle; shape is a Proposal)

Every request and command answers with one sealed result, in the shared core:

```dart
sealed class DwResult<R> {}
final class DwOk<R> extends DwResult<R> { final R value; }
final class DwRefused<R> extends DwResult<R> { final DwRefusal refusal; }
final class DwNotAuthenticated<R> extends DwResult<R> {}
final class DwFailed<R> extends DwResult<R> { final String incidentId; }
```

- **A refusal is a code with parameters, never a sentence.** `DwRefusal(code, params, field?)`. `field` points a validation refusal at a form field. Permission checks, business rules and validation are all refusals — one mechanism (#132, #136, #137).
- **Codes are the project's.** The project declares its refusal codes as an enum in shared implementing `DwRefusalCode`; the framework declares its own small set (`notAuthenticated`, `forbidden`, `notFound`, `conflict`, `invalid`) and ships **no text** for them.
- **A failure never carries detail.** The client gets an incident id; the exception goes to the operator (#261 and `4c5c068`).
- Refusals do not alert. Failures alert.

---

## 4. Realtime: channels (Decided)

Updates travel only on channels a client subscribed to. Nothing is pushed that nobody asked for.

**Shared — the project declares its channel kinds:**

```dart
enum AppChannel with DwChannelKind {
  chat,         // key: chatId
  myBookings,   // key: userId
  news;         // no key
}
```

A channel instance is a kind plus an optional key: `DwChannel(AppChannel.chat, 7)`.

**Server — who may subscribe, declared once per kind.** The project writes the check with its own notions of user and role; a kind without a declaration refuses every subscription:

```dart
dw.channel(AppChannel.chat, canSubscribe: (ctx, chatId) => ctx.app.isChatMember(chatId));
```

**Server — commands publish:**

```dart
ctx.publish(DwChannel(AppChannel.chat, cmd.chatId), view);
```

**Client — a request declares the channels it lives on and how it absorbs updates:**

```dart
class ChatMessages extends DwCursorRequest<MessageView> {
  const ChatMessages(this.chatId);
  final int chatId;

  @override
  List<DwChannel> get channels => [DwChannel(AppChannel.chat, chatId)];

  @override
  DwUpdate onUpdate(DwDataObject o) => switch (o) {
    MessageView m when m.chatId == chatId => DwUpdate.upsert,
    _ => DwUpdate.ignore,
  };
}
```

Rules:

1. **Subscriptions are reference-counted** on the client: three widgets watching one chat hold one server subscription; it is released when the last one goes.
2. **Publishing happens after commit.** A rolled-back transaction publishes nothing.
3. **One command, one message per connection.** Everything a command publishes to a channel is batched.
4. **No echo to the author connection.** The author already has the command result; the user's other connections receive the update.
5. **Access is checked once, at subscription.** Therefore everything published to a channel must be readable by every subscriber of it; audiences that may see different things are different channel kinds.
6. **Revocation is explicit.** A command that removes someone's access closes the subscription: `ctx.revoke(channel, userId)`. The framework itself closes all of a user's subscriptions on sign-out and key revocation. No access re-check per publish.
7. **Deletion is an update:** `DwDeleted<T>(id)`.

`onUpdate` returns an action: `upsert`, `remove`, `refetch` (for derived data the client cannot compute), `ignore`.

**Defaults when a request does not override `onUpdate`** (Decided direction, exact table Proposal):

| Request kind | Object with an id already in state | New object | `DwDeleted` |
|---|---|---|---|
| single | replaced | ignored (absent single: taken if the request's `matches` says so, #242) | removed |
| list / page | replaced **in place, never moved** | inserted by the request's `sort` if declared, otherwise at the head | removed |
| cursor | replaced in place | inserted at the head | removed |

"Never moved" is the U90 lesson: head insertion lifted a liked post to the top of the feed.

**Parity check (Proposal).** A request's server handler (SQL) and its `onUpdate` (Dart) describe one criterion twice. The test harness ships `expectRequestParity(request, seed)`: run the handler, feed every seeded object through `onUpdate`, and require the same set. One line per request in the project's tests.

---

## 5. Internationalisation (Decided)

The framework ships no texts and no languages.

- Strings are declared in the project's **shared** package — key, default text, typed parameters — and generated into typed accessors used by server and client alike: `t.booking.seatsLeft(left: 2)`.
- The project's languages are chosen at `dartway create` through the CLI; the default is `en`.
- **Every string is editable in the admin panel from the first day.** Overrides live in the database per key and language; the client receives the catalogue with a version and caches it; the build embeds a snapshot for a first start without network.
- Server-side texts (push, e-mail, SMS) come from the same catalogue in the recipient's language.
- An edit whose placeholders do not match the declaration is refused on save.
- Refusal codes (§3) are rendered on the client through the same catalogue.

The template demonstrates all of it: declarations, the admin editor, a refusal shown in a form.

---

## 6. Migrations (Decided requirements; design is a Proposal modelled on Django and Rails)

Requirements from the owner:

- migrations are **Dart code**: schema, seeding and data migration in one place, with arbitrary logic;
- migrations **roll back**;
- the database records **the set of all applied migrations**, not a single version, so order does not matter.

### 6.1 Ledger

```sql
create table dw_migrations (
  namespace   text not null,          -- 'app', or a module: 'push', 'dw'
  id          text not null,          -- '20260913_1402_add_orders'
  checksum    text not null,          -- hash of the migration source at generation time
  batch       int  not null,          -- one migrate run = one batch
  seq         bigserial,              -- real order of application; rollback walks it backwards
  state       text not null,          -- 'applied' | 'dirty'
  applied_at  timestamptz not null default now(),
  primary key (namespace, id)
);
```

### 6.2 A migration

```dart
final class AddOrders extends DwMigration {
  @override String get id => '20260913_1402_add_orders';
  @override List<DwMigrationRef> get dependsOn => const [];   // optional, checked before applying
  @override bool get transactional => true;                    // false only for CONCURRENTLY / enum ADD VALUE

  @override
  Future<void> up(DwMigrationContext db) async { ... }         // DDL helpers, raw SQL, untyped queries

  @override
  Future<void> down(DwMigrationContext db) => irreversible();  // default; `noop()` is a separate, explicit answer
}
```

A migration never imports the current entity classes: they change, and an old migration must still run in six months. Data work uses SQL or the untyped query API.

### 6.3 Running

1. Take a session advisory lock on a dedicated connection (two instances starting at once).
2. Re-read the ledger after the lock.
3. **Refuse to start** when an applied migration is missing from code, its checksum changed, or a row is `dirty`.
4. Pending = registered − applied, ordered by `dependsOn`, then by id.
5. Each migration: `BEGIN; up(); insert ledger row; COMMIT`. A non-transactional one writes `dirty` first and flips it after.
6. **Any failure exits non-zero and the server does not start** (#109: Serverpod exited 0).

`rollback --batch` / `rollback --id X` walks `seq` backwards and refuses to roll back something another applied migration depends on.

### 6.4 Generating a draft

`dartway migration create <name>` diffs **the entities** against **the schema produced by replaying all migrations on a scratch database** (not the live database), and writes a Dart draft with `up` and a generated `down`. Renames, drops, and `NOT NULL` without a default on an existing table are **not** guessed: the draft stops with a marked decision the author must make (#140: a generated `DROP TABLE … CASCADE`). The nullable → backfill → `NOT NULL` sequence is a first-class helper.

### 6.5 Checks in CI

- fresh database → all migrations → introspected schema equals the entities;
- `up → down → up` for every reversible migration;
- "branch order": apply the base branch's set first, then the new migrations, compare again.

### 6.6 Modules

A module (push, and the framework's own tables) ships its migrations under its own namespace. Adding a module to a live database is a tested scenario, not a manual repair (#110).

---

## 7. Code generation (Proposal)

- One generator, run as `dartway generate` — a workspace dev dependency pinned by the lock file, **no global CLI and no `build_runner`** (the template dropped `build_runner` in `f29b4a7`: four-minute edit loops and phantom "undefined name" errors for agents).
- Input: annotated Dart classes resolved with `package:analyzer`. Output: serialisation codecs and a static registry for DTOs (shared), table/column/query code for entities (server), typed string accessors (shared).
- Output is formatted with the project's SDK formatter and is deterministic: regenerating an unchanged tree produces no diff. CI checks it.
- Generated code is never edited by hand, and nothing about it depends on a patch surviving (the `manualDeserialization` trap).
- Generics on the wire (`DwResult<R>`, `List<T>`, nullable `T?`) are expressed by the generator itself.

---

## 8. Testing (Decided: full-stack coverage is key; harness is a Proposal)

1. **`dartway test` stays**: a Postgres per run on a port Docker picks, removed afterwards; every suite fails loudly when it cannot reach it.
2. **The server starts inside the test process** with no globals: `final app = await DwTestServer.start(appConfig)`. Tests isolate by transaction rollback where the handler allows it, by schema otherwise.
3. **Widget tests can talk to the real server**: a Flutter test boots `dw` against an in-process server over an in-memory transport — real handlers, real SQL, real channels. The recording fake transport remains for pure UI tests.
4. **`dw` has no static state**: it can be created and disposed per test, any number of times in one process (#50, #77, #160).
5. **Parity helper** for requests (§4).
6. **Conformance suites** that the framework ships for contracts a project or module implements (the pattern from #79).
7. **Required checks from the first commit of the branch**: analyze, all suites including the database tier, generator determinism, migration checks, web compile of every client package, template built as a stranger receives it. A red check blocks the merge; review findings marked blocking block the merge.

