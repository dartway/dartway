# Changelog

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
