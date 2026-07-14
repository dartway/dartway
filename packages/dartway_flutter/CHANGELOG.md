# Changelog

## 0.1.0

First public release — the Flutter skeleton of a DartWay app: everything an app needs before and
around its data layer.

**App bootstrap.** `DwAppRunner` owns what every app sets up and no app enjoys setting up: the
`ProviderScope`, the native splash, async initializers, and a zone that routes uncaught errors into
the error pipeline instead of losing them.

**The async-UI contract.** `dwBuildAsync` / `dwBuildListAsync` render loading, error and data
uniformly — and the loading state is a skeleton derived from your real widget, not a spinner.

**Guarded actions.** `DwUiAction` describes *what* an action does — confirmation
(`DwUiConfirmation`), success notification, follow-up, error reporting — and `DwActionBuilder` binds
it to *any* tappable widget and handles the rest: no re-entrant taps (a double tap does not book
twice), an in-flight flag, optional `Form` validation. The guard is not welded to a button, so a
list tile or an icon gets it too.

**Notifications.** A global overlay pipeline: post a `DwUiNotification` from anywhere
(`dw.notify.success(...)`), render it with your own handler.

**Error reporting with context.** Every error carries an app-state snapshot — route, mounted
features, the action label, platform, version — through an overridable `reportError`. A minified web
stack trace tells you nothing; this tells you what the user was doing.

**Feature declarations.** `DwFeature` / `scanMountedFeatures`: mark widgets as product features and
discover the mounted ones at runtime — for feature catalogs, analytics, error context and
[DartWay Studio](https://dartway.dev) passports.

**Plugins.** `DwPlugin` is the seam for integrations the framework must not know about: declare one
at startup and reach it anywhere via `dw.plugin<T>()`. Telegram Mini App support lives outside this
package, in [`dartway_telegram`](https://pub.dev/packages/dartway_telegram) — an app that is not a
Mini App never downloads a Telegram SDK.

**It ships no design system.** There is no `DwButton`, no `DwText`, no theme and no style presets —
on purpose. A design system is the one thing every serious app ends up owning, and shipping it as a
dependency only starts an argument about the corner radius of your button. `dartway create`
scaffolds a UI kit **into your app** as source you own. What this package keeps is the mechanism you
should not have to reinvent.

Riverpod-native by design: `AsyncValue` is the type the whole async-UI contract is built on. That is
not an implementation detail you can swap — it is the framework.
