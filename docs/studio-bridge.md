# DartWay Studio Bridge

Every DartWay app can describe itself for [DartWay Studio](https://dartway.dev)
— the closed platform that shows a live preview of your running app with a
screen map, screen passports and a demo-persona switcher.

The open `dartway_studio_bridge` package is the only integration surface:

- **Spec models** — declare navigation zones, screen passports
  (`StudioScreenSpec` with bilingual `StudioText`) and demo personas in your
  app's code. Screens are identified by route path strings, so any router
  works.
- **Runtime protocol** — a versioned `postMessage` protocol between Studio and
  the app's web build running in an iframe: Studio navigates the live app,
  the app reports route and session changes, persona sign-in runs entirely
  inside the app (credentials never cross the bridge).
- **`StudioBridgeHost.attach`** — call it once in your app shell (see
  `lib/studio/studio_bridge_binding.dart` in the example). The host is inert
  unless the app runs on web embedded in a Studio frame; release builds
  require an explicit origin allowlist.

See the package [README](../packages/dartway_studio_bridge/README.md) for the
full API, and `example/dartway_example_flutter/lib/studio/` for the reference
integration (manifest, personas, persona switcher, binding widget).
