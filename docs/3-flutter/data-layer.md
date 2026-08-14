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

### The signed-in profile is not one of these reads

The current user is a special source, not a row you fetch by id. It arrives with the session and is
kept up to date by it, so it has its own pair of providers on `dw` — never
`dw.repo.model<UserProfile>(...)`:

```dart
// UserProfile? — signed out is a legal answer: splash, router guards, the auth zone
ref.watch(dw.userProfileProvider)

// UserProfile — non-nullable, for anything drawn under DwUserAsyncScope
ref.watch(dw.requireUserProfileProvider)
ref.watch(dw.requireUserProfileProvider.select((p) => p.firstName))
```

The split is the same one as `maybeModel` vs `model`, for the same reason: `require` throws a
`StateError` when nobody is signed in, because on an authenticated screen that is a wiring mistake
and not a state to render.

Both are typed by the profile model you gave `DwCore<Client, UserProfile>`, so your own model comes
out of them without a provider of your own. `dartway create` still scaffolds
`lib/core/user_profile_provider.dart` on top — `ref.watchUserProfile` / `ref.readUserProfile`, two
getters over `requireUserProfileProvider`, because Dart has no generic getters and the framework
cannot name your model in an extension on `Ref`. They are shorthand, not the source: delete the file
and the providers still work.

When the id is all you need — a filter, a channel key, an ownership check — there is a third provider
beside them, and no reason to pull the whole profile out to reach `.id`:

```dart
// int? — null while signed out, and null in an app running without a DartWay session
ref.watch(dw.signedInUserIdProvider)
```

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

`dwBuildListAsync` asserts that a placeholder is obtainable, but the assert only checks that
`DwConfig.defaultModelGetter` is wired at all (the app passes `dwGetDefault`), not that your
particular model is registered. A new model means a new `setupRepository` call, always.

Both the assert and the placeholder itself belong to the loading branch and run nowhere else — a
widget test that hands the builder a ready `AsyncData` never touches the registry, and so does not
have to stand it up. A list test that *does* fail on a missing placeholder is a test of the loading
state, whether or not it was written as one.

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

## Providers live at the root

Your app writes no `ProviderScope`. `DwAppRunner` creates the only one, around everything; tests
build their own and are welcome to.

The temptation it forbids is a nested scope that overrides a provider for one subtree — a screen
showing the same widgets "as an admin", a route fixing a mode, a panel with its own copy of some
state. It reads as a clean way to inject a value without threading it through the tree, and for
widgets it genuinely works: a `WidgetRef` resolves from the nearest scope above its widget and sees
the override.

A provider does not. Reading through its own `Ref`, it resolves from the container hosting *it* —
the root, for anything that declares no `dependencies` — and gets the base value. Nothing throws,
nothing warns, and the screen shows something other than what you overrode. The failure appears
later, when someone adds a provider that reads a value two other widgets were reading happily.

So a value that differs per subtree is passed, not scoped: a family key, or a constructor argument
to a notifier.

```dart
// ❌ the override is invisible to any provider that reads workspaceModeProvider
ProviderScope(
  overrides: [workspaceModeProvider.overrideWith(() => IssuesMode())],
  child: const WorkspacePage(),
)

// ✅ the mode is an argument — visible in the call, and the same value for everyone
final workspaceStateProvider =
    NotifierProvider.family<WorkspaceState, WorkspaceData, WorkspaceMode>(
  WorkspaceState.new,
);
```

`dartway_lints` enforces this as `forbidden_provider_scope`. Riverpod ships a rule for the same trap
(`scoped_providers_should_specify_dependencies`) which cannot help you here: it only reasons about
providers written with code generation, and DartWay writes them by hand.

## State that is not server data

"How this list is sorted", "is this panel collapsed", "which tab was open" is state too, and it never
goes near `dw.repo`. Two questions place it, in this order.

**Does it survive a restart?** No — an ordinary `Notifier`, in memory like anything else. Yes — the
[`dartway_shared_preferences`](plugins.md) plugin, `dw.plugins.prefs`. It hands back a riverpod
provider, so persisting a value costs no reactivity: the same `ref.watch`, and every reader on the
screen sees one value.

**Does it belong to an entity?** No, it is one setting for the whole app — a constant key:

```dart
final darkModeProvider =
    dw.plugins.prefs.provider<bool>(key: 'darkMode', defaultValue: false);
```

Yes, there is one per project, per chat, per section — the family form, where `keyFor` builds the key
from the argument:

```dart
final projectSortProvider = dw.plugins.prefs.providerFamily<String, int>(
  keyFor: (projectId) => 'project.$projectId.sort',
  defaultValue: 'name',
);

final sort = ref.watch(projectSortProvider(project.id));
ref.read(projectSortProvider(project.id).notifier).update('createdAt');
```

The family is what makes this safe, not just short. `provider` takes a constant key and must be
declared once, like any riverpod provider: call it per id and each call builds a *new* provider, so
two of them over one key never see each other's writes. A family is declared once and riverpod keeps
one provider per argument value, which is exactly the guarantee the loop cannot give.

`mappedProvider`/`mappedProviderFamily` are the same pair for enums and custom types, stored as a
`String`. `dw.plugins.prefs.raw` is the underlying store, for a genuine one-off imperative read — a
store class of your own built on it has no subscribers, and the state ends up trapped in one widget's
`State`.

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

The `copyWith` above is not a style choice. Rebuilding an existing row by naming its fields —
`SessionBooking(id: booking.id, …)` — is how a field added later gets silently reset to its default
on every save, and `model_rebuild_by_constructor` (`dartway_lints`) warns about it. The reasoning,
and why clearing a nullable field is `copyWith`'s job too, is in
[models](../2-core/models.md#an-existing-row-is-rebuilt-with-copywith-never-field-by-field).

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
