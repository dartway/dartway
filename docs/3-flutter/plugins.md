# How does an app add something the framework knows nothing about?

Every app eventually needs an integration the framework has no business knowing: local storage,
Telegram, a vendor SDK someone signed a contract for. The usual answer is a field on the framework's
config — `DwConfig(telegram: ...)` — and from that moment every app carries the vendor's dependency,
including the ones that will never open Telegram.

DartWay does not do that. The framework knows what a **plugin** is; it never knows what any
particular one *does*. `dartway_core_flutter` contains no mention of Telegram or of
`shared_preferences` — only `DwPlugin`, an abstract class with a single `init(core)`
(`packages/dartway_core_flutter/lib/src/core/logic/dw_plugin.dart`).

The consequences are the whole point:

- `DwConfig` never grows a field named after a vendor;
- an app that does not use an integration does not download it;
- an integration is released, versioned and broken on its own schedule, without a framework release.

## Three steps, and the third is the interesting one

**1. Add the package.** Plugins live on pub.dev like anything else:

```bash
flutter pub add dartway_shared_preferences
```

**2. Declare it once, where the core is built** — `lib/core/dw_core.dart`:

```dart
dw = DwFlutterCore(
  config: DwConfig(/* ... */),
  protocol: appProtocol,
  baseUrl: baseUrl,
  plugins: [DwSharedPreferences()],
);
```

`plugins` is declared on `DwFlutter` and passed through by `DwFlutterCore`, so an app on the plain
toolbox writes `DwFlutter(config: ..., plugins: [...])` and nothing else changes.

**3. Reach it as `dw.plugins.<name>`:**

```dart
final darkModeProvider = dw.plugins.prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);
```

That accessor is **not** in the framework. It is an extension declared in the plugin's own package:

```dart
// packages/dartway_shared_preferences/lib/src/dw_shared_preferences.dart
extension DwPrefsAccess on DwPlugins {
  DwSharedPreferences get prefs => of<DwSharedPreferences>();
}
```

So `dw.plugins.prefs` exists only for apps that chose that package — the ergonomics of an ambient
service with none of the coupling. `dw.` is the framework's closed, known core; `dw.plugins.` is the
open set a project plugs in.

**The extension has to be imported** in every file that reads it. When that gets noisy, re-export the
plugin from the file where the app declares `dw`, the way the kit's root file re-exports
`dartway_core_flutter`:

```dart
// lib/core/dw_core.dart
export 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
```

The failure is worth recognising in advance, because the analyzer does not describe it: with the
import missing you are told *"the getter `prefs` isn't defined for the type `DwPlugins`"* — about a
getter that is perfectly fine.

## When a plugin is initialized

`dw.init()` runs `init(core)` on every declared plugin, awaited, in declaration order, **before** the
client reads the stored session — and the bootstrap runs `dw.init()` before the first frame:

```dart
DwAppRunner(
  appInitializers: [dw.init],
  supportedLocales: AppLocalizations.supportedLocales,
  child: const ExampleApp(),
).run();
```

So plugins are ready before the data layer starts, and both are ready before the app renders. See
[Flutter core](flutter-core.md#two-phases-build-then-start).

### What a failing plugin costs — `blocksStartup`

**By default, everything: the app does not start.** `DwPlugin.blocksStartup` is `true` unless a plugin
says otherwise, because a plugin an app declared is one it expects to have, and an app running without
it is an app whose features fail one by one, later and further from the cause. The failure lands on
`DwAppRunner`'s error screen, which prints it.

Starting anyway is a decision, made by the plugin that knows whether it is load-bearing:

```dart
class MyAnalytics extends DwPlugin {
  // Its absence costs analytics and nothing else.
  @override
  bool get blocksStartup => false;

  @override
  Future<void> init(DwFlutter core) async {/* ... */}
}
```

A non-blocking failure is reported once through the error pipeline and the remaining plugins still run.
Without this, declaration order would decide the blast radius: one `init` that threw would stop every
plugin after it, and an optional integration listed first could take down an app that would have run
without it.

Either way the failure travels as `DwPluginInitException`, naming the plugin and carrying the cause —
a report says which plugin failed, not a raw null check from inside a third-party package.

Reaching for a plugin that failed says so. `of<T>()` throws a `StateError` naming the plugin and the
failure, not a `LateInitializationError` from inside the package. `maybeOf<T>()` asks whether anybody
holds a role, and a plugin that did not survive does not hold it, so it answers `null`.

Forget to declare a plugin and the failure is loud: `dw.plugins.of<T>()` throws a `StateError` naming
the type that was never registered. It never returns null.

### `init` is handed the core, and that is not a convenience

A plugin cannot read `dw` while it is being declared. Look at where the declaration sits:

```dart
late DwFlutterCore dw;         // the app's own variable

dw = DwFlutterCore(
  // ...
  plugins: [MyPlugin()],       // built as an argument to the constructor that assigns dw
);
```

`plugins:` is a constructor parameter, so every plugin is constructed *before* the variable it will be
reached through is assigned. Anything that touches `dw` inside that list throws
`LateInitializationError` before the first frame — and the analyzer says nothing, because `late` is
exactly the promise that it will be there by the time anyone reads it. The framework does not export
its own pointer to the core either: `dw` is the app's variable.

Hence the argument. `init` is the first moment the core exists, and it arrives rather than being looked
up:

```dart
class MyPlugin extends DwPlugin {
  DwValueProvider<int?>? _accountId;

  @override
  Future<void> init(DwFlutter core) async {
    // A plugin that needs the data layer names DwFlutterCore and casts. The cast
    // says out loud that this plugin does not work on the plain toolbox, and
    // fails at startup rather than at the first read.
    _accountId = (core as DwFlutterCore).accountId;
  }
}
```

The parameter is a `DwFlutter` because that is what declares `plugins:`. An app on the data layer
passes a `DwFlutterCore`, which *is* a `DwFlutter` — so a plugin that needs nothing from the core (most
of them) ignores the argument and works on both.

What a plugin must **not** do is read, during `init`, a value the app has not set up yet. The session is
the usual example: plugins run before the client reads the stored session, so at `init` time nobody is
signed in. Capture the provider, watch it from the widget tree, and react.

## A role the framework asks for: `DwKeyValueStorePlugin`

Most plugins are an app reaching for its own integration. A role is the other way round: the framework
needs **a job done** and has no opinion about who does it. The role is declared as an abstract plugin in
the framework and claimed by whatever plugin the app declares.

| Role | Who asks | Without one |
|---|---|---|
| `DwKeyValueStorePlugin` | `DwFlutterCore`, to keep the signed-in session across restarts | `dw.init()` throws a `StateError` naming the fix — unless the core was given a `tokenStore:` of its own |

`DwKeyValueStorePlugin` is a handful of key-value methods (`getString`, `setString`, `getInt`,
`setInt`, `remove`) plus `isPersistent` — false where the store fell back to memory, so the app can say
"this browser will not remember you" instead of looking broken. `DwSharedPreferences` claims it; an app
that keeps its session somewhere else writes its own plugin, or passes the core a `DwTokenStore`
directly. See [Flutter core](flutter-core.md#where-the-session-is-kept).

**Why a role and not a direct call.** The framework could reach for `shared_preferences` itself. Then
there would be two implementations of one job — the framework's and the plugin's — agreeing only because
they happen to sit on one store, and a decision made on one side (a fallback, a failure mode) would be
invisible from the other. One implementation, named through a role, is what the role is for.

The framework asks with `maybeOf`, so absence is an ordinary answer. Two plugins claiming one role is
not: `maybeOf` throws rather than picking one.

## Distribution: pub.dev

**Plugins ship on pub.dev, versioned independently of the core family.** An app adds a normal caret
constraint and resolves like any other Dart project. Each plugin states its compatibility with a caret
on the framework — `dartway_shared_preferences` depends on `dartway_core_flutter: ^0.20.0-dev.1` — so a
breaking release of the family is followed by a release of each plugin, and pub refuses the combinations
that were never tested instead of failing at runtime.

Path and git dependencies look like a shortcut when a plugin and an app sit on one machine, and they
cost more than they save:

- a `path:` dependency resolves only in the tree that wrote it; for everybody else — CI included — the
  app does not resolve;
- a git ref pins a moving branch, so two checkouts of one app can build different code;
- `dependency_overrides` is **global to the resolution** and silently outranks every constraint in the
  graph, including the ones the framework states on purpose. Take a newer satellite with it only until
  the framework family raises its own caret, then remove it.

## What exists

| Package | Reached as | What it is |
|---|---|---|
| `dartway_shared_preferences` | `dw.plugins.prefs` | Typed Riverpod providers over local storage (`provider`, `mappedProvider`, `providerFamily`, `mappedProviderFamily`, and `raw` for imperative reads); claims `DwKeyValueStorePlugin`, so it is also where the signed-in session lives. `DwSharedPreferences(whenUnavailable:)` decides between running from memory and failing when the platform has no store. |
| `dartway_telegram` | `dw.plugins.telegram` | Telegram Mini App: `isRunningInTelegram`, `platform`, `safeAreaInset`, `telegramUserId`, configured by `DwTelegramWebAppConfig`. |

`dartway_telegram` shows the other half of what a plugin buys you: `DwTelegramWebApp.create()` returns
the real bridge on web and an inert stub on mobile and desktop, and outside Telegram every getter answers
as if Telegram were absent instead of throwing. One declaration, every platform still builds. Its
`telegramUserId` comes from Telegram's unsigned init data — a hint, never a proof of identity.

Push on the device is a page of its own: [push notifications](push-notifications.md).

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

- **the accessor lives in your package.** A getter on `DwPlugins` inside the framework would put your
  vendor's name in everybody's core — the thing this mechanism exists to prevent;
- **name it for the capability, not the vendor**, when a second implementation is plausible.
  `dw.plugins.prefs` reads as storage; `dw.plugins.telegram` is honest about being one product, and that
  is exactly why it is not called `dw.plugins.chat`.

A plugin used by one app does not need to be published — but it needs to be a package, not a folder
inside the app, the moment a second app wants it.
