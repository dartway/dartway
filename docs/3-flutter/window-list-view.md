# How do I show a chat-like list that grows both ways?

A chat opens where the person stopped reading, loads older messages as they scroll up and newer ones
as they scroll down, keeps new messages coming into view while they sit at the bottom — and moves
nothing while they are reading history. Built on a plain `ListView`, each of those is a fight with
scroll offsets, and the usual shortcut, `reverse: true`, breaks as soon as the list must open in the
middle.

`DwWindowListView` is that list, over [`dw.window`](data-layer.md#windows-dwwindow). It ships no
design: every row is yours.

## The shape

```dart
// example/dartway_example_flutter/lib/app/chat/widgets/chat_channel_view.dart
DwWindowListView<ChatMessage>(
  key: const ValueKey('chat-message-list'),
  request: session.request,           // ListChatMessages, a DwWindowRequest
  controller: session.list,           // DwWindowListController<ChatMessage>
  initialAnchor: session.openAnchor,  // the read position, or null for the newest
  anchorAlignment: 0.3,
  padding: EdgeInsets.fromLTRB(10, hasPinned ? ChatPinnedBar.height + 8 : 8, 10, 12),
  onVisibleItemsChanged: tracker.seen,
  emptyBuilder: (context) => Center(child: AppText.body(l10n.sayHiToTeam)),
  itemBuilder: (context, row) => ChatMessageRow(row: row, session: session),
)
```

It reads `dw.window(request, anchor: ...)` itself — the provider is shared with any other widget
watching the same window.

## Newest at the bottom, and not reversed

The list is a `CustomScrollView` centred on a split between two slivers: the items up to the anchor
grow upward from the split, the items after it grow downward. Loading older items adds to the top of
the upper sliver; loading newer ones adds to the bottom of the lower one. **Neither moves what is on
screen** — no offset is corrected after the fact, because there is nothing to correct. The viewport's
zero is its bottom edge, so a keyboard opening keeps the newest messages where the eye is.

Why not `reverse: true`: a reversed list has one fixed end. Opening at "the first unread message,
a third down the screen" with history above and unread messages below is exactly what it cannot do
without jumping once the data arrives.

## Opening

- `initialAnchor: null` opens at the newest items, at the end.
- `initialAnchor: cursor` opens around that item — a string from `request.cursorOf(item)`, or one
  the server stored, like the example's `lastReadCursor` — with the item's bottom at
  `anchorAlignment` of the height. When too few items follow the anchor to fill the rest of the
  screen, the list stands at its end: it never leaves blank space under the newest item.

`initialAnchor` is read once. A later value is not followed — the person has scrolled since; give the
list another key to open it elsewhere.

## Growing

Older and newer items load when fewer than `loadTriggerExtent` (1.5) heights of the list remain beyond
the loaded ones. The slot past an end that has more is `edgeBuilder(context, edge, error, retry)` —
`edge` is a `DwWindowListEdge` (`older` or `newer`); by default 48 pixels holding a small progress
indicator, or a retry button after a failed load. **Keep its height constant**: it stands between the
rows on screen and the rows a load brings.

Before the first answer `loadingBuilder` is shown, when the first answer is not data `errorBuilder`
(with a `retry`), and while the window has no items `emptyBuilder` — replaced by the list, at its
newest end, when an item arrives live.

## New items arriving live

- **At the newest item** (within `newestTolerance`, 24 pixels): the list stays there, and new items
  come into view at the bottom.
- **Anywhere else:** nothing moves. `controller.newerCount` counts what arrived below.

## `DwWindowListItem`: a row with its neighbours

`itemBuilder` receives a `DwWindowListItem<T>`, not a bare item: `item`, the loaded `older` neighbour
(shown above) and `newer` neighbour (shown below), and `isHighlighted`. A date separator above the
first message of a day, or grouping one author's messages into a run, depends on the neighbours:

```dart
// example/dartway_example_flutter/lib/app/chat/widgets/chat_message_row.dart
final startsDay = older == null || !message.sentAt.isSameLocalDay(older.sentAt);
final last = newer == null || !newer.continues(message);
```

`older` is `null` for the oldest loaded item, whether or not older ones exist on the server.

## `DwWindowListController`: what the screen around the list needs

The screen owns the controller — created once, disposed with the screen — and reads it for what floats
over the list:

| Member | For |
|---|---|
| `isAtNewest` | whether the newest items are loaded and the end is on screen — the "↓" button shows while it is `false` |
| `newerCount` | items newer than any shown: loaded ones below the screen plus the window's unseen ones past its loaded end — the counter on "↓" |
| `topVisibleItem`, `bottomVisibleItem` | a floating date |
| `isScrolling` | fading that date out when the list stops |
| `jumpToNewest()` | "↓": scrolls when the newest item is near, places the list at its end when far, reopens the window at the newest items when they are not loaded |
| `scrollToCursor(cursor)`, `scrollToItem(item)` | a pinned message, a search result, a reply's quote |

The first five are `ValueListenable`s, so a small widget rebuilds on them without rebuilding the list.
From the example's "↓" button:

```dart
final atNewest = useValueListenable(session.list.isAtNewest);
final below = useValueListenable(session.list.newerCount);
// ...
ChatJumpButton(
  visible: !atNewest,
  count: below > unread ? below : unread,
  tooltip: context.l10n.chatJumpToNewest,
  onTap: () => unawaited(session.list.jumpToNewest()),
);
```

`scrollToCursor` animates to a near item, places a loaded far one at once, and **reopens the window
around an item that is not loaded** — a pinned message three hundred messages back costs one request,
not three hundred rows. The item is highlighted (`DwWindowListItem.isHighlighted`) for
`highlightDuration`. It completes with whether the item is in the list: `false` for one that no longer
exists, which the example turns into a "message is gone" notice.

## Knowing what was seen

`onVisibleItemsChanged(visible)` reports the items on screen, newest first, `visibleItemsDebounce`
(300 ms) after the list stops changing, and once more when it goes. An item under the list's `padding`
— where a pinned bar or a composer covers it — is not visible. Read tracking is built on this: the
example's `ChatReadTracker` marks read only forward, at most once per 1.2 seconds, with a `MarkChatRead`
command (`example/dartway_example_flutter/lib/app/chat/logic/chat_session.dart`).

## Proven by

- `packages/dartway_core_flutter/test/dw_window_list_view_test.dart` — opens at the newest line without
  reversing; older lines loaded above keep the first visible line within a pixel; scrolled up, new lines
  move nothing and are counted; opening at an anchor; scrolling to an unloaded line reopens the window.
- `example/dartway_example_flutter/test/app/chat_test.dart` — the chat opens under the unread divider and
  marks read what comes on screen, a new message scrolled up is counted on the arrow, the pinned bar and
  a search reach a message far back in the history.

## Related

- [The data layer](data-layer.md#windows-dwwindow) — `dw.window` and `DwWindowData`.
- [Requests and updates](../2-core/requests-and-updates.md) — `DwWindowRequest` and `positionOf`.
