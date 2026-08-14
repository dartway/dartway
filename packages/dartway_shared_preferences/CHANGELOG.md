# Changelog

## 0.3.0

Follows `dartway_flutter` 0.5.0, where `DwPlugin.init()` gained the core as an argument:
`DwSharedPreferences.init(DwFlutter core)`. Local storage needs nothing from the core — the parameter
is the plugin contract, and behaviour is unchanged. An app that declares the plugin and reads
`dw.plugins.prefs` never sees the difference.

## 0.2.0

- **`DwPrefProvider<T>` and `DwMappedPrefProvider<T>` — the plugin names its own return types**, so a
  consumer needs nothing but this package. Before, `provider(...)` returned
  `NotifierProvider<PrefNotifier<T>, T>`: nameable only in a library that imports riverpod, which a
  file that just wants to remember a setting has no other reason to do. The README's own example did
  not compile in the file it told you to put it in.

  The failure was the expensive part, not the fix. Leaving the type to inference in a library without
  riverpod makes the analyzer report *"the getter `prefs` isn't defined for the type `DwPlugins`"* —
  a getter that is perfectly fine — while `unused_import` simultaneously suggests removing the import
  that fixes it. Found on a real project, and it cost three analyzer runs to stop believing the error
  message.

  A test now holds the line: `consumer_needs_only_this_package_test.dart` imports this package and
  nothing else, and declares both kinds of provider as top-level finals. It asserts almost nothing at
  runtime — the point is that it compiles.

- The README says to write the type out, and shows the re-export trick for the extension itself
  (`dw.plugins.prefs` is declared here, so every file reading it imports this package — an app that
  finds that noisy re-exports the package from wherever it declares `dw`).

## 0.1.1

Moves to `dartway_flutter` 0.2.0 (breaking `DwFeatureSpec`), so the two resolve together.

## 0.1.0

First public release — the shared-preferences plugin for DartWay.

Declare `DwSharedPreferences()` at startup and reach it as `dw.plugins.prefs`: a reactive
wrapper over `SharedPreferences` with typed riverpod providers
(`dw.plugins.prefs.provider(key:, defaultValue:)` and `mappedProvider(...)` for enums/custom types)
plus direct imperative access (`dw.plugins.prefs.raw`). Optional by design — an app that needs no
local storage never depends on it, and `dartway_flutter` knows nothing about it.
