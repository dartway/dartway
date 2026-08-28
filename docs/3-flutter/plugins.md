# How does an app add something the framework knows nothing about?

Every app eventually needs an integration the framework has no business knowing: local storage,
Telegram, a vendor SDK someone signed a contract for. The usual answer is a field on the framework's
config — `DwConfig(telegram: ...)` — and from that moment every app carries the vendor's dependency,
including the ones that will never open Telegram.

DartWay does not do that. The framework knows what a **plugin** is; it never knows what any
particular one *does*. `dartway_flutter` contains no mention of Telegram or of `shared_preferences` —
only [`DwPlugin`](https://github.com/dartway/dartway/blob/master/packages/dartway_flutter/lib/src/core/logic/dw_plugin.dart),
an interface with a single `init(core)`.

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

`dw.init()` runs `init(core)` on every declared plugin, awaited, in declaration order — and a project
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

### What a failing plugin costs — `blocksStartup`

**By default, everything: the app does not start.** `DwPlugin.blocksStartup` is `true` unless a plugin
says otherwise, because a plugin an app declared is one it expects to have, and an app running
without it is an app whose features fail one by one, later and further from the cause.

Starting anyway is a decision, and it is made by the plugin that knows whether it is load-bearing:

```dart
class MyAnalytics extends DwPlugin {
  // Its absence costs analytics and nothing else.
  @override
  bool get blocksStartup => false;

  @override
  Future<void> init(DwFlutter core) async { ... }
}
```

A non-blocking failure is reported once through the error pipeline and the remaining plugins run.
**Declaration order used to decide this silently:** the list ran bare, so a single `init` that threw
aborted `dw.init()` and every plugin after it never ran — an optional integration listed first could
take down an app that would have run perfectly without it. That is not something an app author
weighs while writing `plugins: [...]`.

Either way the failure now travels as `DwPluginInitException`, naming the plugin and carrying the
cause, so a report says which plugin failed rather than showing a raw exception from inside a
third-party package.

Reaching for a plugin that failed says so. `of<T>()` throws a `StateError` naming the plugin and the
failure — not a `LateInitializationError` from inside the package, which is what a swallowed error
would have produced, further from the cause than the crash it replaced. `maybeOf<T>()` asks whether
anybody holds a role, and a plugin that did not survive does not hold it, so it answers `null`.

Declare a plugin and forget it, and the failure is loud and immediate: `dw.plugins.of<T>()` throws a
`StateError` naming the type that was never registered. It cannot silently return null.

### `init` is handed the core, and that is not a convenience

A plugin cannot read `dw` while it is being declared. Look at where the declaration sits:

```dart
late final DwCore<Client, UserProfile> dw;   // the app's own variable

dw = DwCore<Client, UserProfile>(
  plugins: [MyPlugin()],                     // built as an argument to the constructor
);                                           // that assigns dw — dw is not assigned yet
```

`plugins:` is a constructor parameter, so every plugin is constructed *before* the variable it will
be reached through exists. Anything that touches `dw` inside that list throws
`LateInitializationError` before the first frame — and the analyzer says nothing, because `late
final` is exactly the promise that it will be there by the time anyone reads it. The framework does
not export the singleton either, so there is no back door: `dw` is the app's variable, not ours.

Hence the argument. `init` is the first moment the core exists, and it arrives rather than being
looked up:

```dart
class MyPlugin extends DwPlugin {
  ProviderListenable<int?>? _userId;

  @override
  Future<void> init(DwFlutter core) async {
    // A plugin that needs the data layer names DwCore and casts. The cast is the
    // honest part: it says out loud that this plugin does not work on the plain
    // Flutter toolbox, and fails at startup rather than at the first read.
    final dwCore = core as DwCore<Client, UserProfile>;
    _userId = dwCore.userProfileProvider.select((profile) => profile?.id);
  }
}
```

The parameter is a `DwFlutter` because that is what declares `plugins:`. An app on the data layer
passes a `DwCore`, which *is* a `DwFlutter` — so a plugin that needs nothing from the core (most of
them) ignores the argument and works on both.

What a plugin must **not** do is keep the core and read it during `init` for something the app has not
finished setting up. Session state is the usual example: at `init` time nobody is signed in yet.
Capture the provider, watch it from the widget tree, and react — do not read a value.

## A role the framework asks for: `DwKeyValueStorePlugin`

Most plugins are an app reaching for its own integration. A few are the other way round — the
framework needs a **job done** and has no opinion about who does it. Those are declared as an
abstract role in the framework and claimed by whatever plugin an app declares:

| role | who asks | what happens without one |
|---|---|---|
| `DwRepoLocalStorePlugin` | `dw.repo` | reads and writes stay network-only |
| `DwKeyValueStorePlugin` | the auth key manager | a signed-in session cannot survive a reload, and the manager says so |

`DwKeyValueStorePlugin` is a handful of key-value methods plus `isPersistent`. `DwSharedPreferences`
claims it; an app that keeps its key somewhere of its own writes its own plugin, or hands
`DwAuthenticationKeyManager` a store directly.

**This replaced a second copy.** The core used to reach for `shared_preferences` itself, in its own
`SharedPreferenceStorage`, while the plugin implemented the same job a package away — two
implementations that agreed only because they happened to sit on the same store. A decision taken on
one side could not be seen from the other, and a browser with no local storage broke both,
separately. One implementation, named through a role, is what the role is for.

The framework asks with `maybeOf`, so absence is an ordinary answer to the question rather than a
crash — the key manager turns it into a message naming the plugin to declare, at the moment
something actually needs the key.

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

Each plugin states its compatibility with a caret on the framework — `dartway_flutter: ^0.5.0`. So a
breaking release of `dartway_flutter` is followed by a release of each plugin, and pub refuses the
combinations that were never tested instead of failing at runtime.

## What exists today

| Package | Reached as | What it is |
|---|---|---|
| [`dartway_shared_preferences`](https://pub.dev/packages/dartway_shared_preferences) | `dw.plugins.prefs` | Reactive riverpod providers over local storage; claims `DwKeyValueStorePlugin`, so it is also where the signed-in session's key lives |
| [`dartway_telegram`](https://pub.dev/packages/dartway_telegram) | `dw.plugins.telegram` | Telegram Mini App: viewport, safe-area insets, Telegram user id |
| [`dartway_push_flutter`](https://pub.dev/packages/dartway_push_flutter) | `dw.plugins.push` | [Push notifications](push-notifications.md): permissions, token lifecycle, taps — with the transport itself in a package of its own |
| [`dartway_offline_flutter`](https://pub.dev/packages/dartway_offline_flutter) | `dw.plugins.offline` | [Offline](offline.md): the local copy `dw.repo` reads and writes through, plus downloads, signed access leases and trusted time |

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
  Future<void> init(DwFlutter core) async {
    // runs during dw.init(), before the first frame, with the core it was
    // plugged into — ignore the argument if you have no use for it
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
