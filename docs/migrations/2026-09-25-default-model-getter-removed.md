---
title: "DwFlutterConfig.defaultModelGetter, isDefaultModelsGetterSetUp, getDefaultModel and DwFlutterToolbox.hasCustomErrorHandling are gone"
affects:
  dartway_core_flutter: "0.21.0-dev.6"
---

## Who is affected

A project that configures `DwFlutterConfig(defaultModelGetter: ...)`, calls
`dw.isDefaultModelsGetterSetUp` / `dw.getDefaultModel<T>()` directly, or reads
`dw.hasCustomErrorHandling`. No live project on the rewrite does any of these.

## What changed

`dwBuildAsync` and `dwBuildListAsync` fell back to a project-wide model registry
(`defaultModelGetter`) to build a skeleton's placeholder when the caller passed no `loadingValue` /
`loadingItem`. Nothing published to it: it asked for the value through a getter with no way to know
which type would be requested next, which is why every real skeleton was already built from an
explicit `loadingValue` / `loadingItem` instead.

Passing neither now renders nothing while loading (`SizedBox.shrink()`) — exactly what the registry
path already did whenever it had no placeholder for the type, so nothing observable changes for a
project that never set `defaultModelGetter`.

`DwFlutterToolbox.hasCustomErrorHandling` (`true` when `DwFlutterConfig.onErrorReport` is set) had
no caller anywhere on the rewrite either, and nothing in the framework itself ever read it — it is
removed alongside the registry it sat next to.

## What to change

Remove `defaultModelGetter` from `DwFlutterConfig(...)`, and pass an explicit `loadingValue` /
`loadingItem` to any `dwBuildAsync` / `dwBuildListAsync` call that relied on the registry for its
skeleton. A project reading `dw.hasCustomErrorHandling` inlines the same check:
`dw.config.onErrorReport != null`.
