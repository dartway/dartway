# DartWay Flutter

The Flutter shell of a [DartWay](https://dartway.dev) app — everything an app
needs before and around its data layer:

- 🚀 **App bootstrap** — `DwAppRunner`: ProviderScope, native splash handling,
  app initializers and zone-level error handling in one place.
- 🔔 **Notifications** — a global overlay pipeline: post a `DwUiNotification`
  from anywhere (`dw.notify.success(...)`), render it with themable handlers.
- 🖼️ **Base UI kit** — `DwButton` presets, `DwText`, `MultiLinkText`,
  `DwDeviceFrame`, `DwInfiniteListView`; styled through `DwFlutterTheme`, so
  the design system stays the app's own.
- ⚡ **Async utilities** — `AsyncValue` builders with skeleton loading states
  (`dwBuildListAsync`), `DwUiAction` safe callbacks with success/error
  notifications, context helpers.
- 🏷️ **Feature declarations** — `DwFeature` / `scanMountedFeatures`
  (re-exported from `dartway_studio_bridge`): mark widgets as product features
  and discover the mounted ones at runtime — for feature catalogs, analytics
  and [DartWay Studio](https://dartway.dev) passports.

Designed to be used with the DartWay data layer
(`dartway_serverpod_core_flutter`), which re-exports this package — but it has
no server dependencies and works in any Flutter app.

## Quick start

```dart
void main() {
  DwAppRunner(
    appInitializers: [myInit],
    child: const MyMaterialApp(),
  ).run();
}
```

Theme the built-in widgets once via a `ThemeData` extension:

```dart
ThemeData(
  extensions: const [
    DwFlutterTheme(
      primaryButton: AppButton.primary,
      multiLinkText: AppText.body,
      // ...
    ),
  ],
)
```

See `example/` in the [DartWay monorepo](https://github.com/dartway/dartway)
for the canonical usage — a full fitness-club app built on the DartWay stack.
