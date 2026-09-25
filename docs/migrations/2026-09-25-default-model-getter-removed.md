---
title: "DwFlutterConfig.defaultModelGetter, isDefaultModelsGetterSetUp and getDefaultModel are gone"
affects:
  dartway_core_flutter: "0.21.0-dev.6"
---

## Who is affected

A project that configures `DwFlutterConfig(defaultModelGetter: ...)`, or calls
`dw.isDefaultModelsGetterSetUp` / `dw.getDefaultModel<T>()` directly. No live project on the
rewrite does either.

## What changed

`dwBuildAsync` and `dwBuildListAsync` fell back to a project-wide model registry
(`defaultModelGetter`) to build a skeleton's placeholder when the caller passed no `loadingValue` /
`loadingItem`. Nothing published to it: it asked for the value through a getter with no way to know
which type would be requested next, which is why every real skeleton was already built from an
explicit `loadingValue` / `loadingItem` instead.

Passing neither now renders nothing while loading (`SizedBox.shrink()`) — exactly what the registry
path already did whenever it had no placeholder for the type, so nothing observable changes for a
project that never set `defaultModelGetter`.

## What to change

Remove `defaultModelGetter` from `DwFlutterConfig(...)`, and pass an explicit `loadingValue` /
`loadingItem` to any `dwBuildAsync` / `dwBuildListAsync` call that relied on the registry for its
skeleton.
