# The database: how do rows, queries and transactions work?

The server reads and writes PostgreSQL through `dartway_orm`, which `dartway_core_server`
re-exports. It is small on purpose: typed single-table queries, raw SQL when that is not enough,
transactions with savepoints, and locks. There are no joins and no lazy relations (D-011) — related
rows load with `findByIds`, one query per relation for a whole list, so there is no N+1 to fall
into and nothing an ORM hides behind a getter.

## Row classes

A table is declared by a row class in the server package, `lib/src/entities/`. From
`example/dartway_example_server/lib/src/entities/club.dart`:

```dart
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'club.dw.dart';

@DwSqlTable(
  'session_booking',
  indexes: [
    DwTableIndex(['sessionId', 'status']),
    DwTableIndex(['clientProfileId', 'createdAt']),
  ],
)
final class SessionBookingRow extends DwTableRow with _$SessionBookingRow {
  const SessionBookingRow({
    this.id,
    required this.sessionId,
    required this.clientProfileId,
    required this.status,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwForeignKey('club_session', onDelete: DwOnDelete.cascade)
  final int sessionId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int clientProfileId;

  final BookingStatus status;
  final DateTime createdAt;

  static const tableDef = SessionBookingTable();
}
```

The rules, each enforced by `dartway generate`:

- the class is named `<Entity>Row` and extends `DwTableRow` — a row and the data object clients see
  (`SessionBooking`) never share a name, and a row never leaves the server;
- `@override final int? id;` with `this.id` — a `bigserial` primary key, `null` before insert;
- `static const tableDef = <Entity>Table();` and `part '<file>.dw.dart';`;
- columns are the constructor's fields; nullability is the field's type.

| Annotation | Meaning |
|---|---|
| `@DwSqlTable(name, indexes: […])` | the table name; indexes name **Dart fields**, not columns |
| `DwTableIndex(fields, {unique, name})` | an index; named `<table>_<columns>_idx` (`_key` when unique) unless `name` is given |
| `@DwForeignKey(table, onDelete: …)` | a foreign key to that table's `id`; the field is `int` or `int?`. `DwOnDelete.noAction` (default), `restrict`, `cascade`, `setNull` |
| `@DwUniqueColumn()` | a single-column unique constraint |
| `@DwColumnName(name)` | the SQL column name; snake_case of the field otherwise |
| `@DwDefaultValue(sql)`, `DwDefaultValue.now()` | a database default |

A database default applies only to rows written without the column — rows that existed when the
column was added, and raw SQL inserts. A repository insert always writes every column, so the
value a new row gets in Dart comes from the constructor's default (`this.bookedCount = 0`).

### Column types

| Dart field | Column | Notes |
|---|---|---|
| `int` | `bigint` | |
| `double` | `double precision` | |
| `bool` | `boolean` | |
| `String` | `text` | |
| `DateTime` | `timestamp with time zone` | read back in UTC; connections run in UTC |
| `Duration` | `bigint` | microseconds: exact and sortable |
| `Uint8List` | `bytea` | |
| an enum | `text` | its `name` (D-008): adding a value needs no migration |
| `List<E>` | `jsonb` | `E` is `int`, `double`, `String` or `bool`, nullable or not |
| `List<E>` of an enum | `jsonb` | an array of the values' names; `E` not nullable. A name no value has any more fails the read (`DwDecodeException`) |
| `Map<String, V>` | `jsonb` | the same element types |

A data object is not a column type: a row holds ids, and the handler builds the object.

### What `dartway generate` writes

- `<file>.dw.dart`: `==`, `hashCode`, `toString`, a `copyWith` (nullable fields take a
  `DwFieldPatch` — keep, set or clear), and the table class `<Entity>Table extends DwTableDef`,
  whose getters are the typed columns (`t.status`, `t.createdAt`).
- `lib/generated/dw_schema.dart`: the project's `DwDatabaseSchema` (the migration tools and the
  server's startup check compare against it) and one getter per table on `DwDatabaseHandle`, named
  by the plural of the entity:

```dart
extension DartwayExampleDb on DwDatabaseHandle {
  DwTableRepository<SessionBookingRow, SessionBookingTable>
  get sessionBookings => repository(SessionBookingRow.tableDef);
  // one per table
}
```

So `ctx.db.sessionBookings` is a `DwTableRepository` inside a handler, `server.db.sessionBookings`
next to a running server, and `tx.sessionBookings` inside a transaction body. Changing a row class
means regenerating and writing a migration ([migrations](migrations.md)).

## `DwTableRepository`

Every method is one statement and one round trip (two inside a transaction). The statement's text depends only on the shape
of the call — which columns, which operators — never on the values, so each shape is prepared
once per connection and reused.

| Method | Returns |
|---|---|
| `find({where, orderBy, limit, offset, lock})` | the matching rows; without `orderBy` the order is whatever the database returns, so paging needs one |
| `findFirst({where, orderBy, lock})` | the first row or `null` |
| `findById(id, {lock})` | the row or `null` |
| `findByIds(ids)` | the rows with those ids, in one statement whatever their number; missing ids are absent, the order unspecified — index the result by id |
| `count({where})` | how many |
| `exists({where})` | whether any |
| `insert(row)` | the row as stored, with its id and every value read back |
| `tryInsert(row, onConflict: …)` | the stored row, or `null` when it conflicted |
| `insertAll(rows)` | the rows as stored, in order, in one statement; either every row has an id or none has |
| `update(row)` | writes every column by id; throws `DwRowNotFound` when no row has that id — an update that changed nothing is a failure, not a quiet success |
| `updateWhere({where, set})` | sets columns on every matching row; returns the count |
| `delete(id)` | `1`, or `0` when there was none |
| `deleteWhere({where})` | the count |

### Conditions and order

`where` and `orderBy` receive the table and return conditions built from its columns:

```dart
final alreadyBooked = await ctx.db.sessionBookings.exists(
  where: (t) =>
      t.sessionId.equals(session.id!) &
      t.clientProfileId.equals(me.id!) &
      t.status.equals(BookingStatus.booked),
);
```

| On a column | Conditions |
|---|---|
| any | `equals(v)` (`null` matches null cells), `notEquals(v)`, `isNull()`, `isNotNull()`, `asc()`, `desc()`, `set(v)` for `updateWhere` |
| non-null values | `inList(values)`, `notInList(values)` — one array parameter, so one prepared statement for every list length |
| comparable (`int`, `double`, `String`, `DateTime`, `Duration`) | `gt`, `gte`, `lt`, `lte`, `between(low, high)` (inclusive) |
| `String` | `like(pattern)`, `ilike(pattern)` |

Conditions combine with `&`, `|` and `.not()`. Expressions that make no sense for a type do not
compile: no `gt` on a `bool`, no `like` on a `DateTime`. Null follows Dart, not SQL's three-valued
logic: a comparison against a null cell is false, and its `not()` is true.

Values are always bound parameters; nothing passed to a condition is spliced into SQL.

### `tryInsert` and `DwOnConflict`

A unique constraint is the only race-free "insert unless it exists". `tryInsert` skips the
conflicting row and returns `null`:

```dart
final inserted = await ctx.db.sessionReviews.tryInsert(
  SessionReviewRow(
    bookingId: booking.id!,
    rating: command.rating,
    text: command.text,
    createdAt: DateTime.now(),
  ),
  onConflict: DwOnConflict.doNothing((t) => [t.bookingId]),
);
if (inserted == null) ctx.refuse(ExampleRefusal.alreadyReviewed);
```

The target columns name the unique constraint the conflict is expected on; an empty list accepts a
conflict on any of them. Checking with `exists` and then inserting does not work: two calls both see
nothing and both insert, or the second fails on the constraint.

### `updateWhere`

A conditional update is a compare-and-set in one statement. The example's read positions
(`example/dartway_example_server/lib/src/chat/chat_reads.dart`) move forward only:

```dart
await db.chatReadPositions.updateWhere(
  where: (t) =>
      t.profileId.equals(profileId) &
      t.channelId.equals(message.channelId) &
      (t.sentAt.lt(message.sentAt) |
          (t.sentAt.equals(message.sentAt) & t.messageId.lt(message.id!))),
  set: (t) => [t.messageId.set(message.id!), t.sentAt.set(message.sentAt)],
);
```

## Transactions

```dart
Future<R> transaction<R>(
  Future<R> Function(DwDatabaseHandle tx) body, {
  DwIsolationLevel? isolation,
});
```

- The body gets `tx`, a handle bound to one connection; the transaction commits when the body
  completes and rolls back when it throws.
- Inside a transaction, `transaction` opens a **savepoint**: a failure rolls back only the nested
  part. Only the outermost transaction chooses `isolation`.
- **A statement error aborts the whole Postgres transaction**, so catching it inside the body does
  not save the transaction: the body goes on, and at the end the transaction is rolled back and the
  error rethrown — Postgres would silently turn that `COMMIT` into a rollback, and a commit that did
  not happen must not look like one. To survive an expected conflict, use `tryInsert`, or run the
  risky statement in a nested `transaction` (a savepoint) and catch around that.
- A body that returns while its statements are still running is rolled back with a `StateError`:
  await them. A handle used after its transaction ended, or an outer handle used while a nested
  one is open, throws.
- `DwIsolationLevel.serializable` conflicts surface as `DwSerializationFailure`; the caller retries
  the whole transaction.

In a handler, use `ctx.transaction`: it also ties the call's publications and jobs to the commit
([handlers](handlers-and-context.md#dwcallcontext)). A transactional command already runs in one,
and the framework retries it on a serialization failure or a deadlock; a transaction opened
anywhere else is not retried for you.

## Row locks

```dart
final session = await ctx.db.clubSessions.findById(
  command.sessionId,
  lock: DwRowLock.forUpdate,
);
```

`DwRowLock.forUpdate` waits for rows another transaction holds; `DwRowLock.forUpdateSkipLocked`
returns only rows nobody holds — how concurrent workers claim distinct rows from one queue. A lock
is allowed only inside a transaction and throws `StateError` outside one, where it would end with
the statement: it would read like protection and be none. The example's `BookSession` locks the
session row, so the capacity check and the insert of every booking of that session queue behind
each other.

## Advisory locks

Some rules have no row to lock: "one code request per identifier at a time", "one import per
account". `advisoryLock` and `tryAdvisoryLock` lock a pair of 32-bit integers instead:

```dart
Future<void> advisoryLock(int namespace, int key);   // waits for the lock
Future<bool> tryAdvisoryLock(int namespace, int key); // false when it is held
```

Both are transaction-scoped — released at commit or rollback, never leaked — and throw
`StateError` outside a transaction. `namespace` keeps unrelated features apart; the framework uses
the `0x4457xxxx` range for its own locks (identifiers, idempotency keys, pending uploads), so keep
project namespaces clear of it. A string key must be hashed to a 32-bit integer by the project.

`advisoryLock` waits and holds a pooled connection while it waits; `tryAdvisoryLock` answers at
once, for work where "someone else is doing it" is itself the answer.

## Raw SQL

When a statement is not one table's — an aggregate, a `WITH`, a join the batch loaders cannot
express — write SQL:

```dart
final rows = await db.query(
  'SELECT status, count(*) AS n FROM invoice '
  'WHERE created_at > @since GROUP BY status',
  params: {'since': DateTime.utc(2026, 9, 1)},
);
final countByStatus = {
  for (final row in rows) row.get<String>('status'): row.get<int>('n'),
};
```

- `query(sql, params: {…})` returns `List<DwResultRow>`; parameters are `@name`, types inferred by
  the server — add a cast (`@id::int8`, `@ids::int8[]`) where it cannot infer one.
- `DwResultRow` is a read-only map: `row['name']`, `row.get<T>('name')` which throws
  `DwDecodeException` for a missing column or a value of another type (including `null` for a
  non-nullable `T`), and `row.decode(column)` through a table column's type.
- `execute(sql, params: {…})` returns the affected row count; without `params` the text may hold
  several statements, sent in one round trip.
- `notify(channel, payload)` sends a Postgres notification, delivered at commit inside a
  transaction.

Never interpolate values into the SQL text: every distinct text is a separate prepared statement
in the cache, and an injected value is an injection.

## Errors

Driver errors are mapped, so a caller never needs `package:postgres` to tell a constraint from a
lost connection:

| Exception | When |
|---|---|
| `DwUniqueViolation` | SQLSTATE `23505`; `constraint` names it |
| `DwForeignKeyViolation` | `23503`; `constraint` |
| `DwSerializationFailure` | `40001` |
| `DwRowNotFound` | `update` addressed an id that does not exist |
| `DwDecodeException` | a value does not fit the Dart type reading it — the schema and the row class drifted |
| `DwDatabaseException` | the base: `code` (SQLSTATE, or `null` when the server was never reached), `message`, `detail` |

An exception that escapes a handler is a failure: `500`, an incident id, an alert
([alerts](alerts.md)). A conflict the user caused is a refusal the handler decides on — prefer
`tryInsert` over catching `DwUniqueViolation`, which also aborts the transaction.

## The pool

`DwPostgresDatabase.open(config)` opens the pool and proves the database is reachable with one
real connection. `DwDatabaseConfig`:

| Field | Default | |
|---|---|---|
| `host`, `port`, `name`, `user`, `password` | port `5432` | |
| `ssl` | `true` | encrypted, certificate not verified |
| `maxConnections` | 10 | the ceiling of concurrent statements |
| `applicationName` | `dartway` | |
| `connectTimeout` | 15 s | also how long a caller waits for a free connection |
| `queryTimeout` | 5 min | |
| `statementCacheSize` | 256 | prepared statements kept per connection |

Connections are kept until they break, with their prepared statements, and the most recently used
one is handed out first so its cache stays warm. A cached statement invalidated by a schema change
is prepared again and, outside a transaction, the statement is run again once. The server builds
the pool from `DwAppServer(database:)`; a script opens its own and closes it
(`template/dartway_starter_server/bin/seed_dev.dart`).

## Related

- [Migrations](migrations.md) — how a row class change reaches the database.
- [Handlers and the call context](handlers-and-context.md) — `ctx.db` and `ctx.transaction`.
- [Jobs](jobs.md) — `SKIP LOCKED` claims and `LISTEN`/`NOTIFY` in the framework's own queue.
