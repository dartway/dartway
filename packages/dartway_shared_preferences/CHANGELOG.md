# Changelog

## 0.4.0

- **`providerFamily(keyFor:, defaultValue:)` and `mappedProviderFamily(keyFor:, mapFrom:, mapTo:)`
  — a stored value whose key comes from an entity.** `provider`/`mappedProvider` take a constant
  key, so state that belongs to a project, a chat or a section had nowhere to go: they cannot be
  called per id, and the class doc says why — a second call with the same key builds a *second*
  provider, and the two are blind to each other's writes.

  The family is exactly the answer to that warning. Riverpod holds one provider per argument value,
  so `family(id)` resolved in one widget and `family(id)` resolved in another are the same state.
  Declare the family as the top-level `final`; calling it with an argument inside `build` is the
  intended use. `DwPrefProviderFamily<T, Arg>` and `DwMappedPrefProviderFamily<T, Arg>` name the
  return types, so a consumer still imports nothing but this package — and here that matters more
  than before: the underlying `NotifierProviderFamily` is not even exported from
  `flutter_riverpod.dart`, it lives in `flutter_riverpod/misc.dart`.

  What this replaces, twice over on one real project: a store class with injected read/write over
  `dw.plugins.prefs.raw`, plus a `StatefulWidget` reading in `initState`, re-reading in
  `didUpdateWidget` when the entity changed, and writing back on every change. The thirty lines were
  not the cost — the lost reactivity was. A pair of functions has no subscribers, so the value lived
  in one widget's `State` and every second reader had to be handed it through a constructor.

  Both forms ship together on purpose: `provider` and `mappedProvider` are documented as a pair, and
  a family for only one of them is a splinter somebody has to ask about.

- The `dartway-data-layer` skill gains a section on local screen state, which said nothing about
  `dw.plugins.prefs` before. Two questions draw the border: does the value survive a restart (no — an
  ordinary `Notifier`; yes — this plugin), and does it belong to an entity (yes — a family with the
  key built from the argument; no — a constant key). Without a rule the choice was made by copying
  the neighbouring file, which is how one app ends up storing the same kind of thing three ways.

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
