# Changelog

## 0.21.0-dev.15

- **BREAKING: one way to show a read — `DwReadBuilder` — and a paged list, `DwPagedListView`**
  (dartway/dartway#390, D-116). `DwReadBuilder(read, builder:, placeholder:, onRefused:)` takes
  any read (`dw.request`, `dw.table`, `dw.pages`, `dw.window` — a `DwWatchProvider<T>`) and renders
  loading (a skeleton of `builder` over `placeholder`, or the app's loading view), a branch per
  refusal code (`onRefused: {DwCoreRefusal.notFound: (context, refusal) => …}`), the app's failed
  view with a retry that refetches, nothing for a signed-out read, and data. A failure is reported
  to the error pipeline once per failure, not on every rebuild; a refusal and an unreachable server
  are not reported. `DwReadBuilder.derived(provider, retry: (ref) => …)` renders any provider of
  an `AsyncValue` derived from reads the same way, with the retry it names.
  `DwPagedListView(request:, itemBuilder:, emptyBuilder:)` shows a `DwPageRequest` feed and asks
  for the next page — of the request the list holds when the call runs — when the slot after the
  last row is built, as the end comes into the cache extent; the slot shows the app's
  `readLoadingBuilder` while a page loads and a retry after a failed one; a page with no rows while
  more follow keeps loading rather than showing empty; `header`, `placeholder`/`placeholderCount`,
  `onRefused`, `edgeBuilder`, `controller`, `padding`. `DwPagedListView.sliver` is the same list as
  a sliver for a page's own `CustomScrollView`.
- **BREAKING: `DwFlutterConfig.readLoadingBuilder` and `readFailedBuilder`**, required by
  `DwFlutterCore` (an `ArgumentError` naming them otherwise): the app's loading and failed views,
  supplied once from its kit and shown by `DwReadBuilder`, `DwPagedListView` and `DwWindowListView`.
- **BREAKING: `dwBuildAsync` and `dwBuildListAsync` are removed** — their silent default on error
  is what three projects each patched with an extension of their own. `DwReadBuilder` replaces
  both.
- **BREAKING: `DwWindowListView` loses `loadingBuilder` and `errorBuilder`** — its first answer is
  shown as `DwReadBuilder` shows a read, with an `onRefused` of its own — and **`emptyBuilder` is
  required**, as it is on `DwPagedListView`: an empty list says what empty means. Its edge slots
  show the app's `readLoadingBuilder` while loading; the framework draws no spinner of its own.
- **`DwWatchNotifier<S>`** — the public base of the four read notifiers (`refetch()`, `isLive`) —
  and **`DwWatchProvider<S>`**, what `DwReadBuilder` takes. **`DwRefusedBuilder`**, the type of an
  `onRefused` branch.

## 0.21.0-dev.14

- Nothing changed here; the family moves in lockstep to deliver the migration note for the new
  state and command checks of `dartway check` (dartway/dartway#389).

## 0.21.0-dev.13

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#388).

## 0.21.0-dev.12

- Nothing changed here; the family moves in lockstep with `dartway_orm` (dartway/dartway#384).

## 0.21.0-dev.11

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#387).

## 0.21.0-dev.10

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#386).

## 0.21.0-dev.9

- Nothing changed here; the family moves in lockstep with `dartway_core_server` and
  `dartway_client` (dartway/dartway#385). An app on `dartway_core_flutter` sends its UTC offset with
  every call through the client.

## 0.21.0-dev.8

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (dartway/dartway#355, #356).

## 0.21.0-dev.7

- **Requires `dartway_router` 3.0.0** (#314), where a simple route's `extraPathSegment`
  replaces its name in the URL instead of doubling it, and every descendant of such a route
  moves with it. No code change here: this package only re-exports `dartway_router`, but it
  now resolves a router that builds different URLs for any project using `extraPathSegment`
  on a `.simple()` route — the family moves in lockstep for the same reason it did for the
  router's previous breaking change (#302).

## 0.21.0-dev.6

- **BREAKING: `DwFlutterConfig.defaultModelGetter`, `isDefaultModelsGetterSetUp`,
  `getDefaultModel` and `DwFlutterToolbox.hasCustomErrorHandling` are gone.**
  `dwBuildAsync`/`dwBuildListAsync` with no `loadingValue`/`loadingItem` render nothing while
  loading (`SizedBox.shrink()`) instead of asking a project-wide model registry that no live
  project configured; `hasCustomErrorHandling` had no caller either. Migration note:
  `docs/migrations/2026-09-25-default-model-getter-removed.md`.

## 0.21.0-dev.5

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

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

The rewrite (see docs/1.0/DECISIONS.md).

- **`dw.deleteAccount()`** (D-072).

- **A list with no loading placeholder loads as nothing, not as an error.** `dwBuildListAsync` without `loadingItem` in an app whose `defaultModelGetter` is unset (or does not know the model) failed an assert in debug and threw in release, showing an error block until the data came; it now renders nothing while loading, as `dwBuildAsync` does. A skeleton is still built whenever a placeholder exists.

- **No run-time dependency on `flutter_native_splash`** (#268). The splash is held with the binding's `deferFirstFrame` and released after bootstrap; on the web a shell's `removeSplashFromWeb()` is still called when it defines one. The generator's `image`, `archive`, `xml`, `html` and their dependencies leave every app's graph. An app that runs `dart run flutter_native_splash:create` lists the package in its own `dev_dependencies`, as the template now does.

- **BREAKING: `DwErrorReport.actionLabel` is `label`**, and `dw.handleError(label:)` takes it for any source (#126).

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
