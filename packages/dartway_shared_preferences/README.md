# dartway_shared_preferences

The shared-preferences plugin for [DartWay](https://dartway.dev): typed riverpod providers over local
storage, reached as `dw.plugins.prefs`.

Optional by design. The core (`dartway_flutter`) carries no dependency an app might not need — local
storage is a plugin, like any other integration. An app that needs it declares the plugin; one that
doesn't never downloads `shared_preferences`.

## Use

```dart
DwFlutter(
  config: DwConfig(/* ... */),
  plugins: [DwSharedPreferences()],
);
```

The plugin loads `SharedPreferences` during `dw.init()`. After that — **define each
provider once, as a top-level `final`**, like any riverpod provider:

```dart
// A reactive value — the UI watches a preference like any other provider.
final DwPrefProvider<bool> darkModeProvider = dw.plugins.prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);

// Enums / custom types stored as a String.
final DwMappedPrefProvider<AppThemeMode> themeProvider =
    dw.plugins.prefs.mappedProvider<AppThemeMode>(
      key: 'theme',
      mapFrom: (raw) => AppThemeMode.values.byName(raw ?? 'system'),
      mapTo: (mode) => mode.name,
    );

// One-off imperative access.
final token = dw.plugins.prefs.raw.getString('token');
```

**Write the type out.** `DwPrefProvider<T>` and `DwMappedPrefProvider<T>` come from this package, so
the file needs no other import — that is what they are for. Leave the type to inference and the
declaration only compiles where riverpod happens to be imported, which a file that just wants to
remember a setting has no reason to do. And it does not fail helpfully: the analyzer says *"the
getter `prefs` isn't defined for the type `DwPlugins`"*, pointing at a getter that is perfectly fine,
while `unused_import` suggests removing the very import that fixes it.

**The extension has to be in scope.** `dw.plugins.prefs` is declared here, so every file reading it
imports this package. If that gets noisy, re-export the package from wherever the app declares `dw`
— the same way a UI kit's root file re-exports `dartway_flutter`:

```dart
// lib/core/dw_core.dart
export 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
```

Update through the notifier:

```dart
ref.read(darkModeProvider.notifier).update(true);
```

`provider` stores natively — `String`, `bool`, `int`, `double`, `List<String>`. Any other type
compiles but throws `UnsupportedError` on the first write; reach for `mappedProvider` (enums, custom
types) or `raw` instead.

## Why a plugin

`dw.` is the framework's closed core; `dw.plugins.` is what a project plugs in. Preferences live
under `dw.plugins.prefs` for the same reason Telegram lives under `dw.plugins.telegram`: the core
stays a minimal contract, and you pay only for what you use. See
[`docs/DESIGN.md`](https://github.com/dartway/dartway/blob/master/docs/DESIGN.md).
