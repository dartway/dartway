# How does a screen read and change server data?

A screen names what it wants as a **request** — a DTO from the project's shared package — and
watches it. It changes something by sending a **command**. Everything between the two — caching,
sharing one fetch between widgets, applying updates, retries, the signed-in account — is the client
behind `dw`, and a screen writes none of it.

What requests and commands *are* on the wire is [requests and updates](../2-core/requests-and-updates.md)
and [commands and idempotency](../2-core/commands-and-idempotency.md). This page is the Flutter side.

| You want | You write | You get |
|---|---|---|
| one object, an optional one, a list | `ref.watch(dw.request(request))` | `AsyncValue<T>`, `AsyncValue<T?>`, `AsyncValue<List<T>>` |
| a feed that grows as it scrolls | `ref.watch(dw.pages(request))` | `AsyncValue<DwPagedData<T>>` |
| numbered pages with a total | `ref.watch(dw.table(request))` | `AsyncValue<DwTablePage<T>>` |
| a chat-like window around a point | `ref.watch(dw.window(request, anchor: ...))` | `AsyncValue<DwWindowData<T>>` |
| to change something | `await dw.command(command)` | `DwCallResult<R>` |
| a value once, outside any widget | `await dw.client.fetch(request)` | `DwCallResult<R>` |

## Reading: `dw.request`

```dart
final bookings = ref.watch(dw.request(const ListMyBookings()));
```

The request kind decides the value: a `DwSingleRequest<T>` gives `T` (an absent object is a
`dw.notFound` refusal), a `DwMaybeRequest<T>` gives `T?`, a `DwListRequest<T>` gives `List<T>`.
`dw.request` does not take a paginated request — those have their own bindings below.

**A request is its own cache key.** Widgets watching equal requests share one provider, one fetch and
one set of channel subscriptions; `dw.request(...)` returns the same provider for an equal request, so
calling it inside `build` is the intended use. The flip side: a field that changes on every build —
`DateTime.now()` in a request — is a new request every frame. The example's schedule reads "from the
start of today" out of a provider that changes once a day for exactly that reason
(`example/dartway_example_flutter/lib/app/schedule/logic/today_provider.dart`).

**The value stays live on its own.** When a command's answer or another user's change carries an
object the request is interested in, it is applied to what is on screen — inserted, replaced, removed
or re-fetched, as the request declares. How a request declares it is
[requests and updates](../2-core/requests-and-updates.md) and
[channels and realtime](../2-core/channels-and-realtime.md). The screen contains no refresh code:

```dart
// example/dartway_example_flutter/lib/app/schedule/widgets/session_card.dart
AppButton.primary(
  l10n.book,
  onTap: dw.action(
    (_) => dw.command(BookSession(sessionId: session.id)),
    onSuccessNotification: l10n.youAreBooked,
  ),
)
```

The answer carries the booking and the session; both lists on screen take them before the command
completes, and other devices get them on their channels.

A watched request is released `DwClientOptions.releaseDelay` (one second by default) after its last
watcher leaves, keeping its subscriptions meanwhile — so a rebuilt screen, or one left and re-entered
quickly, finds current data instead of refetching.

### Errors are typed

Every way a read ends short of data is an `AsyncError` whose error is one of four types:

| Error | Means |
|---|---|
| `DwRefusalException` | The server refused; `.refusal` is the `DwCallRefusal` to render. Also a request whose `validate()` failed (nothing was sent), and every request once the build is incompatible. |
| `DwFailedException` | The server failed. `.incidentId` is what the operator finds it by; `.call` names the request. |
| `DwNotAuthenticatedException` | The request needs a signed-in user, and there is none. |
| `DwTimeoutException` | No answer for `callTimeout` and no data to show. **The client keeps retrying**; the value becomes data when the server answers. |

An error branch sorts by type, never by message.

### Refreshing stays data

A request that is running again — a pull to refresh, an update that asked for a refetch, a
reconnected socket — **keeps its last value as `AsyncData`**. The screen does not flash back to a
skeleton, and a list does not lose its scroll position because the socket blinked.

Pull to refresh is the notifier's `refetch()`, which completes when answered:

```dart
onRetry: () => ref.read(dw.request(const ListNews()).notifier).refetch(),
```

Use `refetch()`, not `ref.invalidate`: the client keeps a request alive for the release delay after
its provider is thrown away, so a rebuilt provider reattaches to the same failed state instead of
asking again.

## Feeds: `dw.pages`

A `DwPageRequest<T>` is an offset feed. `dw.pages` accumulates its pages into one list. From
`packages/dartway_core_flutter/test/dw_flutter_core_test.dart`:

```dart
final pages = ref.watch(dw.pages(const FeedRooms()));
return Column(
  children: [
    if (pages case AsyncData(:final value)) ...[
      for (final room in value.items) Text(room.name),
      if (value.hasMore)
        TextButton(
          onPressed: () =>
              ref.read(dw.pages(const FeedRooms()).notifier).loadMore(),
          child: const Text('more'),
        ),
    ],
  ],
);
```

`DwPagedData<T>` carries `items` (every loaded object, updates applied), `hasMore`, `loadingMore` and
`loadMoreError` — why the last `loadMore` did not load. A failed next page is **not** an error of the
`AsyncValue`: the loaded items stay, and the error sits beside them for the footer to show.

`loadMore()` is safe to call from every scroll event: one request while one is in flight, none when
there is no more. `refetch()` reloads from the top, as many rows as are loaded.

## Tables: `dw.table`

A `DwTableRequest<T>` has `page` and `pageSize` fields. **Each page is its own request**, so paging is
watching another request, and the previous page is released like any other. From
`example/dartway_example_flutter/lib/admin/users/widgets/admin_users_table.dart`:

```dart
final table = dw.table(request);

return ref
    .watch(table)
    .section(
      loadingValue: DwTablePage(
        PlaceholderObjects.listOf(PlaceholderObjects.profile, 4),
        total: 4,
        page: 1,
        pageSize: request.pageSize,
      ),
      onRetry: () => ref.read(table.notifier).refetch(),
      builder: (page) => UsersPage(page), // rows, and a pager over page.page / page.pageCount
    );
```

`DwTablePage<T>` carries `items`, `total`, `page`, `pageSize` and `pageCount`. A row on the page is
updated in place when it changes. Nothing is inserted into a table page: an object that is not on it,
or a deletion, reads the page again, because its rows and its total may have moved. A page below 1 is
refused locally, without a round trip.

## Windows: `dw.window`

A `DwWindowRequest<T, S, I>` is a newest-first sequence read around a point — a chat, an activity
log. `dw.window(request, anchor: cursor)` opens it around the row of `cursor` (a string from
`request.cursorOf(item)` or `DwWindowCursor.encode(sortValue, id)`), or at the newest rows when
`anchor` is `null`. Windows of one request opened at different anchors are different entries.

```dart
final provider = dw.window(request, anchor: request.cursorOf(lastRead));
ref.watch(provider);                     // AsyncValue<DwWindowData<T>>
ref.read(provider.notifier).loadOlder();
ref.read(provider.notifier).loadNewer();
```

`DwWindowData<T>` carries `items` (newest first), `hasOlder`, `hasNewer`, `loadingOlder`,
`loadingNewer`, `loadError`, and two counters a list needs:

- `unseenNewerCount` — rows that arrived live past the newest loaded one while the window does not
  reach the newest rows; zero once it does;
- `prependedCount` — how many rows the last change put before the previous first row.

A screen rarely reads these by hand: [`DwWindowListView`](window-list-view.md) is the list built on
them.

## Changing: `dw.command`

```dart
final result = await dw.command(BookSession(sessionId: session.id));
```

The answer is a `DwCallResult<R>`, sealed:

| Result | Means |
|---|---|
| `DwCallOk(:value)` | Done. Its updates are already applied to every watched request. |
| `DwCallRefused(:refusal)` | The server said no — an answer for the user. |
| `DwNotAuthenticated()` | It needs a signed-in user; the session is already dropped. |
| `DwCallFailed(:incidentId)` | The server failed. |

**Inside `dw.action` there is nothing to unwrap:** a result that is not `DwCallOk` is handled — a
refusal shown through `DwFlutterConfig.refusalText`, a not-authenticated answer signing out, a failure
reported. That is the usual way to send a command; see
[actions and refusal texts](actions-and-refusal-texts.md). Outside an action, switch over the result,
or read `result.valueOrThrow` to meet it as the typed exceptions above.

Three things happen without code:

- **validation first.** A command that is `DwSelfValidating` and does not validate answers its first
  refusal at once, and nothing is sent;
- **retries are safe.** A command carries an idempotency key kept across its retries, so a retry
  after a lost answer is answered with the stored outcome instead of running twice. Network failures
  are retried until `callTimeout` (30 seconds by default); any answer is final;
- **a timeout is an unknown outcome.** When no answer came in time, the future completes with a
  `DwTimeoutException` — the command may have run. Repeating the intent is a new command, which is
  why the timeout is generous.

## The signed-in account

```dart
ref.watch(dw.accountId); // int?, null when signed out
```

`dw.accountId` is known from the stored session right after start, before the server has answered —
the example's router and profile gate decide by it
(`example/dartway_example_flutter/lib/core/router/app_router_state.dart`). The server corrects it: a
rejected token makes it `null`.

**Every watched request belongs to an account.** State is kept per signed-in account, and a request
that follows "my" channel (`DwLiveChannel.ofCaller`) resolves it for the account signed in. So:

- `dw.signIn(session)` adopts a session — the answer of `DwVerifyCode` — and stores it. When the
  account changes, every watched request is released and asked again for the new account; the value
  goes through loading and **never shows the previous account's data**;
- `dw.signOut()` ends the local session at once — every watched request is asked again anonymously —
  and asks the server to revoke the key. A revocation that did not happen is reported to the error
  pipeline as `DwSignOutException`; the session on the device is over either way.

```dart
// example/dartway_example_flutter/lib/auth/logic/auth_state.dart
if (result case DwCallOk(value: final session)) {
  await dw.signIn(session);
}
```

A screen resets nothing on sign-in or sign-out. The requests it watches follow the account.

## Hearing without reading: `dw.listen`

Some screens need what is published, not what is stored: a badge "3 new posts" has its starting
count from a request and only has to hear the posts that follow. Reading a page to subscribe would
send rows nobody shows.

```dart
// The starting number is a request; the badge watches it as usual.
final state = ref.watch(dw.request(const GetMyFeedReaderState()));

// The posts that follow are only heard.
final subscription = dw.listen(const [DwLiveChannel(AppChannel.feed)]).listen((
  object,
) {
  if (object is FeedPost) newPosts.value++;
});
// …subscription.cancel() when the badge goes away
```

The channels are subscribed while the stream is listened to and released when it is cancelled,
shared with any watched request on the same channel; a caller channel follows a switch of account.
Objects arrive as published — data objects and `DwDeletedObject`s. What is published while the socket
is down is not replayed: the exact number belongs to the request, which is read again after every
reconnect.

## Live status and reconnects

```dart
final status = ref.watch(dw.liveStatus); // DwConnectionStatus
```

Calls are HTTP and work whatever this says. The status tells whether **the data on screen follows the
server**:

| `DwConnectionStatus` | Means |
|---|---|
| `idle` | No socket: nothing watched is live, nobody is signed in (every subscription requires an account), or the client is not started. Nothing is being missed. |
| `connecting` | Opening or authenticating the socket. |
| `connected` | Subscriptions are made as they are needed. |
| `disconnected` | The socket is down and the client waits before the next attempt. Data on screen is not live. |
| `incompatible` | This build cannot talk to this server. Terminal — see [update required](update-required.md). |

`example/dartway_example_flutter/lib/ui_kit/3_special/common/connection_status_indicator.dart`
renders it as a coloured dot, treating `idle` and `connected` alike.

When the socket comes back:

- calls waiting out a retry backoff go at once;
- subscriptions are made again for every watched request;
- a request whose data was fetched before its subscription became active — and may have missed an
  update meanwhile — is read again, with the old value still on screen as data.

A subscription the server refused is tried again after a reconnect; one the server **closed** (access
revoked) stays closed for that account.

## Rendering an `AsyncValue`

`dwBuildAsync` (on `AsyncValue<T>`) and `dwBuildListAsync` (on `AsyncValue<List<T>>`) render the
three branches uniformly:

```dart
ref.watch(dw.request(const ListNews())).dwBuildListAsync(
  loadingItem: placeholderPost,
  loadingItemsCount: 5,
  childBuilder: (posts) => NewsList(posts),
  errorBuilder: (_, _) => AppText.body(context.l10n.loadFailed),
);
```

- **loading** is a skeleton of your real widget, built over placeholder data — `loadingValue` /
  `loadingItem`, or `DwFlutterConfig.defaultModelGetter` when neither is passed — and wrapped in
  `Skeletonizer` (`SliverSkeletonizer` when the builder returned a sliver). `loadingWidget` replaces
  the skeleton where a skeleton over stand-in data would itself mislead;
- **error** goes to the error pipeline with `DwErrorSource.asyncBuild`, and is replaced by
  `errorBuilder`'s widget, or by `errorWidget` (default `SizedBox.shrink()`);
- **data** is `childBuilder`. `skipLoadingOnRefresh` is on by default.

**The error default is blank, and the caller decides.** A decoration may fail silently; the section a
screen exists for may not — an empty page reads as "nothing here yet", not "the read failed". The
example and the skeleton wrap this in one app extension, `section(...)`, which always renders a
message with a retry and skips the not-authenticated case, where the sign-in screen is already the
message (`lib/shared/widgets/load_failed_message.dart` in both).

A refusal or a not-authenticated answer rendered this way still reaches `DwFlutterConfig.onErrorReport`; the
app's policy is what keeps it out of the incident log — see [error reporting](error-reporting.md).

## One-off reads: `dw.client`

For a value needed once, outside any widget, the client itself is `dw.client`:

```dart
final result = await dw.client.fetch(const GetInvoice(invoiceId: 7)); // DwCallResult<Invoice>
```

A `fetch` is not watched: no state is kept and no update reaches the value. It validates first,
retries and times out like a command. `dw.files.getLink(fileId)` is a fetch of this kind — see
[uploads on the client](uploads-client.md).

## Related

- [Flutter core](flutter-core.md) — building `dw`.
- [Window list view](window-list-view.md) — the list over `dw.window`.
- [Actions and refusal texts](actions-and-refusal-texts.md) — sending commands from a tap.
- The `dartway-data-layer` skill — what to do, step by step, inside a project.
