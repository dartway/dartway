---
name: dartway-data-layer
description: >-
  DartWay Flutter data layer and specials (DartWay projects): data access only
  through dw.repo — reads are providers under the native ref.watch/read/refresh
  (dw.repo.model/maybeModel/modelList), writes are dw.repo.saveModel/deleteModel
  (no repositories, no manual syncing), lists via dwBuildListAsync(loadingItemsCount:),
  narrowing by query via backendFilter, local filtering you do yourself with .where in the widget,
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

The skeleton is drawn from your own widget built on that instance — that's why it resembles the future content rather than a generic shimmer. Without registration the very first `dwBuildListAsync` fails at runtime: `Default Objects Repository doesn't contain a model of type X`.

**The placeholder is built in the loading state only**, so a widget test of a list screen that hands the builder a ready `AsyncData` does not have to stand up the default models — if a test does need them, that test is really exercising the loading state.

## 3. Filtering — `backendFilter` (server) + `.where` (client)

**Why:** to narrow a list with a query to the DB — through `backendFilter`. Local filtering of already loaded data the framework deliberately **does not provide**: it is a trivial `.where`, do it yourself in the widget, don't look for a "framework" way.

**Server-side filter — `backendFilter:`.** When a list must be narrowed by a query (your own records, the messages of one chat, upcoming sessions). Filters are an enum with `DwBackendFiltersMixin` and its `.equals()`/`.greaterThan()`:

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

## Data-layer checklist

- [ ] Data — only `dw.repo`: reads are the `dw.repo.model/maybeModel/modelList` providers under `ref.watch/read/refresh`; writes are `dw.repo.saveModel/deleteModel`. No `ref.watchModel`, no `DwRepository.`, no repositories, no manual `Future`s, no direct client.
- [ ] Create and Update — one `saveModel` (not two different methods).
- [ ] `AsyncValue` lists — through `dwBuildListAsync(loadingItemsCount:)`, not a scattering of `when`.
- [ ] Narrowing by query — `backendFilter`; local filtering you do yourself with `.where` in the widget (the framework doesn't provide it).
- [ ] Actions from the UI — `dw.action((context) async {...})`, not a raw `onPressed`/`() async {}`.
- [ ] Notifications — `dw.notify.success/warning/error/info`, not `SnackBar`/`ScaffoldMessenger`.
- [ ] Local screen state — survives a restart? `dw.plugins.prefs`, not a store over `raw`. Belongs to an entity? `providerFamily(keyFor:)`, not `provider` per id.
- [ ] Profile — `ref.watchUserProfile`/`readUserProfile` (getters), not `watchModel<UserProfile>()`. Signed out is a legal answer, or you want `.select` — `dw.userProfileProvider` / `dw.requireUserProfileProvider`. Only the id — `dw.signedInUserIdProvider`.
- [ ] Sign-out — `ref.read(dw.sessionProvider!.notifier).signOut()`.
- [ ] Must **another** user see the update? `dw.repo.modelList` doesn't do that by itself — `broadcastTo` in the config (public), a channel with the group id (group), `sendUpdatesToUser` (private).
- [ ] Putting `broadcastTo` with a public channel — have you answered "any user is entitled to read this row"? If not — a narrower channel or `sendUpdatesToUser`.
