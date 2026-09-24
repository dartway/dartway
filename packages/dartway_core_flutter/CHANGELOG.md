# Changelog

## 0.21.0-dev.2

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (#310, D-087).

## 0.21.0-dev.1

- Nothing changed here; the family moves in lockstep with `dartway_client`, fixed for #309.

## 0.20.0

- First publication of the rewrite to pub.dev.

## 0.20.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_shared` (#296).

## 0.20.0-dev.3

- **BREAKING: re-exports `dartway_router` 2.0.0** (#288): a zone guard takes the `DwNavigationTarget` it is asked about — `(state) => …` becomes `(state, target) => …`. The skeleton's gates use it to bring a person back to the link they opened after signing in. Migration note: `docs/migrations/2026-09-23-zone-guard-target.md`.

## 0.20.0-dev.2

- **`DwUploadNotifier.cancel()`** (#284): stops the running upload — the transfer is aborted, nothing is confirmed, `upload` answers `null`, the state goes back to `DwUploadIdle`, and nothing is reported. `dispose()` still does not cancel.
- **Flutter `>=3.44.0`** (#290): the package fails to compile on 3.41. The repository itself is written against 3.47.2 (#280).
- **`DwFeatureWidget.scanMounted` no longer reports the unselected tabs of an `IndexedStack` on Flutter 3.47**, which stopped wrapping them in a `Visibility` widget; it asks `Visibility.of` instead, which answers on 3.44 and 3.47 alike.

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`dw.deleteAccount()`** (D-072).

- **A list with no loading placeholder loads as nothing, not as an error.** `dwBuildListAsync` without `loadingItem` in an app whose `defaultModelGetter` is unset (or does not know the model) failed an assert in debug and threw in release, showing an error block until the data came; it now renders nothing while loading, as `dwBuildAsync` does. A skeleton is still built whenever a placeholder exists.

- **No run-time dependency on `flutter_native_splash`** (#268). The splash is held with the binding's `deferFirstFrame` and released after bootstrap; on the web a shell's `removeSplashFromWeb()` is still called when it defines one. The generator's `image`, `archive`, `xml`, `html` and their dependencies leave every app's graph. An app that runs `dart run flutter_native_splash:create` lists the package in its own `dev_dependencies`, as the template now does.

- **BREAKING: `DwErrorReport.actionLabel` is `label`**, and `dw.handleError(label:)` takes it for any source (#126). Migration note: `docs/migrations/2026-09-17-error-report-label.md`.

- **`dw.listen(channels)`** forwards `DwAppClient.listen`: hear a channel without reading a page (D-067).

- **`DwAppRunner` survives an error whose stack is not a `StackTrace`.** On the web `FlutterErrorDetails.stack` can hold a raw JavaScript value; the handler read it typed, threw inside itself, and the original error was lost. Any value is now turned into a `StackTrace` (`DwAppRunner.stackOf`).

- **`DwAppBootstrapper` is exported**, so a widget test can mount the app as
  `DwAppRunner` mounts it — initializers, loading and error screens, and the
  "update the app" screen over everything — instead of rebuilding that by hand.
- **`DwWindowListView`** — the chat list over `dw.window(request)`, not
  reversed: a `CustomScrollView` centred on the split between the items up to
  an anchor (growing upward) and those after it (growing downward), with the
  viewport's zero at its bottom edge. Loading older or newer items never moves
  what is on screen, and nothing compensates an offset after the fact. Opens at
  `initialAnchor` (the anchor item's bottom at `anchorAlignment`) or at the
  newest items, never with blank space under the newest; stays at the newest
  item as items arrive there; loads both ends as they come near; reports the
  items on screen, debounced (`onVisibleItemsChanged`). `DwWindowListController`
  scrolls to an item by cursor — animated when near, placed when loaded but
  far, reopening the window around it when not loaded — jumps to the newest
  (reopening at it when not loaded), and tells `isAtNewest`, `newerCount`,
  `topVisibleItem` and `isScrolling` for the "↓" button and a floating date.
- **Uploads:** `dw.files` (the client's `DwFileClient`) and `dw.uploader()` — a
  `DwUploadNotifier`, a `ValueNotifier` of `DwUploadIdle` / `DwUploadProgress`
  / `DwUploadDone` / `DwUploadError` for one upload slot of a screen. Refusals,
  a signed-out caller and an unreachable network stay in the state; server
  failures and storage refusing an upload go to the app's error reporting. No
  picker: choosing a file is the app's. `DwFlutterCore(storageTransport:)`.

## 0.9.0

- **A start that fails says so, and says what failed.** An initializer that threw was reported and
  then the app was expected to render an error screen — but the reporting ran first and
  unguarded, so a handler that threw in turn (DwCore's own alerting, talking to the server the
  start could not reach) left the failure flag unset. The app stayed on the loading screen, which
  under a native splash is a `SizedBox.shrink()`: nothing at all, on every launch, until the app
  was reinstalled. Reporting is now attempted inside its own guard and cannot decide whether the
  app gets a first frame.

- **`DwAppLoadingOptions.errorScreen` becomes `errorScreenBuilder`.** The screen is built from the
  error that failed the start, and the default one puts that text on it. A start can fail for
  reasons only the failure names, and the person looking at the screen is usually the one who will
  be asked what happened. **Breaking:** see `docs/migrations/2026-09-09-app-error-screen-builder.md`.

- **`DwNotAuthenticated`** — the answer "there is no session", as a type. Raised by
  `DwRepository.processApiResponse` for a response the server marked `isNotAuthenticated`, and
  sorted out by an app's `onErrorReport` with one type check, the way `DwRefusal` already is.

## 0.8.0

- **`DwKeyValueStorePlugin` — the role the framework asks for when it needs to keep a small value.**

  The core needed the signed-in session's key to survive a reload and reached for
  `shared_preferences` itself, in its own copy of the contract, while `dartway_shared_preferences`
  implemented the same job a package away. Two implementations that agreed only because they sat on
  the same store: a decision taken on one side — a fallback, a failure mode — could not be seen from
  the other, and a browser with no local storage broke both, separately.

  The role is declared here so neither side has to depend on the other, the same shape as
  `DwRepoLocalStorePlugin`. The framework asks through `maybeOf`, so nobody claiming it is an
  ordinary answer that turns into a message naming the plugin to declare.

- **One plugin's failed `init` no longer takes the whole app start with it, and the report says
  which plugin it was.**

  `DwPluginRegistry.initAll` ran the list bare: a single `init` that threw aborted `dw.init()`, so every
  plugin declared after it never ran and the application did not start at all. Declaration order
  silently decided the blast radius — not something an app author weighs while writing
  `plugins: [...]`. In production this cost a whole app start: the first plugin in the list met a
  browser with no `localStorage`, and the integrations after it, none of which needed storage,
  never got their turn. The report was as unhelpful as the outcome — a raw exception out of a
  third-party package, naming neither the plugin nor initialization.

  What a failure costs is now the plugin's own answer. **`DwFlutterPlugin.blocksStartup` defaults to
  `true`**, so nothing changes for an app that says nothing: a plugin it declared is one it expects
  to have. An integration that is genuinely optional sets it to `false`, and its failure is
  reported once through the error pipeline while the app starts without it.

  Either way the failure now travels as `DwPluginInitException`, which names the plugin and carries
  the cause, so the message says what happened wherever it is caught.

  **Breaking for a class that `implements DwFlutterPlugin`** rather than extending it: the new member has a
  default body, so `extends` inherits it and `implements` must declare it. `DwTelegramWebApp` was
  such a class and now extends instead — which is what a plugin base wants anyway, so the next
  member with a default does not break it either.

  Reaching for a plugin that failed no longer leaks a `LateInitializationError` from inside the
  package — further from the cause than the crash it replaced. `of<T>()` throws a `StateError`
  naming the plugin and the failure; `maybeOf<T>()`, which asks whether anybody holds a role,
  answers that nobody does, because a plugin that did not survive does not hold it.

## 0.7.0

**`DwRefusal`** — the one error that is an answer. It carries a `message` written for the user
("This message was already deleted"), and everything downstream treats it as a decision rather than
an incident:

- `dw.action` shows that message instead of the action's `onErrorNotification`. The rule's text was
  written for this case; the action's was written for every case.
- it still travels through `dw.handleError`, so an app's `DwFlutterConfig.onErrorReport` sees it and sorts
  it out with one type check. The core's built-in alerting does not raise it — see
  `dartway_serverpod_core_flutter` 0.11.0, where a server response marked `isRefusal` becomes one.
- an app can throw one from its own code for a local rule ("this file is larger than 10 MB") and get
  the same treatment.

## 0.6.0

**`dw.plugins.maybeOf<T>()`** — the lookup for a *role* rather than an integration. `of<T>()` is an
app reaching for something it connected, so absence is a wiring mistake and it throws; `maybeOf<T>()`
is the framework asking whether anybody took a job, where absence is an ordinary answer. Two plugins
claiming one role is not an ordinary answer and still throws, rather than quietly picking the first
and deciding something the app did not.

Added for the data layer, which now asks this way whether the app declared a local store for
`dw.repo` — see `dartway_serverpod_core_flutter` 0.10.0.

**The ambient-core errors say what is missing.** `Dw is not initialized` now names the core the app
failed to build and adds the part that costs people an afternoon: a widget test needs one too,
because a feature reaches `dw` while *building* — `dw.action(...)` is constructed in `build` — so
the subtree does not render without it, and the failure surfaces later as a finder that found
nothing. `Dw already initialized` says why an app's core initializer has to be idempotent: one core
per process, so a second test file booting it must be a no-op rather than an error.

## 0.5.1

**`dwBuildListAsync` builds its skeleton only when it is showing one.** The placeholder list — and
the assert that a placeholder is obtainable at all — used to be computed before `dwBuildAsync` was
even asked which branch to render, so `dw.getDefaultModel<T>()` ran on the data and error frames
too. In an app that is invisible, because `DefaultModels.initRepository()` runs at startup. In a
widget test it is a wall: a screen handed a ready `AsyncData<List<X>>([])`, with no loading state
anywhere in the test, still died on `UnimplementedError: Default Objects Repository doesn't contain
a model of type X` — a message naming neither the screen nor the test.

Both builders now delegate to one implementation that takes the placeholder as a factory and calls
it inside the loading branch, where the single-value `dwBuildAsync` already computed its own. The
public API is unchanged; a widget test of a list screen no longer has to stand up the default-model
registry unless it is genuinely testing the loading state.

## 0.5.0

**A plugin is handed the core it was plugged into.** `DwFlutterPlugin.init()` now takes one:
`Future<void> init(DwFlutterToolbox core)`. Until now it took nothing, and a plugin had no legal way to
reach the framework it was part of.

The gap was not theoretical. A plugin is constructed *as an argument* to the constructor that
assigns `dw` — that is what `plugins:` being a constructor parameter means — while the app declares
`late final DwCore<Client, UserProfile> dw`. So anything a plugin needs from the core has to be
passed in at declaration time, and the ambient instance is not assigned yet. Writing the obvious
thing inside the list:

```dart
plugins: [DwPush(config: DwPushConfig(
  recipientIdProvider: dw.userProfileProvider.select((p) => p?.id),  // throws at startup
))],
```

compiles silently and fails with `LateInitializationError` before the first frame. `dw` is also not
exported by the framework — neither `dartway_flutter` nor `dartway_serverpod_core_flutter` hands the
singleton out — so there was no version of that line that worked, only versions that looked like they
might. `dartway_push_flutter`'s own README shipped one.

`init` is the first moment the core exists, so that is where it arrives. The argument is a
`DwFlutterToolbox`; an app on the data layer passes a `DwCore`, which is one — a plugin that needs the data
layer names it and casts, and thereby says out loud that it does not work on the plain toolbox.

**Breaking, mechanically.** Every `DwFlutterPlugin` implementation adds the parameter; nothing else about a
plugin changes, and a plugin with no use for the core ignores it. `DwPluginRegistry.initAll()` takes the core
too, and `dw.init()` passes itself.

## 0.4.0

**A feature can be found by pointing at it.** `DwFeatureWidget.hitTest(globalPosition)` answers what is
declared at a point on screen — the other half of `scanMounted`, which answers what is declared on
the screen at all. Studio's tap-to-inspect is the first caller: pick a spot in the live preview, get
that feature's passport, with no id to look up and no map to keep in your head.

The innermost declaration wins. A card and the "more actions" row inside it both cover the tap, and
the row is what the finger landed on — so the walk goes depth-first and takes the last match, not
the first.

A feature is matched on the area it actually **paints** into, not the one it lays out in. The two
differ more often than they sound like they would: a subtree under a `Transform.scale` draws
smaller than it measures, and a list item scrolled past the edge of its viewport keeps its layout
position while painting nothing at all — and being deeper in the tree, it would have won over the
feature you can see. Both are cut out by transforming through to the root and intersecting with
every ancestor clip.

Same rule as `scanMounted` for subtrees Flutter parks out of sight (offstage, invisible, disabled
ticker) — being mounted is not being on screen, and now neither is being laid out.

## 0.3.0

**A feature can say what is wrong with it.** `DwFeatureSpec` gains `knownIssues` — a setting nothing
reads, a screen still wired to mock data, a sort order commented out while the field feeding it
stayed in the form. `hasKnownIssues` answers the catalog's question without every caller repeating
`.isNotEmpty`.

The line against `implementationNotes` is what the reader is meant to do about the entry: a note
says "this is deliberate, leave it", an issue says "this is not right, fix it". An agent editing the
feature has to tell them apart before it touches anything, and prose in one list could not. The
test: if someone fixed it, would the entry disappear?

Additive — the field defaults to empty, so existing specs compile unchanged.

## 0.2.0

**A feature now describes itself, and the description lives next to the code.** `DwFeatureSpec`
used to carry a single `description`, which is why every project that wanted more grew a second
description somewhere else — a doc page, a table in a tool — and then had two that disagreed. The
spec now carries the whole thing:

- `purpose` — why the feature exists for the user. Optional on purpose: a card or a row usually
  has no purpose of its own, it belongs to the screen it serves, and repeating the screen's
  purpose on each of its parts is noise.
- `behaviors` — what it observably does, one checkable statement per entry. The rule that keeps
  the field alive is in its doc comment: every entry must be verifiable by looking at the running
  app. The moment "works nicely with long titles" appears, the field has turned back into prose.
- `requirements` — what it must honour, imposed from outside it.
- `implementationNotes` — decisions a reader would otherwise re-open; written for the team, not
  for the client.

**Breaking:** `description` is gone. It sat between `title` and `behaviors` with nothing left to
say, and that is exactly what made feature descriptions shallow.

The registry enum is gone with it. A spec belongs in the file of the feature it describes — a
central catalog of every feature in the app is a file nobody reads that lives far from the code it
claims to describe. What the enum did give was enumerability, and a running app cannot replace it:
Dart has no reflection, so `DwFeatureWidget.scanMounted()` sees only what is on screen. A whole-project
catalog is a job for static analysis of the sources.

## 0.1.0

First public release — the Flutter skeleton of a DartWay app: everything an app needs before and
around its data layer.

**App bootstrap.** `DwAppRunner` owns what every app sets up and no app enjoys setting up: the
`ProviderScope`, the native splash, async initializers, and a zone that routes uncaught errors into
the error pipeline instead of losing them.

**The async-UI contract.** `dwBuildAsync` / `dwBuildListAsync` render loading, error and data
uniformly — and the loading state is a skeleton derived from your real widget, not a spinner.

**Guarded actions.** `dw.action(...)` builds a `DwUiAction` that describes *what* an action does —
confirmation (`DwUiConfirmation`), success notification, follow-up, error reporting — and
`DwActionBuilder` binds it to *any* tappable widget and handles the rest: no re-entrant taps (a
double tap does not book twice), an in-flight flag, optional `Form` validation. The guard is not
welded to a button, so a list tile or an icon gets it too.

**Notifications.** A global overlay pipeline: post a `DwUiNotification` from anywhere
(`dw.notify.success(...)`), render it with your own handler.

**Error reporting with context.** Every error carries an app-state snapshot — route, mounted
features, the action label, platform, version — through a single `DwFlutterConfig.onErrorReport` hook (and
an overridable `dispatchReport`). A minified web stack trace tells you nothing; this tells you what the
user was doing.

**Feature declarations.** `DwFeatureWidget` / `DwFeatureWidget.scanMounted`: mark widgets as product features and
discover the mounted ones at runtime — for feature catalogs, analytics, error context and
[DartWay Studio](https://dartway.dev) passports.

**Plugins.** `DwFlutterPlugin` is the seam for integrations the framework must not know about: declare one
at startup and reach it as `dw.plugins.<name>` — the open namespace for what a project plugs in, kept
apart from the core's own services. Telegram lives in
[`dartway_telegram`](https://pub.dev/packages/dartway_telegram) (`dw.plugins.telegram`), local
storage in [`dartway_shared_preferences`](https://pub.dev/packages/dartway_shared_preferences)
(`dw.plugins.prefs`) — an app that needs neither never downloads them.

**It ships no design system.** There is no `DwButton`, no `DwText`, no theme and no style presets —
on purpose. A design system is the one thing every serious app ends up owning, and shipping it as a
dependency only starts an argument about the corner radius of your button. `dartway create`
scaffolds a UI kit **into your app** as source you own. What this package keeps is the mechanism you
should not have to reinvent.

Riverpod-native by design: `AsyncValue` is the type the whole async-UI contract is built on. That is
not an implementation detail you can swap — it is the framework.
