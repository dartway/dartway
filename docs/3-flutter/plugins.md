# How does an app add something the framework knows nothing about?

Every app eventually needs an integration the framework has no business knowing: local storage,
Telegram, a vendor SDK someone signed a contract for. The usual answer is a field on the framework's
config — `DwConfig(telegram: ...)` — and from that moment every app carries the vendor's dependency,
including the ones that will never open Telegram.

DartWay does not do that. The framework knows what a **plugin** is; it never knows what any
particular one *does*. `dartway_flutter` contains no mention of Telegram or of `shared_preferences` —
only [`DwPlugin`](https://github.com/dartway/dartway/blob/master/packages/dartway_flutter/lib/src/core/logic/dw_plugin.dart),
an interface with a single `init()`.

The consequences are the whole point:

- `DwConfig` never grows a field named after a vendor;
- an app that does not use an integration does not download it;
- an integration can be released, versioned and broken on its own schedule, without a framework
  release.

## Three steps, and the third is the interesting one

**1. Add the package.** Plugins live on pub.dev like anything else:

```bash
dart pub add dartway_shared_preferences
```

**2. Declare it once, where the core is built.** In a generated project that is
`lib/core/dw_core.dart`, next to `config:` and `client:`:

```dart
dw = DwCore<Client, UserProfile>(
  config: DwConfig(/* ... */),
  client: Client(backendUrl),
  plugins: [DwSharedPreferences()],
  // ...
);
```

`plugins` is declared on `DwFlutter` and passed straight through by `DwCore`, so an app on the plain
Flutter toolbox writes `DwFlutter(config: ..., plugins: [...])` and nothing else changes.

**3. Reach it as `dw.plugins.<name>`:**

```dart
final darkModeProvider = dw.plugins.prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);
```

That accessor is **not** in the framework. It is an extension declared in the plugin's own package:

```dart
// inside dartway_shared_preferences, not inside dartway_flutter
extension DwPrefsAccess on DwPlugins {
  DwSharedPreferences get prefs => of<DwSharedPreferences>();
}
```

So `dw.plugins.prefs` exists only for apps that chose that package — the ergonomics of an ambient
service with none of the coupling. `dw.` is the framework's closed, known core; `dw.plugins.` is the
open set a project plugs in.

**The extension has to be imported** in every file that reads it. When that gets noisy, re-export the
plugin from the file where the app declares `dw`, the way a UI kit's root file re-exports
`dartway_flutter`:

```dart
// lib/core/dw_core.dart
export 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
```

The failure is worth recognising in advance, because the analyzer does not describe it: with the
import missing you are told *"the getter `prefs` isn't defined for the type `DwPlugins`"* — a getter
that is perfectly fine.

## When a plugin is initialized

`dw.init()` runs `init()` on every declared plugin, awaited, in declaration order — and a project
built by `dartway create` already calls it from the bootstrapper:

```dart
DwAppRunner(
  appInitializers: [
    () => dw.initDwCore(initRepositoryFunction: DefaultModels.initRepository),
  ],
  child: const _AppMaterialApp(),
).run();
```

`initDwCore` awaits `super.init()` first, so plugins are ready before the data layer is, and both are
ready before the first frame. A plugin that throws during `init()` surfaces on `DwAppRunner`'s error
screen rather than half-booting the app.

Declare a plugin and forget it, and the failure is loud and immediate: `dw.plugins.of<T>()` throws a
`StateError` naming the type that was never registered. It cannot silently return null.

## Distribution: pub.dev, and nothing else

**Plugins ship on pub.dev, versioned independently of the core.** Not as a git ref, not as a path
dependency. An app adds a normal caret constraint and resolves like any other Dart project.

Path and git dependencies look like a shortcut when the plugin and the app happen to sit on one
machine, and they cost more than they save:

- a `path:` dependency resolves only in the tree that wrote it. For everybody else — CI included —
  the app does not resolve at all;
- the usual patch is `dependency_overrides`, which is not a patch. An override is **global to the
  resolution** and silently outranks every constraint in the graph, including the ones the framework
  states deliberately. It is a debugging tool for working on the framework itself, not a way to
  consume it;
- a git ref pins a moving branch, so two checkouts of the same app can build different code.

Each plugin states its compatibility with a caret on the framework — `dartway_flutter: ^0.4.0`. So a
breaking release of `dartway_flutter` is followed by a release of each plugin, and pub refuses the
combinations that were never tested instead of failing at runtime.

## What exists today

| Package | Reached as | What it is |
|---|---|---|
| [`dartway_shared_preferences`](https://pub.dev/packages/dartway_shared_preferences) | `dw.plugins.prefs` | Reactive riverpod providers over local storage |
| [`dartway_telegram`](https://pub.dev/packages/dartway_telegram) | `dw.plugins.telegram` | Telegram Mini App: viewport, safe-area insets, Telegram user id |
| [`dartway_push_flutter`](https://pub.dev/packages/dartway_push_flutter) | `dw.plugins.push` | [Push notifications](push-notifications.md): permissions, token lifecycle, taps — with the transport itself in a package of its own |

`dartway_telegram` shows the other half of what a plugin buys you: `DwTelegramWebApp.create()`
returns the real bridge on web and an inert stub on mobile and desktop, and outside Telegram every
getter answers as if Telegram were absent instead of throwing. One declaration, every platform still
builds.

Push shows the pattern taken one step further: `dartway_push_flutter` is the
plugin, and the vendor SDKs sit behind it in `dartway_push_firebase` and
`dartway_push_rustore`, so an app that ships only to the App Store never
downloads a Russian store's SDK, and an app that ships only to RuStore never
downloads Firebase. The server side of push is something else again — a Serverpod
module with its own tables, wired on the server rather than declared in
`plugins:`. See [push on the device](push-notifications.md) and
[push delivery](../4-server/push-delivery.md).

## Writing your own

A plugin is one class and one extension, in your own package:

```dart
class MyAnalytics extends DwPlugin {
  @override
  Future<void> init() async {
    // runs during dw.init(), before the first frame
  }

  void track(String event) {/* ... */}
}

extension MyAnalyticsAccess on DwPlugins {
  MyAnalytics get analytics => of<MyAnalytics>();
}
```

Two rules keep it a plugin rather than a fork:

- **the accessor lives in your package.** Adding a getter to `DwPlugins` inside the framework would
  put your vendor's name in everybody's core — which is the thing this whole mechanism exists to
  prevent;
- **name it for the capability, not the vendor** when there is a plausible second implementation.
  `dw.plugins.prefs` reads as storage; `dw.plugins.telegram` is honest about being one specific
  product, and that is exactly why it is not called `dw.plugins.chat`.

A plugin that is only ever used by one app does not need to be published — but it does need to be a
package, not a folder inside the app, the moment a second app wants it.
