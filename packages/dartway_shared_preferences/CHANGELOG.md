# Changelog

## 0.6.1

- Fixed: `provider`, `mappedProvider`, `providerFamily` and `mappedProviderFamily` no longer bind to
  the `DwSharedPreferences` instance they were called on. The store is now resolved when the
  notifier is created — per `ProviderContainer`, from whichever plugin most recently finished
  `init()` — so a top-level `final` provider is safe across as many `DwFlutterToolbox`s as run in
  the isolate, such as one new core per widget test file. Previously the first core to touch the
  provider bound it forever, and every later core silently read and wrote through that first core's
  stale store instead of its own (dartway/dartway#363). Reading a provider before any plugin has
  finished `init()` now throws `StateError` naming the cause, instead of `LateInitializationError`.

## 0.6.0

- This package now targets the rewritten DartWay framework: `dartway_flutter` is now `dartway_core_flutter` `^0.20.0`, and the two-word renames that came with it (`DwFlutter` → `DwFlutterToolbox`, `DwConfig` → `DwFlutterConfig`, `DwPlugin` → `DwFlutterPlugin`, `DwPlugins` → `DwPluginRegistry`). Nothing else changed — the previously published `0.5.0` (on `dartway_flutter` `^0.8.0`) is otherwise identical.
