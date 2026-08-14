# Changelog

## 0.5.1

**`dwBuildListAsync` builds its skeleton only when it is showing one.** The placeholder list — and
the assert that a placeholder is obtainable at all — used to be computed before `dwBuildAsync` was
even asked which branch to render, so `dw.getDefaultModel<T>()` ran on the data and error frames
too. In an app that is invisible, because `DefaultModels.initRepository()` runs at startup. In a
widget test it is a wall: a screen handed a ready `AsyncData<List<X>>([])`, with no loading state
anywhere in the test, still died on `UnimplementedError: Default Objects Repository doesn't contain
a model of type X` — a message naming neither the screen nor the test.

Both builders now delegate to one implementation that takes the placeholder as a factory and calls
it inside the loading branch, where the single-value `dwBuildAsync` already computed its own. The
public API is unchanged; a widget test of a list screen no longer has to stand up the default-model
registry unless it is genuinely testing the loading state.

## 0.5.0

**A plugin is handed the core it was plugged into.** `DwPlugin.init()` now takes one:
`Future<void> init(DwFlutter core)`. Until now it took nothing, and a plugin had no legal way to
reach the framework it was part of.

The gap was not theoretical. A plugin is constructed *as an argument* to the constructor that
assigns `dw` — that is what `plugins:` being a constructor parameter means — while the app declares
`late final DwCore<Client, UserProfile> dw`. So anything a plugin needs from the core has to be
passed in at declaration time, and the ambient instance is not assigned yet. Writing the obvious
thing inside the list:

```dart
plugins: [DwPush(config: DwPushConfig(
  recipientIdProvider: dw.userProfileProvider.select((p) => p?.id),  // throws at startup
))],
```

compiles silently and fails with `LateInitializationError` before the first frame. `dw` is also not
exported by the framework — neither `dartway_flutter` nor `dartway_serverpod_core_flutter` hands the
singleton out — so there was no version of that line that worked, only versions that looked like they
might. `dartway_push_flutter`'s own README shipped one.

`init` is the first moment the core exists, so that is where it arrives. The argument is a
`DwFlutter`; an app on the data layer passes a `DwCore`, which is one — a plugin that needs the data
layer names it and casts, and thereby says out loud that it does not work on the plain toolbox.

**Breaking, mechanically.** Every `DwPlugin` implementation adds the parameter; nothing else about a
plugin changes, and a plugin with no use for the core ignores it. `DwPlugins.initAll()` takes the core
too, and `dw.init()` passes itself.

## 0.4.0

**A feature can be found by pointing at it.** `DwFeature.hitTest(globalPosition)` answers what is
declared at a point on screen — the other half of `scanMounted`, which answers what is declared on
the screen at all. Studio's tap-to-inspect is the first caller: pick a spot in the live preview, get
that feature's passport, with no id to look up and no map to keep in your head.

The innermost declaration wins. A card and the "more actions" row inside it both cover the tap, and
the row is what the finger landed on — so the walk goes depth-first and takes the last match, not
the first.

A feature is matched on the area it actually **paints** into, not the one it lays out in. The two
differ more often than they sound like they would: a subtree under a `Transform.scale` draws
smaller than it measures, and a list item scrolled past the edge of its viewport keeps its layout
position while painting nothing at all — and being deeper in the tree, it would have won over the
feature you can see. Both are cut out by transforming through to the root and intersecting with
every ancestor clip.

Same rule as `scanMounted` for subtrees Flutter parks out of sight (offstage, invisible, disabled
ticker) — being mounted is not being on screen, and now neither is being laid out.

## 0.3.0

**A feature can say what is wrong with it.** `DwFeatureSpec` gains `knownIssues` — a setting nothing
reads, a screen still wired to mock data, a sort order commented out while the field feeding it
stayed in the form. `hasKnownIssues` answers the catalog's question without every caller repeating
`.isNotEmpty`.

The line against `implementationNotes` is what the reader is meant to do about the entry: a note
says "this is deliberate, leave it", an issue says "this is not right, fix it". An agent editing the
feature has to tell them apart before it touches anything, and prose in one list could not. The
test: if someone fixed it, would the entry disappear?

Additive — the field defaults to empty, so existing specs compile unchanged.

## 0.2.0

**A feature now describes itself, and the description lives next to the code.** `DwFeatureSpec`
used to carry a single `description`, which is why every project that wanted more grew a second
description somewhere else — a doc page, a table in a tool — and then had two that disagreed. The
spec now carries the whole thing:

- `purpose` — why the feature exists for the user. Optional on purpose: a card or a row usually
  has no purpose of its own, it belongs to the screen it serves, and repeating the screen's
  purpose on each of its parts is noise.
- `behaviors` — what it observably does, one checkable statement per entry. The rule that keeps
  the field alive is in its doc comment: every entry must be verifiable by looking at the running
  app. The moment "works nicely with long titles" appears, the field has turned back into prose.
- `requirements` — what it must honour, imposed from outside it.
- `implementationNotes` — decisions a reader would otherwise re-open; written for the team, not
  for the client.

**Breaking:** `description` is gone. It sat between `title` and `behaviors` with nothing left to
say, and that is exactly what made feature descriptions shallow.

The registry enum is gone with it. A spec belongs in the file of the feature it describes — a
central catalog of every feature in the app is a file nobody reads that lives far from the code it
claims to describe. What the enum did give was enumerability, and a running app cannot replace it:
Dart has no reflection, so `DwFeature.scanMounted()` sees only what is on screen. A whole-project
catalog is a job for static analysis of the sources.

## 0.1.0

First public release — the Flutter skeleton of a DartWay app: everything an app needs before and
around its data layer.

**App bootstrap.** `DwAppRunner` owns what every app sets up and no app enjoys setting up: the
`ProviderScope`, the native splash, async initializers, and a zone that routes uncaught errors into
the error pipeline instead of losing them.

**The async-UI contract.** `dwBuildAsync` / `dwBuildListAsync` render loading, error and data
uniformly — and the loading state is a skeleton derived from your real widget, not a spinner.

**Guarded actions.** `dw.action(...)` builds a `DwUiAction` that describes *what* an action does —
confirmation (`DwUiConfirmation`), success notification, follow-up, error reporting — and
`DwActionBuilder` binds it to *any* tappable widget and handles the rest: no re-entrant taps (a
double tap does not book twice), an in-flight flag, optional `Form` validation. The guard is not
welded to a button, so a list tile or an icon gets it too.

**Notifications.** A global overlay pipeline: post a `DwUiNotification` from anywhere
(`dw.notify.success(...)`), render it with your own handler.

**Error reporting with context.** Every error carries an app-state snapshot — route, mounted
features, the action label, platform, version — through a single `DwConfig.onErrorReport` hook (and
an overridable `dispatchReport`). A minified web stack trace tells you nothing; this tells you what the
user was doing.

**Feature declarations.** `DwFeature` / `DwFeature.scanMounted`: mark widgets as product features and
discover the mounted ones at runtime — for feature catalogs, analytics, error context and
[DartWay Studio](https://dartway.dev) passports.

**Plugins.** `DwPlugin` is the seam for integrations the framework must not know about: declare one
at startup and reach it as `dw.plugins.<name>` — the open namespace for what a project plugs in, kept
apart from the core's own services. Telegram lives in
[`dartway_telegram`](https://pub.dev/packages/dartway_telegram) (`dw.plugins.telegram`), local
storage in [`dartway_shared_preferences`](https://pub.dev/packages/dartway_shared_preferences)
(`dw.plugins.prefs`) — an app that needs neither never downloads them.

**It ships no design system.** There is no `DwButton`, no `DwText`, no theme and no style presets —
on purpose. A design system is the one thing every serious app ends up owning, and shipping it as a
dependency only starts an argument about the corner radius of your button. `dartway create`
scaffolds a UI kit **into your app** as source you own. What this package keeps is the mechanism you
should not have to reinvent.

Riverpod-native by design: `AsyncValue` is the type the whole async-UI contract is built on. That is
not an implementation detail you can swap — it is the framework.
