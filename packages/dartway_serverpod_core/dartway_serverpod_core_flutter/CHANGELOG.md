# Changelog

## Unreleased

**`dw.repo` — one client-side data-access point.** Reads are Riverpod providers consumed natively —
`ref.watch(dw.repo.model<T>(...))` (reactive), `ref.read(...future)` (one-shot),
`ref.refresh(...future)` (force). Writes and realtime are plain methods: `dw.repo.saveModel/deleteModel`,
`dw.repo.addUpdatesListener/removeUpdatesListener`; default-model registration moved here too
(`dw.repo.setupRepository/mockModelId/getDefault`).

- `dw.repo.model<T>(...)` resolves to a non-null `T` (StateError when absent); `maybeModel<T>` is the
  nullable view; `modelList<T>` is the backend-filtered list. No app code names a provider type or
  touches `.notifier` — the whole Riverpod surface an app uses is `ref.watch/read/refresh(dw.repo.<x>)`.
- Local (frontend) list filtering is no longer a framework feature — do it with a plain `.where` in the
  widget; `backendFilter` still narrows the query server-side.
- Added alongside the existing `DwRepository` statics and `ref.watchModel*` extensions (additive); those
  are being migrated away and will be removed once call sites move to `dw.repo`.

## 0.1.0

First public release — the Flutter half of the DartWay core.

**A typed realtime data layer.** `ref.watchModelList<T>()` returns a live `AsyncValue<List<T>>`:
realtime sync, pagination, declarative backend filters and skeleton loading states out of the box.
`ref.watchModel` / `ref.readModel` read a single one; `DwRepository.saveModel` /
`DwRepository.deleteModel` write. No repositories, no services, no sockets, no cache invalidation.

**Sessions** on the app's own user model, surviving restarts through the authentication key manager.

**Connection-aware error handling.** A network blip becomes a toast, a real failure becomes a
report — `dwReportingOnFailedCall` and the streaming error classifier tell them apart, so a subway
tunnel does not page you at 3am.

**Context-rich alerting, zero-config.** Every error carries the app's state at the moment it broke:
the route, the features mounted on the screen, the action the user tapped or the `endpoint.method`
that failed, the platform, the app version and the user — instead of a minified web stack trace.

Re-exports [`dartway_flutter`](https://pub.dev/packages/dartway_flutter), so one import covers the
standard app surface.
