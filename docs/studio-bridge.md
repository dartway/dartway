# DartWay Studio Bridge

Every DartWay app can describe itself for [DartWay Studio](https://dartway.dev)
— the closed platform that shows a live preview of your running app with a
screen map, screen passports and a demo-persona switcher.

The open `dartway_studio_bridge` package is the only integration surface:

- **Spec models** — declare navigation zones and screen passports
  (`StudioScreenSpec`, plain single-language strings — written in whatever
  language your team works in) in your app's code. Screens are identified by
  route path strings, so any router works.
- **Runtime protocol** — a versioned `postMessage` protocol between Studio and
  the app's web build running in an iframe: Studio navigates the live app and
  switches its UI locale (when the manifest declares `supportedLocales`), the
  app reports route, session and locale changes.
- **Demo personas are configured in Studio, not in the app.** Test users and
  their verification codes live in the platform's project config; on switch
  Studio sends them over the bridge and the app runs its **regular** auth flow
  with them (DartWay server side: per-user rotatable `testVerificationCode`).
  A public web build therefore ships no test accounts and no special sign-in
  path. Role-gating of zones stays entirely in the app — guards and server
  filters, not spec metadata.
- **`StudioBridgeHost.attach`** — call it once in your app shell (see
  `lib/studio/studio_bridge_binding.dart` in the example). The host is inert
  unless the app runs on web embedded in an iframe; the channel pins the
  origin of the first valid Studio message for its replies.
- **Access control is per project.** Studio holds a random secret per project;
  the app accepts a connection only if the presented key passes its
  `validateAccessKey`. The shipped `studioHashAccessValidator` bakes only the
  secret's hash into the build (`--dart-define=STUDIO_KEY_HASH=...`), so the
  secret never lives in the app's public bundle — only its hash does. Grab the
  hash from the project's settings in Studio.
- **Features** arrive per screen, as the app navigates: every widget that
  implements `DwFeature` declares its `DwFeatureSpec` next to itself, and the
  binding reports the ones currently mounted. What a feature says about itself
  — `purpose`, `behaviors`, `requirements`, `implementationNotes` — travels
  over the bridge on every connect, so Studio renders it live and stores none
  of it: there is nothing that can drift away from the code.

  `manifest.features` stays in the protocol for the *whole-project* catalog,
  but a running app cannot fill it: Dart has no reflection, so only mounted
  widgets are observable. Enumerating every feature of a project is a job for
  static analysis of the sources, not for the app.

See the package [README](../packages/dartway_studio_bridge/README.md) for the
full API, and `example/dartway_example_flutter/lib/studio/` for the reference
integration (manifest, sign-in executor, binding widget).
