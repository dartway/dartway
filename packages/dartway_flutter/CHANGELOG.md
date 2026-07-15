# Changelog

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
