# How does a read stay current?

A read is a request: a DTO whose fields are its complete filter and whose kind says the shape of its
result. The app watches it; the client asks the server once, keeps the answer as the request's
state, and applies objects published on the request's channels until nobody watches it any more.
Equal requests (equality is generated from the fields) share one state and one call.

A request has no side effects. The client may retry it, cache it and read it again whenever it
likes; a handler that publishes from a request throws `StateError`. Changes are commands
([commands-and-idempotency.md](commands-and-idempotency.md)).

## The kinds

| Kind | Result | Server handler | Default update |
|---|---|---|---|
| `DwSingleRequest<T>` | `T` — absent answers `dw.notFound` | `DwCallHandler.single` | `update` |
| `DwMaybeRequest<T>` | `T?` | `DwCallHandler.maybe` | `matches ? upsert : remove` |
| `DwListRequest<T>` | `List<T>`, the whole list | `DwCallHandler.list` | `matches ? upsert : remove` |
| `DwPageRequest<T>` | `DwPageResult<T>`: items, `hasMore` | `DwCallHandler.page` | `matches ? upsert : remove` |
| `DwTableRequest<T>` | `DwTablePage<T>`: items, `total`, `page`, `pageSize` | `DwCallHandler.table` | `matches ? upsert : remove`, applied to a page (below) |
| `DwWindowRequest<T, S, I>` | `DwWindowResult<T>`: items newest first, `olderCursor`, `newerCursor` | `DwCallHandler.window` | `matches ? upsert : remove`, inside the loaded range (below) |

A deletion (`DwDeletedObject`) removes, except where the kind reads again: `.refetchOnUpdate()` and a
table page refetch.

- **Single or maybe.** A single request asks for an object that must exist — the handler returns
  `null` and the framework refuses `dw.notFound`, so no handler forgets to. A maybe request treats
  absence as an answer, and its `matches` is **required**: no default can say which object on the
  channel is "the one" — "every object" would fill the state with the first stranger, "none" would
  empty it on every update of the held one.
- **List** — the whole list, when it is small enough to read at once.
- **Page** — an accumulating feed read by offset: "load more" appends.
- **Table** — numbered pages with a total, for an admin table.
- **Window** — a long newest-first sequence read both ways from an anchor: a chat, a log. The
  Flutter side is [../3-flutter/window-list-view.md](../3-flutter/window-list-view.md).

The scenario of a list or a page is chosen by its **named super constructor**, so the class stays
`const` and says what it does in its declaration:

| Constructor | An object on the channel | A deletion |
|---|---|---|
| `DwListRequest()` / `DwPageRequest(pageSize: …)` | `matches ? upsert : remove` | remove |
| `DwListRequest.updateOnly()` / `DwPageRequest.updateOnly(pageSize: …)` | update — membership is the server's decision | remove |
| `DwListRequest.refetchOnUpdate()` | refetch — a derived list the client cannot compute | refetch |

For anything else override `onUpdate(Object item)` and return a `DwUpdateAction`, keeping it a pure
function of the object and the fields.

## `matches`, `sort`, `positionOf` and `channels` are pure

The client calls them on objects arriving at any moment and relies on an equal request answering
equally. They depend on the object and the request's fields only; `DateTime.now()` inside one is a
bug — the time belongs in a field (`example/dartway_example_shared/lib/src/schedule.dart`):

```dart
final class ListUpcomingSessions extends DwListRequest<ClubSession>
    with _$ListUpcomingSessions {
  const ListUpcomingSessions({required this.from});

  final DateTime from;

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.schedule),
  ];

  @override
  bool matches(ClubSession item) => !item.startsAt.isBefore(from);

  @override
  int Function(ClubSession a, ClubSession b) get sort =>
      (a, b) => a.startsAt.compareTo(b.startsAt);
}
```

`matches` should be the server's filter written for one object. A table whose `matches` is looser
than its handler keeps a row on the page that has left the filter.

## How an update reaches a request

1. A command publishes an object to a channel ([channels-and-realtime.md](channels-and-realtime.md)).
   It reaches the client in that command's response, or over the live socket.
2. **Only requests that declare that channel hear it.** A request without `channels` hears nothing,
   including the responses of its own app's commands — which is right for a snapshot such as a
   search (`ListChatMessagesMatching` in `example/dartway_example_shared/lib/src/chat.dart`).
3. Only objects of the request's item type are offered (`acceptsItem`), and only deletions of that
   type (`acceptsDeletion`).
4. `onUpdate` answers a `DwUpdateAction`, and the client applies it:

| Action | What the client does |
|---|---|
| `upsert` | Replace the object with the same id **where it stands — never moved**, so a liked post does not jump to the top of a feed. Absent: insert by `sort`, at the head without one |
| `update` | Replace the object with the same id where it stands; never insert |
| `remove` | Remove the object with that id |
| `refetch` | Read the request again |
| `ignore` | Nothing |

Each kind bounds that further:

- **Single** — a removal of the held object reads again, and the screen shows what the server now
  answers (`dw.notFound`): a single state cannot be empty.
- **Maybe** — an upsert fills an empty state or replaces the held object; a removal empties it.
- **Page** — while more pages exist, an insert that sorts past the loaded rows is dropped: it
  arrives on scroll, and inserting it at the end would shift the offset of the next page.
- **Table** — a numbered page never grows by an update. An object on the page is replaced in place;
  an object not on the page and every removal read the page again, because a new row moves every
  later row and changes the total — and the client cannot tell a new row from one on another page.
  Rereads triggered together are coalesced into one call.
- **Window** — a new object is inserted where `positionOf` puts it, only inside the range loaded.
  Newer than the newest row while newer rows exist (`hasNewer`), it is counted as unseen
  (`DwWindowData.unseenNewerCount`); older than the oldest while older rows exist, it is left for
  loading older rows to bring.

A load in flight does not lose updates. Objects that arrive while a call is on its way are applied
to what is shown and applied again to the answer, because the server may have read before the
update was committed; every action is idempotent, so applying one twice changes nothing.

## Page sizes

`DwPageRequest` and `DwWindowRequest` take `pageSize` and an optional `maxPageSize` as super-constructor
arguments — constants of the class, never serialised, so a client cannot ask the server for everything
(`example/dartway_example_shared/lib/src/chat.dart`):

```dart
const ListChatMessages({required this.channelId})
  : super(pageSize: 40, maxPageSize: 160);
```

A call may send a `pageSize` query parameter; the server serves at most `maxPageSize` (the class's
`pageSize` when none is set). The client uses it to reload the rows it already shows in one call. A
`pageSize` below 1 is a malformed call (400).

A `DwTableRequest` is different: `page` and `pageSize` are **fields**, because page 2 and page 3 are
different states, and only `maxPageSize` is a super argument
(`example/dartway_example_shared/lib/src/admin.dart`):

```dart
const ListUserProfiles({
  this.page = 1,
  this.pageSize = 10,
  this.search = '',
  this.role,
}) : super(maxPageSize: 100);
```

The server serves `servedPageSize` — `pageSize` clamped to `maxPageSize` — and answers the size it
served in `DwTablePage.pageSize`. A page or page size below 1 is refused `dw.invalid` on both sides
(`checkPage`), because no clamping turns it into the page the caller meant.

Handlers read one row past the page — `DwPageInput.fetchLimit`, `DwTableInput.fetchLimit` — so the
framework learns whether more rows exist without counting. Returning more rows than `fetchLimit`
fails the call. A table handler also supplies `count`, asked only when the rows cannot tell the total
(a full page, or an empty page past the first). An offset feed needs a total order (`createdAt, id`),
or its pages skip and repeat rows; the client drops a row that arrives twice.

## Window cursors

`positionOf` is the one definition of a window's order: the sort value `S` (`int`, `String` or
`DateTime`) and the id `I` (`int` or `String`) of a row.

```dart
@override
DwWindowPosition<DateTime, int> positionOf(ChatMessage item) =>
    (sortValue: item.sentAt, id: item.id);
```

The server builds cursors from it (`DwWindowCursor`), and the client orders live inserts by it. The
pair is the position: rows sharing a timestamp are ordered by id, so reading "before (t, 7)" neither
skips the other rows at `t` nor repeats row 7. On the wire a cursor is an opaque base64url string; a
cursor that does not decode to this request's `S` and `I` is a malformed call.

A window result has a cursor at an end exactly when rows exist past it: `hasOlder` and `hasNewer` are
the cursors' presence, so the flag and the way to load cannot disagree. A call reads the newest rows,
the rows around an anchor, rows older than `olderCursor` or rows newer than `newerCursor`
(`DwWindowQuery`). The handler reads one direction at a time (`DwWindowInput`) and the framework
composes the window: see [../4-server/handlers-and-context.md](../4-server/handlers-and-context.md).
