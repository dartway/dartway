# DartWay Flutter

The Flutter skeleton of a [DartWay](https://dartway.dev) app — everything an app
needs before and around its data layer:

- 🚀 **App bootstrap** — `DwAppRunner`: ProviderScope, native splash handling,
  app initializers and zone-level error handling in one place.
- ⚡ **The async-UI contract** — `dwBuildAsync` / `dwBuildListAsync` render
  loading, error and data uniformly, with skeleton loading states derived from
  your real widget.
- 🎬 **Guarded actions** — `DwUiAction` describes *what* an action does
  (confirmation, notifications, follow-up, error reporting); `DwActionBuilder`
  binds it to *any* tappable widget and handles the rest: no re-entrant taps,
  an in-flight flag, optional `Form` validation.
- 🔔 **Notifications** — a global overlay pipeline: post a `DwUiNotification`
  from anywhere (`dw.notify.success(...)`), render it with your own handler.
- 🧯 **Error reporting** — every error carries an app-state snapshot: route,
  mounted features, action label, platform, version.
- 🏷️ **Feature declarations** — `DwFeature` / `scanMountedFeatures`: mark
  widgets as product features and discover the mounted ones at runtime — for
  feature catalogs, analytics and [DartWay Studio](https://dartway.dev)
  passports.

## Riverpod-native by design

DartWay is opinionated: Serverpod on the server, **Riverpod on the client**.
`DwAppRunner` mounts the `ProviderScope`, the data layer exposes providers, and
`AsyncValue` is the type the whole async-UI contract is built on. This is not an
implementation detail you can swap — it is the framework.

## It ships no design system

There is no `DwButton`, no `DwText`, no theme and no style presets here — on
purpose. A design system is the one thing every serious app ends up owning, and
shipping it as a dependency only starts an argument about the corner radius of
your button.

Instead, `dartway create` scaffolds a UI kit **into your app**, as source you
own outright: `AppText`, `AppButton` and friends live in your `lib/ui_kit/`, and
you change them without asking anyone. What this package keeps is the mechanism
you should not have to reinvent — the action guard and the async contract above.

```dart
// your app's kit — your widget, your styles
AppButton.primary(
  'Save',
  onTap: DwUiAction.create(
    (context) => ref.saveModel(model),
    onSuccessNotification: 'Saved',
  ),
)

// the framework's part of it — works under any widget, not just buttons
DwActionBuilder(
  action: deleteAction,
  builder: (context, onPressed, busy) => ListTile(
    onTap: onPressed,
    trailing: busy
        ? const CircularProgressIndicator()
        : const Icon(Icons.delete),
  ),
)
```

## Quick start

```dart
void main() {
  DwAppRunner(
    appInitializers: [myInit],
    child: const MyMaterialApp(),
  ).run();
}
```

Designed to be used with the DartWay data layer
(`dartway_serverpod_core_flutter`), which re-exports this package — but it has
no server dependencies and works in any Flutter app.

See `example/` in the [DartWay monorepo](https://github.com/dartway/dartway)
for the canonical usage — a full service-business app built on the DartWay
stack, including the UI kit `dartway create` gives you.
