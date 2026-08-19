---
name: dartway-data-layer
description: >-
  DartWay Flutter data layer and specials (DartWay projects): data access only
  through dw.repo — reads are providers under the native ref.watch/read/refresh
  (dw.repo.model/maybeModel/modelList), writes are dw.repo.saveModel/deleteModel
  (no repositories, no manual syncing), lists via dwBuildListAsync(loadingItemsCount:),
  narrowing by query via backendFilter, local filtering you do yourself with .where in the widget,
  an entity and everything hanging off it read in ONE request (include on the server, DwRelationUpdatesConfig
  for live child updates — a parent that leaves the server without its include silently blanks the
  nested lists on every client),
  actions from the UI via dw.action (unified error/loading handling), notifications via dw.notify.* (not SnackBar),
  the profile via ref.watchUserProfile/readUserProfile (getters, not CRUD), sign-out via
  sessionProvider.notifier.signOut(), local screen state that survives a restart via
  dw.plugins.prefs (providerFamily/mappedProviderFamily when the value belongs to an entity).
  Use when working with data, actions, notifications, local state,
  loading/saving models in Flutter features.
---

# DartWay — data layer and specials (Flutter)

In DartWay Flutter **data access and side effects go through a ready-made data layer**, not through repositories, manual `Future`/`setState` and raw popups. This gives uniform error handling, loading and reactivity. The source of cleanliness rules is `dartway-clean-code`; the layer map is `__FLUTTER_PKG__/CLAUDE.md`.

> ⚠️ The API below is verified against the codebase. Reads are providers under `ref.watch(dw.repo.…)`, **not** `ref.watchModel`. `DwCallback` **does not exist** — it is `DwUiAction`. `watchUserProfile` is a **getter** (no parentheses).

---

## 1. Data access — only through `dw.repo`

**Why:** one data entry point for all features. Reads are riverpod providers that you consume with the **native** `ref`: `ref.watch` — a reactive subscription (the UI rebuilds), `ref.read(...future)` — a one-off read, `ref.refresh(...future)` — a forced fresh fetch. Writes are methods. The read/write config is set on the server (`DwCrudConfig`), the frontend needs no repositories.

```dart
// ❌ your own repository / a manual future / a direct client
final repo = ChatRepository();
final posts = await repo.fetchPosts();

// ✅ dw.repo — the single data entry point
final coursesAsync = ref.watch(dw.repo.modelList<LearningCourse>());         // reactive list
final course       = ref.watch(dw.repo.model<LearningCourse>(filter: ...));  // AsyncValue<T>, missing → StateError
final maybe        = ref.watch(dw.repo.maybeModel<UserCourse>(filter: ...)); // AsyncValue<T?>, null instead of an error
final once         = await ref.read(dw.repo.model<LearningCourse>(id: 1).future); // one-off read
await dw.repo.saveModel(updatedCourse);                                      // create+update (one save)
await dw.repo.deleteModel(post);
```

**Reads are the `dw.repo.model/maybeModel/modelList` providers under the native `ref`; writes are the `dw.repo.saveModel/deleteModel` methods.** No `ref.watchModel` and no `DwRepository.` — the single data access point is `dw.repo`. `model` throws a `StateError` if the model is missing; `maybeModel` returns `null`. A forced fetch is `ref.refresh(dw.repo.maybeModel(...).future)` (the fetching provider). **Create and Update are one `saveModel`** (the CRUD law).

**What you hand to `saveModel` is a `copyWith`, not a rebuilt model.** `saveModel(SessionBooking(id: booking.id, …))` compiles today and silently resets tomorrow's field to its default — `default=` and nullable make those constructor arguments optional. See `dartway-clean-code` §1.10; `model_rebuild_by_constructor` (`dartway_lints`, warning) flags it in the editor.

## 2. Lists — through `dwBuildListAsync`

**Why:** a single render of `AsyncValue<List<T>>` with skeletons on loading and error handling — without a scattering of `when(loading/error/data)`.

```dart
// ❌ a manual when with loading/error copy-pasted into every feature
coursesAsync.when(loading: () => ..., error: (e, _) => ..., data: (list) => ...);

// ✅
coursesAsync.dwBuildListAsync(
  loadingItemsCount: 5,
  childBuilder: (list) => ListView(
    children: [for (final course in list) CourseCard(course: course)],
  ),
);
```

**When you introduce a new model, register its default instance** in `__FLUTTER_PKG__/lib/core/default_models.dart` — one call per model:

```dart
dw.repo.setupRepository(
  defaultModel: ClubSession(id: dw.repo.mockModelId, capacity: 10, ...),
);
```

This is the one model construction in your app that names an id without rebuilding a row: `mockModelId` is a sentinel and the instance is invented from nothing, which `model_rebuild_by_constructor` knows — the file needs no `// ignore_for_file:`.

The skeleton is drawn from your own widget built on that instance — that's why it resembles the future content rather than a generic shimmer. Without registration the very first `dwBuildListAsync` fails at runtime: `Default Objects Repository doesn't contain a model of type X`.

**The placeholder is built in the loading state only**, so a widget test of a list screen that hands the builder a ready `AsyncData` does not have to stand up the default models — if a test does need them, that test is really exercising the loading state.

## 3. Filtering — count the round trips, not the filters

**Why:** what costs something is **how many times a screen asks the backend**, and a `modelList`
without a `backendFilter` is not a lapse. Reading a list broadly — whole, even — and picking out
what you need locally is the **right** answer whenever it saves a request. Local filtering of
already loaded data the framework deliberately **does not provide**: it is a trivial `.where`, do it
yourself in the widget, don't look for a "framework" way.

**Several `modelList` calls with the same config are one request.** `DwModelListStateConfig` is a
family key with value equality — `backendFilter`, `paginationStrategy`, `apiGroupOverride`,
`relationUpdatesConfigs`, the custom listener and the sorter all take part in `==`. So two features
watching the same list are two readers of **one** provider, not two fetches: splitting a screen into
small features costs nothing on the wire, and merging them "to save a request" saves none. The
metric to watch is the number of *distinct* configs a zone builds, not the number of `modelList`
calls in it.

> The one field left out of that equality is `orderByList`. Two lists differing **only** in their
> order share a provider, and whichever was built first decides the order for both. Order such a
> list on the client instead.

**`backendFilter` is for a selection that otherwise would not fit or would carry rows that are not
this user's business** — one client's bookings, one chat's messages, one project's records. Not for
carving a list you already hold into slices: that is `.where`.

**The choice is one line in the feature's passport**, so the next reader does not re-open it. An
`implementationNotes` entry of the shape *"Data — `modelList<CommunityEvent>()` with no
`backendFilter`: the block takes the whole list and shows all of it"* settles the question for good;
so does *"filtered on the backend — a member must not receive another member's rows at all"*.

**Server-side filter — `backendFilter:`.** Filters are an enum with `DwBackendFiltersMixin` and its `.equals()`/`.greaterThan()`:

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();

  static DwBackendFilter clientBookings(int id) =>
      AppBackendFilters.clientProfileId.equals(id);
}

// in the feature:
ref.watch(dw.repo.modelList<SessionBooking>(
  backendFilter: AppBackendFilters.clientBookings(ref.watchUserProfile.id!),
));
```

`DwGetModelListConfig` on the server **does not require** a `filterPrototype` (unlike `DwGetModelConfig` for a single model) — list backend filters work without registering a prototype. Security is on the config's `accessFilter` (server), not on client-side narrowing.

**Local filter/search — a plain `.where` in the widget.** Keep the search string in a Riverpod provider, filter the already loaded list right in the builder:

```dart
final query = ref.watch(searchQueryProvider);
coursesAsync.dwBuildListAsync(
  childBuilder: (list) {
    final visible = list.where((c) => c.title.contains(query)).toList();
    return ListView(children: [for (final c in visible) CourseCard(course: c)]);
  },
);
```

## 3a. Relations — the graph arrives with the model, it is not assembled on the client

**Why:** an entity and everything hanging off it is **one** read. A screen that fetches the parents,
then the comments, then the events, then the attachments, and stitches them together by foreign key
in memory has re-implemented the join the database does for free — and it pays for it four times on
the wire, in four separate provider lifecycles that can disagree with each other. A production
screen once opened with **seven** flat `modelList` calls and a hand-written matcher on top of them;
it now opens with one.

**How the graph gets there — three declarations, none of them in the widget:**

1. the relation is declared in the YAML, bidirectionally — the same `relation(name=…)` on both
   sides (`dartway-models`). The relation field on the parent is always `?`: `null` there means
   "not loaded", not "absent";
2. the CRUD config raises it with `include` (`dartway-crud-config`) — on `DwGetModelListConfig`,
   and on every `DwGetModelConfig` that returns the same entity;
3. the children arrive as ordinary fields of the model. The screen reads `ticket.comments`, and
   `dartway-clean-code` §1.3a decides where the reading-out lives: an extension on the model.

```dart
// SERVER — the include is a named value, because everything that returns this
// entity must use the same one (see the warning below)
final supportTicketInclude = SupportTicket.include(
  comments: TicketComment.includeList(),
  events: TicketEvent.includeList(),
);

final supportTicketCrudConfig = DwCrudConfig<SupportTicket>(
  table: SupportTicket.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: _ticketAccessFilter,
    include: supportTicketInclude,
  ),
  saveConfig: DwSaveConfig<SupportTicket>(
    allowSave: _allowTicketSave,
    afterSaveTransform: _reloadTicketGraph,   // re-reads with the include
  ),
);
```

**The depth of the graph is exactly the depth the screen thinks in.** A flat list of children that
an extension sorts into place on the client is **cheaper** than a second level of nesting: nesting
a child inside its sibling means the same rows travel twice. A reply is a comment with a
`parentCommentId` — let it arrive in `comments` and let `repliesOf(comment)` find its owner.
Go two levels deep only when the second level genuinely holds different rows.

**Live changes to a child do not come as a new graph.** The server publishes the changed child
**flat**, and the client folds it into its parent by foreign key — `DwRelationUpdatesConfig` in the
list's config:

```dart
/// The zone's single query: tickets with everything hanging off them.
final projectTicketsProvider =
    Provider.family<AsyncValue<List<SupportTicket>>, int>(
  (ref, projectId) => ref.watch(
    dw.repo.modelList<SupportTicket>(
      customConfig: DwModelListStateConfig<SupportTicket>(
        backendFilter: AppBackendFilters.projectId.equals(projectId),
        relationUpdatesConfigs: _ticketRelationUpdates,
      ),
    ),
  ),
);

/// ⚠️ Declared **once, at the top level** — see the trap below.
final _ticketRelationUpdates =
    <DwRelationUpdatesConfig<SupportTicket, SerializableModel>>[
  DwRelationUpdatesConfig<SupportTicket, TicketComment>(
    relationKey: 'ticketId',
    copyWithRelatedModels: (ticket, updates) => ticket.copyWith(
      comments: updates.mergedInto(ticket.comments, (comment) => comment.id),
    ),
  ),
  DwRelationUpdatesConfig<SupportTicket, TicketEvent>(
    relationKey: 'ticketId',
    copyWithRelatedModels: (ticket, updates) => ticket.copyWith(
      events: updates.mergedInto(ticket.events, (event) => event.id),
    ),
  ),
];

/// Changed rows replace, new ones are appended, deleted ones disappear. Nothing
/// has to be filtered by parent here — the framework already selected this
/// parent's updates by `relationKey`.
extension RelatedModelUpdates on List<DwModelWrapper> {
  List<Related> mergedInto<Related>(
    List<Related>? currentItems,
    int? Function(Related item) idOf,
  ) {
    final updatedIds = map((update) => update.modelId).toSet();
    return [
      ...?currentItems?.where((item) => !updatedIds.contains(idOf(item))),
      ...where((update) => !update.isDeleted).map((u) => u.model as Related),
    ];
  }
}
```

`parentIdsGetter:` is the extra argument for a child that hangs off a **nested** level (a reply
whose `relationKey` points at a comment, not at the ticket): it tells the framework which ids on the
parent count as owners.

> **Trap: the list of relation configs is compared by identity.** `DwModelListStateConfig` is a
> family key, and it compares `relationUpdatesConfigs` as a **list reference**. Built in place — in
> a provider body, in `build` — it yields a *new* family key on every rebuild: a re-fetch, lost
> state, an endless redraw. Nothing throws; the app just behaves strangely. Declare the list once,
> as a top-level `final`, and hand that same instance in.

### ⚠️ A flat parent on the wire erases the graph

**`DwSingleModelState` and `DwModelListState` both *replace* the model with whatever arrives.** So a
parent that leaves the server **without** its include — the answer to a save, a publication from a
worker, an `afterUpdates` entry written by a neighbouring config — blanks the nested lists for
**every** subscriber holding it. The screen then shows a ticket with no conversation and no history
and **reports no error at all**: on the client a relation that does not exist and a relation that
was not requested are the same `null`.

This is not hypothetical. One production project caught it in the field and wrote the reason into
its config as a comment; the next project met it on its very first `include`.

**The rule: a model that has an include leaves the server only with it.** All three exits, not just
the obvious one:

- the answer to `saveModel` → `afterSaveTransform` re-reads the row with the same include
  (`currentModel` at that point holds the flat row that was written);
- anything put into `beforeUpdates`/`afterUpdates`, including by a *child's* config;
- anything sent over the socket — `broadcastTo`, `sendUpdates`, `sendUpdatesToUser`, from a worker
  included.

**Children travel flat and need no re-read** — `DwRelationUpdatesConfig` puts them where they
belong. It is the parent, and only the parent, that has to be reloaded.

Give that reload a name and let everything use it:

```dart
/// Every ticket leaving the server is read from here — see the rule above.
Future<SupportTicket?> loadTicketGraph(
  Session session,
  int ticketId, {
  Transaction? transaction,
}) => SupportTicket.db.findById(
      session,
      ticketId,
      include: supportTicketInclude,
      transaction: transaction,
    );
```

**The review check, and it is countable:** the number of places a parent goes out equals the number
of calls to that loader. A `DwModelWrapper(object: <parent>)` built straight from a model in hand is
the bug — wherever it sits, and however innocuous the hook that writes it looks.

## 4. Actions from the UI — `dw.action`

**Why:** a single wrapper for user actions (taps, submits): automatic loading state, error handling (with a report to alerting — see `label`), confirmations. The callback receives a `BuildContext`. Don't wrap things in a raw `() async {}`/`onPressed`.

```dart
// ❌ a raw handler: errors and loading by hand in every widget
onPressed: () async { await doSomething(); }

// ❌ a manual confirm dialog inside the action (the pain of legacy projects)
final confirm = await showDialog<bool>(...); if (confirm != true) return;

// ✅ dw.action — context, a typed result, a built-in confirm
final deleteAction = dw.action<bool>(
  (context) async {
    await dw.repo.deleteModel(post);
    return true;
  },
  label: 'deletePost', // the action name in error reports/alerts
  confirmation: DwUiConfirmation('Delete this post?', isDestructive: true),
);
// in the widget: onTap: deleteAction   (or dw.action((_) async {...}) if context isn't needed)
```

> The real name is **`DwUiAction`** (46+ usages). There is no `DwCallback` in the project.
> Declining the confirm dialog cancels the action entirely (no notifications, no follow-up). A custom dialog is `DwConfig.confirmDialogBuilder`. Action errors automatically reach alerting with context (route, screen features, `label`) — see the framework's error-reporting doc.

**`dw.action` says what to write an action with; where it lives is `dartway-clean-code` §1.9b —
in the widget that owns the button.** Not a callback handed down from a parent, and not a screen-wide
`busy` flag: `DwActionBuilder` computes busy per button already.

> **What a widget test over a self-writing feature covers, and where its seam is.** A feature that
> saves for itself gives a test no callback to assert on. That seam went with the parameter, and
> bringing it back is the wrong trade: **do not keep a callback alive as a test seam** — it buys a
> weaker screen for a weaker test.
>
> The seam is one level down, and it is the same one the framework uses on itself: **the transport
> handed to `DwCore`**. Pass `transport: DwRecordingServerTransport(serializationManager:
> app.Protocol())` from `package:dartway_serverpod_core_flutter/testing.dart` **instead of**
> `client:`, and nothing in the process has to stand up a Serverpod client for a widget to render.
> The protocol is the project's own generated one, imported prefixed because the core declares a
> `Protocol` too — it is the only thing that names the models right, since a generated model is an
> abstract class whose `runtimeType` reads `_NewsPostImpl`.
>
> It keeps every save and delete that left (`transport.saves`, `transport.deletes`) and answers
> reads from what the test prepared (`answerGetAll`, `answerGetOne`, `answerGetCount`); a read
> nobody prepared throws `DwUnpreparedServerCall` naming the call and the field that would answer
> it, while a save needs no setup — the default echoes the model back, because the assertion is
> about what *left*. What that gets you is "the button reached `saveModel` with this model", which
> is what a widget test should assert. What covers the **rule** is still an integration test over
> the CRUD config on the server, where the rule lives.
>
> Boot the core from `setUpAll` through **the app's own initializer**, given an optional `transport`
> parameter, and build no Serverpod client when it is set — a client brings a connectivity monitor
> and an auth key manager, both of which reach for platform channels. Without a key manager there is
> no session, so a test that needs a signed-in user overrides `dw.requireUserProfileProvider` in its
> own `ProviderScope`.
>
> Two traps about time, not about the transport: `pumpAndSettle` does not drain the toast a
> successful `onSuccessNotification` leaves behind (pump `DwUiNotification.defaultDuration` after
> the tap), and a read you made fail is **retried** by Riverpod with a backoff — assert the shape of
> what was asked, never the number of attempts.
>
> **The offline store is not that seam, and is documented not to be.** A write always goes to the
> network first; `dw.repo.localWrites` is reached only after the call fails with a connection error.
> Reaching for it to watch a save would force every save to declare itself queued, which is a lie
> about intent.
>
> One thing to know before writing the test at all: the feature reaches `dw` **while building**, not
> on the tap — `dw.action(...)` is constructed in `build`. So the core has to be up for the widget
> to render, even in a test that never interacts. Without it the subtree does not build and the test
> fails later at a finder ("found 0 widgets"), with the real cause in a separate exception block
> above. Boot it from `setUpAll` through the app's own initializer, and keep that initializer
> idempotent so no test file has to know whether another one booted the core first.

## 4a. Derived state — a provider, not assembly in the widget

State derived **from several sources** or containing a rule lives in a provider,
it is not assembled in `build`.

```dart
// ❌ the widget stitches three watches by hand and feeds them to a function — recomputed on every build
final state = resolveSomething(
  a: ref.watch(providerA), b: ref.watchUserProfile.flag, c: ref.watch(providerC),
);

// ✅ the provider knows where the data comes from; a pure function — what follows from it
final state = ref.watch(somethingProvider(id: id));
```

**We write providers by hand, without `riverpod_generator`** (see the code generation policy in `CLAUDE.md`):

```dart
final courseLockStateProvider =
    Provider.family<CourseLockState, ({int? courseId, int accessCourseId})>(
  (ref, args) => CourseLockState.resolve(
    userCourse: ref.watchUserCourseById(args.accessCourseId),
    hidePaidFeaturesInfo: ref.watchUserProfile.hidePaidFeaturesInfo,
    now: DateTime.now(),
  ),
);
```

**A family notifier is also written by hand.** `NotifierProvider.family` is declared as
`NotifierT Function(ArgT arg)` — the argument arrives in the factory, the notifier takes it through its constructor:

```dart
class AudioControllerNotifier extends Notifier<AsyncValue<AudioControllerState>> {
  AudioControllerNotifier(this._args);
  final AudioControllerArgs _args;
  @override
  AsyncValue<AudioControllerState> build() { /* ... _args.mediaId ... */ }
}

final audioControllerProvider = NotifierProvider.family<
    AudioControllerNotifier, AsyncValue<AudioControllerState>, AudioControllerArgs>(
  AudioControllerNotifier.new,
);
```

The framework itself is built this way (`DwModelListState(this.config)`). The internal `ref.$arg` that
code generation uses is not needed by a hand-written class — and must not be touched, it is `@internal`.

**A family key is a value with meaningful equality.** Serverpod models compare by identity:
a family keyed by a model creates a new provider on every build, recomputing and auto-disposing for nothing.
The key is identifiers or a **record** of them: a record has value equality out of the box, so the hand-written
option doesn't lose to the generator here, it wins — without waiting for `build_runner`.

**A provider does not reach into another feature's internals.** Data access extensions are usually declared on
`WidgetRef`, while inside a provider you have `Ref` — the temptation to import a neighbouring feature's `logic/`
is strong and is caught only by the checker. The right move: **that feature's public file provides an extension on `Ref`**.

**Don't introduce local state on top of server state.** A write through `dw.repo` updates the lists itself:
"requests already sent" do not need to be accumulated in a `Set<int>` — the response is already in the list the
screen watches anyway. A local copy of server truth is a second source that can only drift from the first.

**Don't introduce shims over the framework API.** `ref.saveModel(...)` forwarding the call to
`dw.repo.saveModel(...)` adds nothing but hides the real API: on a production project 82 calls lived on such a
pass-through, and half the team didn't know what they were calling.

**One provider answers one question — it does not serve one screen.** The rule above is easy to
honour and still get backwards: a provider that assembles *everything the screen will need* passes
every test in this section (it is a provider, it holds a pure function, nothing is stitched in
`build`) and yet puts the screen straight back into prop-drilling. Once the top has decided
everything, the widgets below it have nothing left to ask, and every value reaches them as a
constructor argument.

The symptoms, in order of how reliably they give it away:

- **the name.** `<Screen>Snapshot`, `<Screen>State`, `<Screen>ViewModel` — named after a place in
  the UI rather than after a question. A provider named for what it answers cannot grow this way:
  nothing else fits under `openTaskCountProvider`;
- **the audience.** Fields that fewer than half of the consumers read. A seventeen-field object
  serving six widgets is six providers that have not been written yet;
- **the arity.** Derived from a **single** model — not a provider at all. That is an extension on
  the model (`dartway-clean-code` §1.3a): `ticket.openComments`, `ticket.canBeClosed`. It needs no
  container, no family key and no lifecycle, and it is reachable from the model through the dot at
  any depth of the tree.

A provider earns its existence when the answer draws on **several sources** (§4a above) or has to
be cached across rebuilds. Everything a widget could have asked for itself, it asks for itself.

### Overriding a provider in a test

**A test is the only place that writes a `ProviderScope`** — in the app the single one belongs to
`DwAppRunner`, and `forbidden_provider_scope` (`dartway_lints`, warning) flags any other. A nested
scope with `overrides:` is read by widgets and silently missed by providers, which resolve from the
root container; a value that must differ per subtree is a family key or a constructor argument.

A **hand-written** `NotifierProvider` has no `overrideWithValue` — that method exists only on value
providers. What gets overridden is the factory: a subclass that overrides `build()` with a ready value.

```dart
// ❌ doesn't compile: overrideWithValue is not defined for NotifierProvider
overrides: [userCoursesStateProvider.overrideWithValue(userCourses)],

// ✅ a fake notifier: the test checks the extension over the state, not its loading
class _FixedUserCoursesState extends UserCoursesState {
  _FixedUserCoursesState(this.fixedCourses);
  final List<UserCourse> fixedCourses;
  @override
  List<UserCourse> build() => fixedCourses;
}

overrides: [
  userCoursesStateProvider.overrideWith(() => _FixedUserCoursesState(userCourses)),
],
```

**For a family, `overrideWith` takes a parameterless factory** — `() => notifier`, not
`(arg) => notifier`, even though `NotifierProvider.family` itself is declared as `NotifierT Function(ArgT)`.
The whole family is overridden at once, so you hand the argument to the fake yourself through its constructor:

```dart
final fake = FakeAudioControllerNotifier(
  const AudioControllerArgs(246, 'https://example.com/podcast.mp3'),
);
overrides: [audioControllerProvider.overrideWith(() => fake)],
```

A subclass of a family notifier must **forward the argument to `super`** and override the
parameterless `build()` — the one that took arguments stayed in the code generation world:

```dart
class FakeAudioControllerNotifier extends AudioControllerNotifier {
  FakeAudioControllerNotifier(AudioControllerArgs args) : super(args);
  @override
  AsyncValue<AudioControllerState> build() => const AsyncValue.loading();
}
```

## 4b. Local screen state — two questions decide where it lives

**Why:** "the sort order of this list", "is this panel collapsed", "which tab was open" is state
too, and an app that answers the question differently in every feature ends up with three ways to
store the same thing — chosen by copying the neighbouring file rather than by a rule. There are two
questions, in this order.

**1. Does the value survive a restart?** No — an ordinary `Notifier` (§4a), it is in-memory state
like any other. Yes — `dw.plugins.prefs`, the local-storage plugin
(`dartway_shared_preferences`, declared in `plugins:` next to the config). It gives back a riverpod
provider, so persistence costs you no reactivity: the same `ref.watch`, and every reader on the
screen sees the same value.

**2. Does the value belong to an entity?** No (one setting for the whole app) — a constant key.
Yes (one per project, per chat, per section) — the **family** form, where the key is built from the
argument:

```dart
// ❌ a hand-rolled store: read in initState, re-read in didUpdateWidget, write on change
class _SortStore { String read(int id) => ...; void write(int id, String v) => ...; }

// ❌ provider() called per id: every call builds a *new* provider, and two over one key
//    do not see each other's writes
final p = dw.plugins.prefs.provider(key: 'project.$projectId.sort', defaultValue: 'name');

// ✅ the family is the top-level `final`; riverpod holds one provider per argument value
final projectSortProvider = dw.plugins.prefs.providerFamily<String, int>(
  keyFor: (projectId) => 'project.$projectId.sort',
  defaultValue: 'name',
);

// in the widget — an ordinary watch, and any other reader of the same id sees the same state
final sort = ref.watch(projectSortProvider(project.id));
ref.read(projectSortProvider(project.id).notifier).update('createdAt');
```

`mappedProviderFamily(keyFor:, mapFrom:, mapTo:)` is the same for enums and custom types, exactly as
`mappedProvider` is to `provider`. Storage keys are namespaced by hand (`'project.$id.sort'`) —
`keyFor` returns the whole key, so a prefix that says which feature owns it costs one string.

**The hand-rolled store is the thing to stop writing.** A class with injected read/write over
`dw.plugins.prefs.raw` plus a `StatefulWidget` that re-reads in `didUpdateWidget` is thirty lines
that work — and have no subscribers. The state then lives in one widget's `State`, so a second
reader (a counter in the header, a "reset" button in another panel) can only receive it through
constructor arguments. `raw` is for a genuine one-off imperative read, not for state a screen
watches.

## 5. Notifications — `dw.notify.*` (not `SnackBar`)

**Why:** a single style of toasts/notifications across the whole app. Don't poke `ScaffoldMessenger`/`SnackBar`/custom popups.

```dart
// ❌
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done')));

// ✅
dw.notify.success('Saved');
dw.notify.error('The file is too large');
dw.notify.warning('Check the fields');
dw.notify.info('Upload started');
```

## 6. User profile — `ref.watchUserProfile` (a getter, not CRUD)

**Why:** the current profile is a special source, not an ordinary model. Don't pull it through `watchModel<UserProfile>()`.

```dart
// ❌ the profile through ordinary CRUD
final me = ref.watch(dw.repo.model<UserProfile>(...));

// ✅ special getters (no parentheses!) — they return UserProfile directly
final isMine = post.authorProfileId == ref.watchUserProfile.id;   // reactive
final myId   = ref.readUserProfile.id;                            // one-off
```

**The providers underneath are the framework's, the getters are the project's.** `dw` carries a pair, already typed with your profile model:

- `dw.userProfileProvider` → `UserProfile?` — where signed out is a legal answer: router guards, the auth zone, a splash;
- `dw.requireUserProfileProvider` → `UserProfile` — everything under `DwUserAsyncScope`; throws a `StateError` when nobody is signed in.

The getters above are two lines of shorthand over the second one, scaffolded by `dartway create` into `__FLUTTER_PKG__/lib/core/user_profile_provider.dart` (Dart has no generic getters, so the framework cannot name your model in an extension on `Ref`). Don't delete that file — but don't reimplement the providers in it either.

Reach for the provider directly in two cases: the user may be signed out, or you want to rebuild on one field only —

```dart
final name = ref.watch(dw.requireUserProfileProvider.select((p) => p.firstName));
```

Need only the id — for a filter, a channel key, an ownership check? `dw.signedInUserIdProvider` → `int?`, `null` while signed out. Don't reach through the profile for it, and don't read `dw.sessionProvider!` by hand:

```dart
final userId = ref.watch(dw.signedInUserIdProvider);
```

## 7. Sign-out — through `sessionProvider`

**Why:** ending a session is a centralized dartway-session operation, not a hand-written state reset.

```dart
// ✅ as in the codebase
ref.read(dw.sessionProvider!.notifier).signOut();
```

## 8. Real-time between users — `broadcastTo` in the config

**What is NOT there by default:** `saveModel` returns the update **only to whoever saved it**. So "client A signed up — it updated by itself for client B" does not work on its own: `dw.repo.modelList` is reactive to *its own* edits.

**It is switched on by one line — on the server, in the CRUD config.** Nothing needs to be written in Flutter: the app is already subscribed to the public channel in its root.

```dart
// SERVER — in the model config:
saveConfig: DwSaveConfig<NewsPost>(
  allowSave: ...,
  broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],
),
deleteConfig: DwDeleteConfig<NewsPost>(
  allowDelete: ...,
  // without this, everybody else keeps a deleted row hanging around
  broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
),
```

A model arriving in the channel is routed by type into **any** `dw.repo.modelList<T>()` of the subscribers — the list redraws itself, with no update code on either side.

**A channel is an audience, and the framework cannot check who is in it.** Everything the save touched flies out to every subscriber — regardless of whether `accessFilter` would have shown them that row or not. Hence two rules:

- `broadcastTo` — **only for models that are public in their entirety** (a catalog, prices, stock, published news). Their `accessFilter` is open to the whole audience anyway;
- for rows belonging to one person (orders, messages, profiles) — **don't broadcast**, notify the owner: `session.sendUpdatesToUser(id, updatedModels: [...])`.

**When you need to choose what exactly flies out** (a private row is saved, but a public counter changed) — an imperative call in `afterSaveSideEffects`:

```dart
// only the public session flies out, the booking itself stays private
session.sendUpdates(
  channels: [DwCoreConst.publicUpdatesChannel],
  updatedModels: [updatedSession],
);
```

**Sending from a worker, a future call or a cron job — `global: true`.** Both methods take the flag, default `false`, and the default is right while the app is one process: the clients are connected to the process doing the sending. A background worker in its own container is not that process, and its own subscriber list is empty.

```dart
session.sendUpdatesToUser(job.requestedByProfileId, updatedModels: [job], global: true);
```

**Forgetting it fails silently** — the call compiles, throws nothing and delivers to nobody, because an audience of zero is not an error. Tests do not save you either: a worker's publisher is normally injected, so the suite checks *who* the recipients are while the delivery is a fake, and a test config with `redis: enabled: false` looks perfectly ordinary.

A channel can be narrowed to the audience you need and built from the context — `['chat:${ctx.currentModel.chatId}']`. Then a screen subscribes to it precisely:

```dart
DwChannelSubscriptionWidget(channel: 'chat:$chatId', child: messagesList)
```

**Both halves or neither:** a channel the app names itself must also be declared on the server, in `DwCore.init(channelConfigurations: ...)` — see `dartway-crud-config`. An undeclared channel is refused, and a refusal is not retried: the screen simply never updates, and the reason arrives in the error handler rather than on screen.

### Which channel to listen to and where to send is the decision itself

A channel is a **broadcast bus**: **everything** posted into it arrives at **every** subscriber. So **scope the channel to the audience that actually needs the update**. The question is always one: "who is entitled to see this change?" — and send to / subscribe exactly them.

| Audience of the update | Channel |
|---|---|
| Public to everyone (catalog, prices, stock, news) | `DwCoreConst.publicUpdatesChannel` — the app is subscribed to it in the root |
| A group (chat room, board) | a channel keyed by the group: `'chat:$channelId'` — subscription on the group's screen |
| Private to one user (their booking was cancelled) | `session.sendUpdatesToUser(userId, ...)` — their personal channel, no subscription needed |

**The anti-pattern is sending everything into the common channel.** What is dangerous is not the common channel itself (it exists precisely for the public), but what gets put into it: if a private row goes there, every subscriber gets it — `accessFilter` no longer works here, it is about reading through the API. The check before putting `broadcastTo` with a public channel: **"is any user entitled to read this row anyway?"** No — then the channel is narrower, or it's `sendUpdatesToUser`.

The second frequent miss is hanging `broadcastTo` on a private model's config for the sake of a public side effect (we save a booking, but what has to be shown is the seat counter). `broadcastTo` sends **everything the save touched**, including the booking itself. In that case — an imperative `session.sendUpdates(channels: [...], updatedModels: [publicModel])`, where you choose what flies out.

The rule: **the channel's scope = exactly those who are entitled to see this change.**

---

## 9. Files and images — `DwFileUploadHandler`

**Why:** picking a file, uploading it to storage and getting a public link — one call. You don't need your own picker, your own http client and your own endpoint.

```dart
// ✅ the whole upload end to end: picker → storage → public URL
final imageUrl = await DwFileUploadHandler.pickAndUploadImageUrl();
if (imageUrl == null) return;              // null = the user closed the picker, that's not an error
await dw.repo.saveModel(userProfile.copyWith(imageUrl: imageUrl));
```

From then on the link lives as an ordinary model field and travels the same CRUD path as the rest — there is no separate "file" layer in the app.

Neighbouring forms: `pickAndUploadImage()` (returns a `DwCloudFile` with size and mime), `uploadXFileToServer(xFile:)` — when the file is already obtained (camera, drag-n-drop).

**Wrap it in `dw.action`** — the upload is long, and `DwActionBuilder` will suppress a repeated tap by itself and hand back `busy` for the indicator.

**What is needed on the server:** `cloudStorageConfig` in `DwCore.init` (in the project these are the `dwCloudStorage*` keys in `config/passwords.yaml`, and in development the `minio` service from `docker-compose.yaml`). If storage is not configured, the upload will honestly say so instead of failing silently.

---

## 10. Offline — a store on the core, and a flag per query

**Why:** `dw.repo` is network-only. A read that cannot reach the backend fails, and so does a write. That is the right default and you leave it alone unless the project asked for offline.

If it did, the project declares a **local store** once, at bootstrap, as a plugin:

```dart
dw = DwCore<Client, UserProfile>(
  // ...
  plugins: [DwOfflinePlugin(config: offlineConfig)],
);
```

**There is no setter.** `dw.repo.localReads` and `dw.repo.localWrites` are read-only — if you are looking for where to assign a store, you are looking for something that deliberately does not exist. A store assigned after startup outlives the core it was attached to, and the failure is silent: everything keeps working, the writes go somewhere that belongs to nobody.

**Feature code does not change.** The same `ref.watch(dw.repo.modelList<X>())`, the same `await dw.repo.saveModel(...)`. Do not write a branch for "are we offline" — there isn't one to write.

**A read opts in for itself:**

```dart
ref.watch(
  dw.repo.modelList<Lesson>(
    customConfig: DwModelListStateConfig<Lesson>(
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
    ),
  ),
);
```

The default is `DwRepoReadStrategy.networkOnly`, and a store being declared does not change it. Turn it on for the handful of reads a screen genuinely needs without a network, not for everything.

**A write does not opt in at the call site at all.** Which writes are queued is decided inside the store, per operation and model. Do not go looking for a `readStrategy` equivalent on `saveModel` — reading the two as a pair is the usual mistake, and a list kept offline for reading says nothing about whether saving that model is queued.

**What is queued and what is not.** Only a *connection* failure falls back to the queue. A rejected authorization or a validation error surfaces to you exactly as it does online — replaying it later would mean retrying a request the server already refused.

**Implementing a store is not app work.** It is `DwRepoLocalReads` / `DwRepoLocalWrites` in a package, and the core ships a conformance suite it has to pass (`package:dartway_serverpod_core_flutter/testing.dart`). If a task sounds like "cache this screen", the answer is a `readStrategy`, not a new store.

---

## Data-layer checklist

- [ ] Data — only `dw.repo`: reads are the `dw.repo.model/maybeModel/modelList` providers under `ref.watch/read/refresh`; writes are `dw.repo.saveModel/deleteModel`. No `ref.watchModel`, no `DwRepository.`, no repositories, no manual `Future`s, no direct client.
- [ ] Create and Update — one `saveModel` (not two different methods).
- [ ] `AsyncValue` lists — through `dwBuildListAsync(loadingItemsCount:)`, not a scattering of `when`.
- [ ] Narrowing by query — `backendFilter`; local filtering you do yourself with `.where` in the widget (the framework doesn't provide it). The count that matters is **distinct configs**, not `modelList` calls: reading broadly and picking locally is right when it saves a request (§3).
- [ ] An entity and what hangs off it — **one** read: relations declared in the YAML, raised with `include`, folded live by `DwRelationUpdatesConfig`, and that config list is a top-level `final` (§3a). No stitching flat lists by foreign key in the widget.
- [ ] Does a parent with an `include` leave the server anywhere **without** it — a save response, an `afterUpdates`, a socket send? That silently blanks the nested lists on every client (§3a).
- [ ] Actions from the UI — `dw.action((context) async {...})`, not a raw `onPressed`/`() async {}`, and written **in the widget that owns the button** (`dartway-clean-code` §1.9b).
- [ ] A provider answers **one question**, not one screen — no `<Screen>Snapshot`; derived from a single model is an extension on that model (§4a).
- [ ] Notifications — `dw.notify.success/warning/error/info`, not `SnackBar`/`ScaffoldMessenger`.
- [ ] Local screen state — survives a restart? `dw.plugins.prefs`, not a store over `raw`. Belongs to an entity? `providerFamily(keyFor:)`, not `provider` per id.
- [ ] Profile — `ref.watchUserProfile`/`readUserProfile` (getters), not `watchModel<UserProfile>()`. Signed out is a legal answer, or you want `.select` — `dw.userProfileProvider` / `dw.requireUserProfileProvider`. Only the id — `dw.signedInUserIdProvider`.
- [ ] Sign-out — `ref.read(dw.sessionProvider!.notifier).signOut()`.
- [ ] Must **another** user see the update? `dw.repo.modelList` doesn't do that by itself — `broadcastTo` in the config (public), a channel with the group id (group), `sendUpdatesToUser` (private).
- [ ] Offline — the store is declared in `DwCore(plugins: [...])`, never assigned; a read opts in with `readStrategy: networkFirstWithSnapshot`, a write does not opt in at the call site at all.
- [ ] Putting `broadcastTo` with a public channel — have you answered "any user is entitled to read this row"? If not — a narrower channel or `sendUpdatesToUser`.
