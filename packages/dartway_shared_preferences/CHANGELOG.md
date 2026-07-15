# Changelog

## 0.1.0

First public release — the shared-preferences plugin for DartWay.

Declare `DwSharedPreferencesPlugin()` at startup and reach it as `dw.plugins.prefs`: a reactive
wrapper over `SharedPreferences` with typed riverpod providers
(`dw.plugins.prefs.provider(key:, defaultValue:)` and `mappedProvider(...)` for enums/custom types)
plus direct imperative access (`dw.plugins.prefs.raw`). Optional by design — an app that needs no
local storage never depends on it, and `dartway_flutter` knows nothing about it.
