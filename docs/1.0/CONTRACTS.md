# Revision 2 — the owner's review of 2026-09-14

> **As built after stage 2:** packages are `dartway_core_shared` (pure Dart), `dartway_core_server` (re-exports shared and `dartway_orm`), `dartway_core_flutter` (re-exports shared, `dartway_client`, `dartway_router`) at `0.20.0-dev.1`. `DwWindowRequest<T, S, I>` declares `positionOf(T) → DwWindowPosition<S, I>` (sort value + id) — order is defined once, on the request, and the server builds cursors from it; the client places a new window item by that position only inside the loaded range (at the head when the window shows the newest, counted as unseen otherwise). Anonymous clients do not open the live socket. A replayed command answer carries `"replayed": true` and the client re-reads its live state.
>
> **As built after the example port (D-036, D-037):** response `updates` are grouped by channel wire name, then by type (`DwUpdateTransport` of `DwChannelUpdates`), collapsed by (channel, type, id); the socket `upd` keeps naming its channel beside one channel's type groups. The client applies an object only to entries whose request declares that channel, caller channels resolved for the entry's account; a request without channels hears no updates. `DwLiveChannel.ofCaller(kind)` is resolved by the client to `kind:<accountId>`; the server's `DwChannelRule.ofCaller(kind)` allows only the caller's own key and a handler publishes with `DwLiveChannel.forAccount(kind, accountId)` (publishing an unresolved caller channel throws). `DwTableRequest` answers `matches ? upsert : remove`: an object on the page is replaced in place, an upsert of an object not on the page and every removal re-read the page (coalesced). The live socket's origin check compares full origins (scheme, host, port): the origin the upgrade was sent to (its `Host`) and `allowedOrigins`, which are full origins checked at startup.

> **As built for accounts, keys and identities (D-042 – D-050):** session keys are `app` (sign-in) or `personal` (`DwAccountService.issueKey`) with a label; `ctx.sessionKey` names the key of every authenticated context, routes authenticate by `DwRouteAuth`; one key is revoked with `revokeKey`, at once in-process. Identifiers are attached or changed by code with the built-in `DwRequestIdentifierCode` / `DwConfirmIdentifier`, mirrored by `onIdentifierChanged`, moved and removed by `DwAccountService`; `onAccountCreated` receives a `DwAccountOrigin`. §3.3 is current.

**This section supersedes everything below it where they disagree.** It records the decisions of the morning review; the build is being redone to match. Sections below remain valid where untouched.

## R2.1 Naming — no name shorter than two words

| What | Where | Rule | Example |
|---|---|---|---|
| table row class | server | `<Entity>Row extends DwRow` | `SessionBookingRow` |
| generated table | server | `<Entity>Table` | `SessionBookingTable` |
| repository getter | server | camelCase plural of the entity (without `Row`) | `db.sessionBookings` |
| data object | shared | a noun of two or more words, no suffix | `SessionBooking`, `ClubSession`, `UserProfile` |
| read | shared | `Get…` / `List…` + two or more words | `GetUserProfile`, `ListMyBookings` |
| change | shared | verb + object | `BookSession`, `CancelBooking` |
| project channels / refusals | shared | `<Project>Channel` / `<Project>Refusal` | `ExampleChannel` |

ORM renames: `DwEntity` → `DwRow` (base class of table rows); the raw SQL result row `DwRow` → `DwResultRow`. The `*View` suffix of the first build is gone.

**The rule covers the framework's own public names too** (owner, 2026-09-14); the `Dw` prefix is not a word:

| Was | Is |
|---|---|
| `DwEntity` / `DwRow` (row base) | `DwTableRow` |
| `DwRow` (raw SQL row) | `DwResultRow` |
| `DwCall` | `DwServerCall` |
| `DwRequest` | `DwDataRequest` |
| `DwSingleRequest` / `DwMaybeRequest` / `DwListRequest` / `DwPageRequest` / `DwTableRequest` / `DwWindowRequest` | unchanged (two words already) |
| `DwCommand` | `DwActionCommand` |
| `DwServer` | `DwAppServer` |
| `DwClient` | `DwAppClient` |
| `DwChannel` | `DwLiveChannel` (and `DwChannelKind` stays, `DwChannelRule` stays) |
| `DwProtocol` | `DwWireProtocol` |
| `DwTransport` | `DwUpdateTransport` |
| `DwDto` | `DwWireObject` |
| `DwPatch` (+ `DwKeep`/`DwSet`/`DwClear`) | `DwFieldPatch` (+ `DwKeepField`/`DwSetField`/`DwClearField`) |
| `DwResult` (+ `DwOk`/`DwRefused`/`DwFailed`) | `DwCallResult` (+ `DwCallOk`/`DwCallRefused`/`DwCallFailed`; `DwNotAuthenticated` stays) |
| `DwRefusal` | `DwCallRefusal` |
| `DwContext` | `DwCallContext` |
| `DwAccess` | `DwAccessRule` |
| `DwHandler` | `DwCallHandler` |
| `DwAuth` | `DwAuthConfig` |
| `DwAccounts` | `DwAccountService` |
| `DwJobs` | `DwJobQueue` |
| `DwJson` | `DwJsonCodec` |
| `DwPage` / `DwWindow` | `DwPageResult` / `DwWindowResult` |
| `DwSession` | `DwAuthSession` |
| `DwCore` (Flutter) | `DwFlutterCore` |
| `DwHttp` | `DwHttpContract` |
| `DwDeleted` | `DwDeletedObject` |

Any other one-word public name found during the renames follows the same rule (`Dw` + two or more words) and is listed in the stage's report.

## R2.2 Transport: HTTP per DTO, WebSocket only for live updates

One server process, one port.

```
POST /dw/<DtoWireName>     requests and commands (framework)
GET  /dw/live              WebSocket: authenticate, subscribe, unsubscribe; receives updates and channel closures
GET  /health               liveness + database reachability
*                          project routes (external doors); /dw/ and /health are reserved, a collision fails startup
```

### Call

- Body: the DTO's own JSON (`toJson()`), no type tag — the type is the path.
- Query: page parameters only — `offset` (page), `page`&`pageSize` (table), `anchor`/`before`/`after` (window cursors, opaque strings produced by the server).
- Headers:
  - `Authorization: Bearer <token>` (absent = anonymous);
  - `Dw-Idempotency-Key: <key>` — required for commands, forbidden for requests;
  - `Dw-Protocol: 1` — required; unsupported → 426;
  - `Dw-App-Version: <semver>+<build>` — sent by the framework client; below the project's `minAppBuild` → 426 `dw.updateRequired`;
  - `Dw-Live-Connection: <id>` — optional: the id the server gave this client's WebSocket; lets the server exclude that connection from the socket broadcast of this command's updates; the channels it subscribes to travel in the response instead. With it or without, a successful command's response carries the publications to channels the caller may read: those its named connection subscribes to, and every other one whose rule (`canSubscribe`) allows the caller when asked after commit — minus channels the command revoked for the caller, and none for an anonymous caller or one whose key the command revoked (D-053). A named connection that is unknown, closing, or of another account counts as none.
- Only POST. Body limit 1 MiB by default.

### ApiResponse (always the body)

```json
{"status":"ok","result":<encoded by the request/command class>,"updates":{"schedule":{"ClubSession":[{…}]},"bookings:7":{"SessionBooking":[{…}],"DwDeletedObject":[{"type":"SessionBooking","id":1}]}}}
{"status":"refused","refusal":{"code":"noSpotsLeft","params":{},"field":null}}
{"status":"unauthenticated"}
{"status":"failed","incidentId":"…"}
{"status":"incompatible","refusal":{"code":"dw.updateRequired"}}
```

`result` is never tagged (its type is the request's or command's); `updates` is the **transport** — objects grouped by the channel they were published to, then by wire name, the only place a type name stands next to objects. The channel travels because it is the only fact that says whose data an object is (D-036): the client applies an object only to requests that declare its channel. `updates` is omitted when empty.

### Honest HTTP statuses

| Outcome | HTTP |
|---|---|
| ok | 200 |
| refused by a rule or validation | 422 |
| `dw.forbidden` | 403 |
| `dw.notFound` | 404 |
| `dw.conflict` | 409 |
| `dw.tooManyRequests` | 429 + `Retry-After` |
| unauthenticated | 401 |
| failed | 500 |
| malformed call, unknown DTO, wrong method, missing required header | 400 (unknown DTO: 404 with `failed`) |
| protocol unsupported / update required | 426 |

Refusals never alert; 5xx alert.

### WebSocket `/dw/live`

```
← {"k":"hello","connection":"<id>"}                  on open
→ {"k":"auth","token":"…"} / {"k":"auth"}            first, and after sign-in/out
← {"k":"authed","account":7} / {"k":"authed","rejected":true}
→ {"k":"sub","ch":"bookings:7"} / {"k":"unsub","ch":"…"}
← {"k":"subok","ch":"…"} / {"k":"subno","ch":"…", …}
← {"k":"upd","ch":"schedule","updates":{"ClubSession":[{…}]}}
← {"k":"closed","ch":"…"}
```

Query `?protocol=1&app=<version>` on the upgrade (browsers cannot set headers); same 426 semantics as a close code. Pings as before. The author's own connection (named in `Dw-Live-Connection`) does not receive updates of its own command over the socket — it has them in the response.

## R2.3 Request kinds and update actions

```dart
enum DwUpdateAction { upsert, update, remove, refetch, ignore }
```

- `upsert` — replace by id; insert when absent (by `sort`, else at the head).
- `update` — replace only when present.
- `remove`, `refetch`, `ignore`.

No `auto`. Every kind's `onUpdate(Object item)` returns an explicit action; scenarios are chosen with **named super constructors**, overriding `onUpdate` stays for special cases.

| Kind | Result | Default action | Named constructors |
|---|---|---|---|
| `DwSingleRequest<T>` | `T` (absent ⇒ `dw.notFound`) | `update` | — |
| `DwMaybeRequest<T>` | `T?` | `matches ? upsert : remove` | — |
| `DwListRequest<T>` | `List<T>` | `matches ? upsert : remove` | `.updateOnly()`, `.refetchOnUpdate()` |
| `DwPageRequest<T>` (offset, accumulating feed) | `DwPage<T>` (items, hasMore) | `matches ? upsert : remove`; an insert sorting past the loaded pages is dropped while more pages exist | `.updateOnly()` |
| `DwTableRequest<T>` (numbered pages) | `DwTablePage<T>` (items, total, page, pageSize) | `matches ? upsert : remove` on a page: present → replaced in place; not on the page, or removed → `refetch` (coalesced), so the total and paging stay true (D-037) | — |
| `DwWindowRequest<T>` (anchored, both directions) | `DwWindow<T>` (items newest-first, hasOlder, hasNewer, olderCursor, newerCursor) | present → `update`; new + `matches` → insert **only when `hasNewer == false`** (otherwise the window counts it as unseen); not matches → `remove` | — |

`DwCursorRequest` is removed (a window without anchor opens at the newest).

Page sizes: `DwPageRequest` / `DwWindowRequest` take `pageSize` (and `maxPageSize`) as super-constructor arguments — constants, not serialised. `DwTableRequest` declares `page` and `pageSize` as **fields** (they are the key); the class declares `maxPageSize`; the server clamps.

Window cursors are opaque strings the server builds from the sort value and the id (`DwWindowCursor.encode(sortValue, id)` / `.decode`), so rows sharing a timestamp are neither lost nor repeated. The handler receives `DwWindowInput { direction: around|older|newer, anchor?, cursor?, fetchLimit }` and returns the rows of that direction; the framework assembles the window and the flags.

`bool acceptsItem(Object?)`, `matches`, `sort`, `channels` stay pure functions of the object and the request's fields. `DateTime.now()` inside them is a bug.

## R2.4 Access and account scoping

- `validate()` (`DwValidatable`) knows only the DTO's fields and runs on both sides; **who calls** is decided on the server only.
- Client state is always scoped by account: a sign-in as a different account never sees the previous account's entries. "My …" requests carry no account or profile id; the server uses the caller, and their channels are `DwLiveChannel.ofCaller(kind)` (D-037).
- `DwAccess.check((ctx, request) async => bool)` receives the request for rules on real parameters (staff viewing a client's bookings).

## R2.5 Versions

`Dw-Protocol` (framework envelope) and `Dw-App-Version` (the app build). The server's `DwServerSettings.minAppBuild` (int, default 0) can be changed without a release (read from settings/environment at startup; a project may also load it from the database). The Flutter layer turns `dw.updateRequired` into a full-screen "update the app" page with project-supplied text and store links.

## R2.6 External doors

`DwRoute.get/post/any(path, (DwRouteContext ctx, DwHttpRequest request) async => DwHttpResponse, {auth: DwRouteAuth.none|optional|required})` — `auth` reads `Authorization: Bearer` as a call does and fills `ctx.accountId`/`ctx.sessionKey` (D-042); framework types over the HTTP server. **No relic (D-028): the server runs directly on `dart:io` `HttpServer`** with a thin layer of its own — routing `/dw/<type>`, `/dw/live`, `/health` and project doors by map lookup, body reading with a limit, the few headers it needs, response writing, graceful stop.

## R2.7 Web and deploy (for the deploy milestone)

Three hosts, one server process: `example.com` (site: optional `app_site/` built by the project or external), `app.example.com` (Flutter web by nginx; `/dw/*` and `/health` proxied to the server — same origin, no CORS, no preflight), `api.example.com` (the server for mobile apps and webhooks). The server does not serve static files.

---

# DartWay 1.0 — package contracts

The seams between the 1.0 packages, fixed before the packages are written so they can be built in parallel. `SPEC.md` says *what* and *why*; this file says *which names and shapes*. Where an implementation finds a contract unworkable, it changes this file in the same commit and says why in `DECISIONS.md`.

Stack facts every package relies on (verified against sources, `docs/1.0/DECISIONS.md` D-004):

- **relic 2.0.0-rc.1** — WebSocket via `WebSocketUpgrade`; cross-origin upgrades refused unless configured; no ping by default; **run a single isolate** (`noOfIsolates > 1` silently duplicates in-memory state).
- **postgres 3.5.12** — SSL required unless disabled; **a pool has one connection unless `maxConnectionCount` is set**; `runTx` cannot nest (use SAVEPOINT); a parameterised `execute` is three round trips and there is no statement cache (the ORM caches prepared statements per connection); `numeric` decodes as `String`; enums in native Postgres enum types decode as raw bytes — **DartWay stores enums as `text`**; pooled connections cannot `LISTEN`.
- **analyzer** — pinned in the generator package only.

Toolchain: Flutter 3.44.0 / Dart 3.12 (`/Users/eugen/fvm/versions/3.44.0/bin`).

---

## As built (2026-09-14)

The sections below were written before the packages; these are the differences the build settled on, each justified in the package sources:

- **orm** — `tryInsert` (nullable result) instead of `insert(onConflict:)`; tables expose `columns` (the schema is derived); statements list columns explicitly, never `*` (cached plans break on `ADD COLUMN`); the ORM runs its own pool and caches prepared statements per connection (1 round trip per repeated statement instead of 3); transactions are driven with `BEGIN`/`SAVEPOINT`; `DwMigration.checksum` is written into the file (SHA of the source without whitespace) and re-sealed by `rehash`; migration files are `m<id>.dart`; decisions in a draft are a compile error (`decisionRequired(...)`); `DwMigrationCli` takes `modules` (other namespaces replayed first, e.g. `dw`).
- **server** — the app WebSocket is served through a relic hijack with `dart:io` WebSocket (needed to measure unread outbound bytes for the slow-consumer ceiling); version is the `v` query parameter (`/dw?v=1`), a mismatch closes with 4001; the server pings every 20 s; `DwServerSettings` holds limits; page handlers receive `DwPageInput`; every channel subscription requires sign-in (D-020); updates reach the author's connection too (D-018); `DwAccounts` creates or finds accounts outside the sign-in flow (seeds, admin bootstrap).
- **client** — `DwTokenStore` stores the whole `DwSession`; `watch` serves single/maybe/list requests and `watchPages` paginated ones; `DwRequestData` carries `refreshing` and `live`; calls time out after `callTimeout` counted from the call, queueing included.
- **flutter** — `DwCore extends DwFlutter` builds its own client; the toolbox's text `DwRefusal`/`DwNotAuthenticated` exceptions are gone in favour of core results.

## Packages

| Package | Kind | Depends on | Holds |
|---|---|---|---|
| `dartway_core` | pure Dart | — | DTO kinds, results, refusals, channels, wire protocol, auth DTOs. **Done.** |
| `dartway_orm` | pure Dart (server) | `dartway_core`, `postgres` | entities, typed queries, transactions, locks, schema, migrations |
| `dartway_server` | pure Dart (server) | `dartway_core`, `dartway_orm`, `relic` | the app server: WebSocket protocol, handlers, context, auth, channels, idempotency, jobs, web routes, alerts, test server |
| `dartway_client` | pure Dart | `dartway_core` | connection, calls, request state engine, channel subscriptions, session |
| `dartway_flutter` | Flutter | `dartway_client` | the existing toolbox + Riverpod bindings, session storage, refusal rendering |
| `dartway_generator` | pure Dart (dev tool) | `analyzer` | DTO codecs, entity tables, registries, schema |
| `dartway_cli` | pure Dart | — | `create`, `generate` (delegates), `test`, `migration` (delegates), `check`, `doctor`, `deploy` |

A project on 1.0:

```
app_shared/   DTOs, channel kinds, refusal codes, strings        → dartway_core
app_server/   entities, handlers, migrations, bin/server.dart     → dartway_server, dartway_orm, app_shared
app_flutter/  screens                                             → dartway_flutter, app_shared
```

There is no generated `app_client` package: the shared package is the client contract.

---

## 1. Generated code (dartway_generator)

`dartway generate` in a project runs the generator over `app_shared` and `app_server`. Output is deterministic and `dart format`ted.

### 1.1 DTOs (shared)

A file declaring DTOs has `part '<file>.dw.dart';`. For every class extending `DwDataObject`, a `DwRequest` kind or `DwCommand` (directly or through a kind), the part contains exactly the shape of `packages/dartway_core/test/fixtures/booking_view.dw.dart`:

- `mixin _$Name on <DirectSuperclass>` with `dwTypeName`, `toJson()`, `==`, `hashCode`, `toString()`; the class declares `with _$Name`.
- a top-level `Name $NameFromJson(Map<String, Object?> json)`.
- for data objects only: `extension NameCopyWith on Name { Name copyWith(...) }` — nullable fields take `DwPatch<T>` in `copyWith`.

Field rules (constructor parameters named like fields; every serialised field is a final field initialised by a named constructor parameter):

| Dart type | JSON | Notes |
|---|---|---|
| `int`, `String`, `bool` | same | |
| `double` | number | decode with `DwJson.decodeDouble` |
| `DateTime` | int, UTC micros | `DwJson.encodeDateTime` / `decodeDateTime` |
| `Duration` | int, micros | |
| `Uint8List` | base64 string | |
| enum | `name` | `DwJson.decodeEnum` |
| a DTO class | its `toJson()` (untagged) | decoded with its `$XFromJson` |
| `List<T>` / `Map<String, T>` of the above | array / object | omitted when empty **only** if the constructor default is `const []` / `const {}` |
| `T?` | omitted when `null` | |
| `DwPatch<T>` | absent / value / `null` | `DwJson.writePatch` / `readPatch`; default `const DwPatch.keep()` |

Getters, static members and fields not in the constructor are not serialised. `id` of a data object must be `int` or `String`.

### 1.2 Registry (shared)

`app_shared/lib/generated/dw_protocol.dart`:

```dart
// GENERATED BY dartway generate. DO NOT EDIT.
import 'package:dartway_core/dartway_core.dart';
import '../src/booking/booking_dtos.dart';

final DwProtocol appProtocol = DwProtocol([
  DwDtoEntry(BookingView, 'BookingView', $BookingViewFromJson),
  // … sorted by name
], include: DwProtocol.core);
```

The variable is named `<package name without _shared, camelCase>Protocol` — `dartway_example_shared` → `dartwayExampleProtocol`. Two classes with the same name fail generation.

### 1.3 Entities (server)

See §2.2 for the declaration and the generated shape (the ORM owns that shape; the generator reproduces it). Plus `app_server/lib/generated/dw_schema.dart`:

```dart
final DwSchema appSchema = DwSchema([ClubSession.table, ClubService.table, …]);
extension AppDb on DwDb {
  DwRepository<ClubSession, ClubSessionTable> get clubSessions => repository(ClubSession.table);
}
```

(`appSchema` is `<package without _server, camelCase>Schema`; the extension is `<Pascal>Db`.)

---

## 2. dartway_orm

### 2.1 Connection

```dart
final database = await DwDatabase.open(DwDatabaseConfig(
  host: 'localhost', port: 5432, name: 'app', user: 'app', password: '…',
  ssl: false, maxConnections: 10,
));
final DwDb db = database.db;          // pool-bound
await database.close();
```

`DwDatabaseConfig.fromEnvironment(Map<String, String> env, {String prefix = 'DW_DATABASE_'})` reads `HOST`, `PORT`, `NAME`, `USER`, `PASSWORD`, `SSL`, `MAX_CONNECTIONS`.

### 2.2 Entities

```dart
import 'package:dartway_orm/dartway_orm.dart';
part 'club_session.dw.dart';

@DwTable('club_session', indexes: [DwIndex(['startsAt'])])
final class ClubSession extends DwEntity with _$ClubSession {
  const ClubSession({this.id, required this.serviceId, this.coachProfileId,
                     required this.startsAt, required this.capacity});

  @override
  final int? id;                                   // bigserial primary key, null before insert

  @DwReferences('club_service', onDelete: DwOnDelete.cascade)
  final int serviceId;

  @DwReferences('user_profile', onDelete: DwOnDelete.setNull)
  final int? coachProfileId;

  final DateTime startsAt;
  final int capacity;

  static const tableDef = ClubSessionTable();      // declared by the author, typed by the generator (D-040)
}
```

Annotations: `@DwTable(name, indexes:)`, `@DwIndex(columns, unique:, name:)`, `@DwReferences(tableName, onDelete:)`, `@DwColumnName('sql_name')` (default: snake_case of the field), `@DwDefault.now()` / `@DwDefault(sqlExpression)`, `@DwUnique()` (single-column unique shortcut).

Column types: `int` → `bigint`, `double` → `double precision`, `bool` → `boolean`, `String` → `text`, `DateTime` → `timestamptz`, `Duration` → `bigint` (micros), enum → `text` (name), `Uint8List` → `bytea`, `List<…>`/`Map<String, …>` of JSON-able values → `jsonb`. Nullability from the Dart type.

Generated part:

```dart
part of 'club_session.dart';

mixin _$ClubSession on DwEntity { /* ==, hashCode, toString */ }

extension ClubSessionCopyWith on ClubSession { ClubSession copyWith({…}) }

final class ClubSessionTable extends DwTableDef<ClubSession> {
  const ClubSessionTable() : super('club_session');

  DwColumn<int> get id => const DwColumn('id', this);   // exact form is the ORM's choice
  DwColumn<int> get serviceId => …;
  DwColumn<int?> get coachProfileId => …;
  DwColumn<DateTime> get startsAt => …;
  DwColumn<int> get capacity => …;

  @override List<DwColumn<Object?>> get columns => […];      // id first; each column carries type, nullability, default, unique, references
  @override List<DwIndexSchema> get indexSchemas => […];
  @override ClubSession fromRow(DwRow row) => …;
  @override Map<String, Object?> toRow(ClubSession entity) => …;   // without id when null
}
```

### 2.3 Queries

```dart
final repo = db.clubSessions;
await repo.find(
  where: (t) => t.startsAt.gt(now) & t.serviceId.equals(3),
  orderBy: (t) => [t.startsAt.asc(), t.id.asc()],
  limit: 21, offset: 0,
  lock: DwLock.forUpdate,                          // allowed only inside a transaction
);
await repo.findById(id, {lock});                   // Entity?
await repo.findFirst(where:, orderBy:, lock:);     // Entity?
await repo.findByIds(ids);                         // List<Entity>, one query
await repo.count(where:);  await repo.exists(where:);
await repo.insert(entity);                         // returns the entity with id
await repo.insertAll(entities);
await repo.tryInsert(entity, onConflict: DwOnConflict.doNothing((t) => [t.x]));   // Entity? (null when skipped)
await repo.update(entity);                         // by id, all columns; returns entity
await repo.updateWhere(where:, set: (t) => [t.capacity.set(5)]);         // int count
await repo.delete(id);  await repo.deleteWhere(where:);                  // int count
```

Expressions on `DwColumn<T>`: `equals`, `notEquals`, `isNull`, `isNotNull`, `inList`, `notInList`, `gt`, `gte`, `lt`, `lte`, `between`; on `String` columns `like`, `ilike`; combine with `&`, `|`, and `.not()`. Values are always bound parameters. Ordering: `asc()`, `desc()`.

There are no includes/joins in 1.0 (D-011): related rows are loaded with `findByIds` — one query per relation, never per row.

Raw access: `db.query(sql, params: {…})` → `List<DwRow>`; `db.execute(sql, params:)` → affected count. `DwRow` is a `Map<String, Object?>` view with typed getters.

### 2.4 Transactions and locks

```dart
await db.transaction((tx) async { … });            // tx is a DwDb bound to one connection
```

Inside a transaction, `tx.transaction` opens a SAVEPOINT. `tx.advisoryLock(int namespace, int key)` / `tx.tryAdvisoryLock(…)` take transaction-scoped locks. A `DwDb` knows whether it is inside a transaction (`db.inTransaction`); `lock:` outside one throws `StateError`.

Errors are mapped: `DwUniqueViolation(constraint)`, `DwForeignKeyViolation(constraint)`, `DwSerializationFailure`, others as `DwDatabaseException(code, message)`.

### 2.5 Schema and migrations

`DwSchema(tables)` describes the target schema. Migrations are classes (SPEC §6):

```dart
final class M20260914Initial extends DwMigration {
  @override String get id => '20260914_000000_initial';
  @override String get checksum => '…';        // written by `create`, re-sealed by `rehash`
  @override Future<void> up(DwMigrationContext m) async { await m.createTable(…); await m.sql('…'); }
  @override Future<void> down(DwMigrationContext m) async => m.dropTable('…');
}
```

`DwMigrationContext`: `sql(String, {params})`, `query`, `createTable(DwTableSchema)`, `dropTable`, `addColumn`, `dropColumn`, `renameColumn`, `alterColumnNullability`, `createIndex`, `dropIndex`, `irreversible()`, `noop()`.

Runner: `DwMigrator(db, migrations: {'app': appMigrations, 'dw': DwServer.frameworkMigrations}).apply()` — per SPEC §6.3, ledger `dw_migrations`, advisory lock, refuse on missing/changed/dirty, non-zero exit.

Project entry point `app_server/bin/migrate.dart`:

```dart
Future<void> main(List<String> args) => DwMigrationCli(
  schema: appSchema, migrations: appMigrations, directory: 'lib/src/migrations',
).run(args);   // apply | rollback [--batch|--id] | status | create <name> | check | rehash
```

`create` replays all migrations on a scratch database, introspects, diffs against `schema`, and writes a draft migration file plus its registration in `lib/src/migrations/migrations.dart` (`final List<DwMigration> appMigrations = […]`). Renames and destructive changes stop the draft with a marked decision.

---

## 3. dartway_server

```dart
Future<void> main() async {
  final server = DwServer(
    protocol: dartwayExampleProtocol,
    schema: dartwayExampleSchema,             // optional: startup fails when a declared table or column is missing
    migrations: appMigrations,
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
    auth: exampleAuth,
    handlers: exampleHandlers,
    channels: exampleChannels,
    jobs: exampleJobs,
    routes: const [],
    port: 8080,
  );
  await server.start();          // migrate (framework + app), then serve; any failure exits non-zero
}
```

### 3.1 Handlers

```dart
final exampleHandlers = <DwHandler>[
  DwHandler.request<ListUpcomingSessions, List<SessionView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async { … },
  ),
  DwHandler.page<FeedPosts, PostView>(                // DwPageRequest and DwCursorRequest
    access: DwAccess.signedIn,
    handle: (ctx, request, page) async =>             // page.offset / page.before, page.fetchLimit
        …find(limit: page.fetchLimit, offset: page.offset),
  ),                                                  // returns List<PostView>; the framework trims and sets hasMore
  DwHandler.command<BookSession, BookingView>(
    access: DwAccess.signedIn,
    transactional: true,                              // default; false for handlers calling external services
    handle: (ctx, command) async { … },
  ),
];
```

`access` is required: `DwAccess.anonymous`, `DwAccess.signedIn`, `DwAccess.check((ctx) async => bool)` (signed in and the check passes, otherwise `dw.forbidden`). A missing handler is a **startup error**: the server refuses to start when a registered request or command type has no handler, and a handler for an unregistered type is equally an error.

Validation: before `handle`, the server runs `dto.validate()` when the DTO implements `DwValidatable` (`List<DwRefusal> validate()`); the first refusal is answered.

### 3.2 Context

```dart
abstract class DwContext {
  int? get accountId;
  int get requireAccountId;                         // DwNotAuthenticated when absent
  DwDb get db;                                       // the transaction in a transactional command
  Future<T> transaction<T>(Future<T> Function(DwDb tx) body);
  void publish(DwChannel channel, DwDto item);       // delivered after commit, batched per channel, to every subscribed connection including the author's (D-018)
  void revoke(DwChannel channel, int accountId);     // closes that account's subscriptions to the channel
  Never refuse(DwRefusalCode code, {Map<String, Object?> params, String? field});
  DwJobs get jobs;                                    // enqueue in the same transaction
  DwLogger get log;
  T memo<T>(Object key, T Function() create);        // per-call cache for project extensions
}
```

Projects add their notions by extension: `extension ExampleContext on DwContext { Future<UserProfile> get profile => memo(#profile, () => …); }`.

### 3.3 Auth

Framework tables (framework migrations, namespace `dw`): `dw_account`, `dw_identity(account_id, kind, value, verified_at, unique(kind, value))`, `dw_auth_key(account_id, token_hash unique, kind app|personal, label, created_at, last_used_at, revoked_at)`, `dw_code_ticket(…, purpose signIn|attach, account_id)`, `dw_command_outcome`, `dw_job`, `dw_recurring_job`, `dw_stored_file`. **A project never queries them**: `DwAccountService` (`ctx.accounts`, `server.accounts`, or over a bare database) is the whole surface.

```dart
final exampleAuth = DwAuthConfig(
  normalize: (kind, raw) => …,                       // required: String? (null = invalid identifier → dw.invalid)
  deliverCode: (ctx, kind, identifier, code) async { … },        // ctx.accountId: null for sign-in, the attaching account otherwise
  fixedCode: (ctx, kind, identifier, accountId) async => null,   // reviewer/test codes; asked for both purposes
  onAccountCreated: (ctx, accountId, kind, identifier, origin) async { … },   // same transaction; origin: DwSignInOrigin(registration) | DwToolOrigin()
  onIdentifierChanged: (ctx, change) async { … },    // same transaction; DwIdentifierChange(accountId, kind, cause, previous, current)
  codeLength: 6, codeLifetime: Duration(minutes: 10),
  maxAttempts: 5, maxRequestsPerWindow: 5, requestWindow: Duration(minutes: 10),
);
```

Built-in commands (`DwWireProtocol.core`):

| Command | Access | Result | Notes |
|---|---|---|---|
| `DwRequestCode(kind, identifier)` | anonymous | `DwCodeTicket` | sign-in ticket; answer does not reveal whether an account exists |
| `DwVerifyCode(ticketId, code, registration)` | anonymous | `DwAuthSession` | sign-in tickets only; creates the account when needed; the session is a new `app` key labelled `Dw-App-Version · User-Agent`; success never stored as an outcome |
| `DwSignOut()` | signed in | `void` | revokes the caller's key |
| `DwRequestIdentifierCode(kind, identifier)` | signed in | `DwCodeTicket` | attach ticket bound to the caller; limits per identifier shared with sign-in |
| `DwConfirmIdentifier(ticketId, code, replace)` | signed in | `DwIdentityInfo` | the caller's attach tickets only; `dw.identifierTaken` (field `code`) when another account owns it, told only after the right code; `replace` changes the oldest identity of the kind in place and removes the others |

Tokens are 256 random bits, stored as SHA-256, never logged; a command whose handler minted one (`issueKey`) stores no successful outcome (D-043). A sign-out and a revocation made through a server take effect at once in its process — the next call is 401 and live connections on the key lose their subscriptions with `rejected` — and in other processes within `DwServerSettings.tokenCacheTtl`.

```dart
// accounts
ctx.accounts.ensure(kind, raw) → ({int accountId, bool created})      // DwToolOrigin
ctx.accounts.find(kind, raw) → int?
// identities
ctx.accounts.listIdentities(accountId) → List<DwIdentityInfo>          // id, accountId, kind, value, createdAt, verifiedAt
ctx.accounts.listIdentitiesOf(accountIds) → Map<int, List<DwIdentityInfo>>
ctx.accounts.accountsMatching(fragment, {kinds}) → Set<int>
ctx.accounts.moveIdentities(from, to, {kinds}) → List<DwIdentityInfo>  // transactional, identifier locks, revokes nothing
ctx.accounts.removeIdentities(accountId, {kinds}) → List<DwIdentityInfo>
// session keys
ctx.accounts.issueKey(accountId, label:, kind: personal) → ({DwSessionKeyInfo key, String token})   // token shown once
ctx.accounts.listKeys(accountId) → List<DwSessionKeyInfo>              // id, accountId, kind, label, createdAt, lastUsedAt, revokedAt
ctx.accounts.revokeKey(keyId, {accountId}) → bool
ctx.accounts.revokeKeys(accountId)
// the call's key
ctx.sessionKey → DwSessionKeyInfo?                                      // calls, subscription checks, DwRoute(auth: optional|required)
```

### 3.4 Channels

```dart
final exampleChannels = <DwChannelRule>[
  DwChannelRule.keyed<int>(AppChannel.bookings, parseKey: int.parse,
      canSubscribe: (ctx, accountId) async => ctx.accountId == accountId),
  DwChannelRule.single(AppChannel.schedule, canSubscribe: (ctx) async => true),
];
```

A subscription to a kind without a rule is refused with `dw.unknownChannel`. Subscriptions live in the server process (single isolate).

### 3.5 Idempotency

Every command message carries a key. In a transactional command the outcome row (`dw_command_outcome(key, account_id, type, status, result)`) is written in the handler's transaction; a refusal is recorded after the rollback; failures are not recorded. A repeated key answers the stored outcome. Outcomes older than 7 days are removed by a framework recurring job.

### 3.6 Jobs

```dart
final exampleJobs = <DwJobDefinition>[
  DwJobDefinition('bookingReminder', handle: (ctx, payload) async { … }),           // payload: Map<String, Object?>
  DwRecurringJob('cleanupTickets', every: Duration(hours: 1), handle: (ctx) async { … }),
];
await ctx.jobs.enqueue('bookingReminder', {'bookingId': 7}, runAt: …, key: 'reminder:7');   // key dedups
```

Executor: rows in `dw_job`, claimed with `FOR UPDATE SKIP LOCKED`, woken by `LISTEN/NOTIFY` with a slow poll as fallback; retries with backoff; the failure text is stored (not a type name); a job handler's context has no connection-bound parts (`publish` still works, delivered after commit).

### 3.7 Routes, alerts, testing

- `DwRoute.get/post(path, (DwRouteContext ctx, Request request) async => Response)` for external doors; the app WebSocket is at `/dw`.
- `DwAlerts`: failures (not refusals) go to a sink; Telegram sink optional; per-signature ceiling.
- `DwTestServer.start(server)` starts on port 0 against the database in `DW_DATABASE_*`, and `testServer.connectClient()` returns a `dartway_client` `DwClient` over a real socket.

---

## 4. dartway_client

```dart
final client = DwClient(
  protocol: dartwayExampleProtocol,
  endpoint: Uri.parse('ws://localhost:8080/dw'),
  tokenStore: DwMemoryTokenStore(),                  // Flutter supplies a persistent one
);
await client.start();

final DwResult<BookingView> r = await client.command(BookSession(sessionId: 3));
final DwResult<List<SessionView>> s = await client.fetch(const ListUpcomingSessions());

final watch = client.watch(const ListUpcomingSessions());   // DwWatch<List<SessionView>>
watch.states;                                        // Stream<DwRequestState<R>>: loading / data / refused / failed / unauthenticated
watch.close();                                       // releases channel subscriptions (reference-counted)

final paged = client.watchPages(const FeedPosts());  // DwPagedWatch<PostView>: states, loadMore(), hasMore
client.session;                                      // Stream<int?> account id
await client.signIn(session);  await client.signOut();
```

Behaviour: queue calls while disconnected; reconnect with backoff; after reconnect re-authenticate, re-subscribe active channels and re-run active watches; apply `onUpdate` defaults per SPEC §4; commands carry a fresh idempotency key per call and reuse it on resend; a `DwNotAuthenticated` answer or a rejected token clears the session.

Transport seam: `DwConnector` (`Future<DwConnection> connect(Uri)`) with a `web_socket_channel` implementation; tests use an in-memory connector.

---

## 5. dartway_flutter

The existing toolbox stays (actions, notifications, errors, plugins, app runner). The data layer is new and replaces `dw.repo`:

```dart
ref.watch(dw.request(const ListUpcomingSessions()))  // AsyncValue<List<SessionView>>
ref.watch(dw.pages(const FeedPosts()))               // AsyncValue<DwPagedData<PostView>>; ref.read(dw.pages(...).notifier).loadMore()
final result = await dw.command(BookSession(sessionId: 3));   // DwResult<BookingView>
ref.watch(dw.accountId)                               // int?
```

A refusal inside `dw.action` is shown through `DwConfig.refusalText(DwRefusal) → String` (the project's catalogue). `DwNotAuthenticated` signs out. Session tokens persist through the `DwKeyValueStorePlugin` role (shared_preferences plugin).
