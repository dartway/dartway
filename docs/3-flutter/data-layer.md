# How does the app read and write data?

Through one object: `dw.repo`. There are no repositories to write, no client calls to make, no
cache to keep in sync. A DartWay app declares a model, gives it a `DwCrudConfig` on the server, and
reads it in a widget.

The split inside `dw.repo` is deliberate and worth learning first:

- **reads are Riverpod providers** — you consume them with the *native* `ref.watch` / `ref.read` /
  `ref.refresh`;
- **writes are plain methods** — `saveModel`, `deleteModel`, awaited like any `Future`.

Nothing in the API asks you for a `ref`, and no provider type name ever appears in app code: the
entire Riverpod surface an app touches is `ref.watch(dw.repo.<x>(...))`. The reads are kept in their
own methods because they are the only state-management-coupled part — they can move to a
`dartway_riverpod` package later without the imperative half following.

## Reading

Three providers, one per shape of answer:

```dart
// AsyncValue<List<T>> — reactive list
ref.watch(dw.repo.modelList<ClubService>())

// AsyncValue<T?> — reactive single model, absence is a legal answer
ref.watch(dw.repo.maybeModel<SessionReview>(filter: reviewOfBooking(id)))

// AsyncValue<T> — reactive single model that must exist
ref.watch(dw.repo.model<ClubSession>(id: sessionId))
```

`model` and `maybeModel` take **either** `id` **or** `filter` — passing neither trips an assert in
`DwSingleModelStateConfig`. An `id` is sugar: it is turned into an `equals` filter on the `id`
field.

### `model` vs `maybeModel`

They run the same fetch and receive the same live updates. The only difference is what happens when
the row is not there:

- `maybeModel` resolves to `null` — the data branch of the `AsyncValue`;
- `model` resolves to a `StateError` — the *error* branch, message
  `dw.repo.model<ClubSession>: model not found (...)`.

Pick by whether absence is a normal state of your screen. A profile screen opened by id: `model`,
because a missing profile is a bug you want reported. "Has this booking been reviewed yet?":
`maybeModel`, because `null` is the answer, not a failure.

One consequence catches people out. `model` is a **derived** provider — a throwing view over
`maybeModel`, not its own fetch. So `ref.refresh(dw.repo.model<T>(...).future)` only recomputes the
wrapper and returns the same cached value; to force a fresh fetch, refresh the provider that
actually fetches: `ref.refresh(dw.repo.maybeModel<ClubSession>(id: id).future)`.

### Which `ref` verb

`ref.watch(provider)` subscribes reactively; `ref.read(provider.future)` reads once inside a
callback or an action; `ref.refresh(provider.future)` discards and refetches. There is also
`dwGlobalRefreshStateProvider` — every read watches it, so
`ref.read(dwGlobalRefreshStateProvider.notifier).refresh()` rebuilds all of them at once. That is a
last resort, not an everyday tool.

## Rendering a list

An `AsyncValue` has three branches, and writing `when(loading:, error:, data:)` in every feature is
how a codebase ends up with twelve different spinners. `dwBuildListAsync` renders all three:

```dart
ref
    .watch(dw.repo.modelList<ChatMessage>(
      backendFilter: AppBackendFilters.channelMessages(channel.id!),
    ))
    .dwBuildListAsync(
      loadingItemsCount: 5,
      childBuilder: (messages) => ListView.builder(...),
    );
```

The loading branch is **not** a shimmer rectangle. It calls your own `childBuilder` with
`loadingItemsCount` placeholder models and wraps the result in a `Skeletonizer` — so the skeleton
has the shape of the content that is coming. `dwBuildAsync` (the single-value form) does the same
with one placeholder, and switches to `SliverSkeletonizer` when your builder returned a sliver,
because a box skeleton is an invalid child of a `CustomScrollView`.

Errors go into the framework error pipeline (`DwErrorSource.asyncBuild`) and are replaced on screen
by `errorWidget`, which defaults to `SizedBox.shrink()`. A failing list is therefore *silent on
screen and loud in your alerts* — set `errorWidget` when the user needs to see something.

### Placeholder models must be registered

The placeholder comes from a per-type registry the app fills once, at startup:

```dart
dw.repo.setupRepository(
  defaultModel: ClubSession(
    id: dw.repo.mockModelId,
    serviceId: dw.repo.mockModelId,
    startsAt: DateTime.now(),
    capacity: 10,
  ),
);
```

Skip it for a model and the failure is immediate and total, because this registration is not only
about skeletons: `setupRepository` also maps the Dart type to the class name the CRUD endpoints
speak. So:

- the **read itself** fails with `Exception: Dw Repository was not initialized for type X`, thrown
  by the provider before the request is even built;
- the **loading branch** throws `UnimplementedError: Default Objects Repository doesn't contain a
  model of type X` while building the skeleton — during `build`, so it is a red screen, not an
  error state.

`dwBuildListAsync` asserts up front that a placeholder is obtainable, but the assert only checks
that `DwConfig.defaultModelGetter` is wired at all (the app passes `dwGetDefault`), not that your
particular model is registered. A new model means a new `setupRepository` call, always.

## Narrowing the list: `backendFilter`

`backendFilter` becomes part of the query the server runs. Filters are declared once, as an enum
carrying the field name and the value type:

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();

  static DwBackendFilter clientBookings(int userProfileId) =>
      AppBackendFilters.clientProfileId.equals(userProfileId);

  static DwBackendFilter upcomingSessions() =>
      AppBackendFilters.startsAt.greaterThan(DateTime.now().dayStart);
}
```

The mixin gives `equals`, `greaterThan(OrEquals)`, `lessThan(OrEquals)`, `like`, `ilike`, each with
a `negate` flag. The comparison operators throw `UnsupportedError` at runtime for any `T` other than
`int`, `double` or `DateTime` — the type parameter on the enum value is what makes that a mistake
you make once.

The filter also applies to **live updates**: a model arriving over the socket is only inserted into
a list whose `backendFilter` accepts it. Narrowing is a property of the list, not of one fetch.

**A `backendFilter` is not security.** It is what *this screen* wants to see. What a user is
*allowed* to see is the `accessFilter` on the server's CRUD config, and it applies whether the
client narrows or not.

## Filtering locally

The framework deliberately gives you nothing for this. Filtering an already-loaded list is a
`.where` (or a collection-`if`) inside your `childBuilder`, and a wrapper around `.where` would only
be a second thing to learn. Keep the search string in an ordinary provider and read it with
`ref.watch`. The moment you find yourself hunting for "the DartWay way" here, you have found a place
where there is none, on purpose.

## Writing

```dart
await dw.repo.saveModel(booking.copyWith(status: BookingStatus.cancelled));
await dw.repo.deleteModel(post);
```

`saveModel` is **create and update in one call** — a model with no id is inserted, one with an id is
updated, and the server's `saveConfig` is the single place both are configured. It returns the
persisted model, so post-processing (computed fields, timestamps) comes back to you. `deleteModel`
returns `true` when nothing is left on the server; a model that was never persisted returns `true`
without a round trip.

Both dispatch the server's `updatedModels` into every open watcher of that type, which is why a
booking cancelled from a card updates the list behind it with no refresh code anywhere. That
reactivity covers **your own writes**. Another user's write reaching your screen is a server-side
decision — see [realtime](../2-core/realtime.md).

## Pagination

By default a list is `DwNoPagination`: one request, everything. For long lists pass a strategy
through `customConfig`:

```dart
dw.repo.modelList<ChatMessage>(
  customConfig: DwModelListStateConfig<ChatMessage>(
    backendFilter: AppBackendFilters.channelMessages(channelId),
    paginationStrategy: DwCursorPagination(limit: 30),
  ),
)
```

`DwOffsetPagination(pageSize)` walks by offset; `DwCursorPagination(limit:)` walks backwards by id,
which is what a chat wants — an offset shifts under you when rows are inserted while you scroll.
`InfiniteListView(listViewConfig: config, listTileBuilder: ...)` drives `loadNextPage` from the
scroll position and renders the same skeletons.

`DwModelListStateConfig` is also the Riverpod family key, so it defines `==`. Two watches with an
equal config share one state; a config rebuilt with a fresh closure (`customUpdatesListener`,
`updatesSortingMethod`) does not, and silently gets its own. Keep such configs out of `build`.

## Escape hatches

Reach for these only when a provider genuinely does not fit — an imperative flow that owns its own
state, or a bespoke endpoint of your own:

- `dw.repo.fetchList<T>(filter:, orderByList:, limit:, offset:)` — one-shot `List<T>`;
- `dw.repo.count<T>(filter:)` — server-side count;
- `dw.repo.processApiResponse(response)` — unwraps a `DwApiResponse` from a **custom** endpoint and
  dispatches its `updatedModels` so open watchers stay in sync;
- `dw.repo.addUpdatesListener<T>` / `removeUpdatesListener<T>` — raw live updates of a type.
