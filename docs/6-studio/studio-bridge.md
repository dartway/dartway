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
  the app's web build running in an iframe: Studio navigates the live app,
  switches its UI locale (when the manifest declares `supportedLocales`) and
  asks what is declared at a point on screen; the app reports route, session
  and locale changes.
- **Demo personas are configured in Studio, not in the app.** Test users and
  their verification codes live in the platform's project config; on switch
  Studio sends them over the bridge and the app runs its **regular** auth flow
  with them (DartWay server side: per-user rotatable `testVerificationCode`).
  A public web build therefore ships no test accounts and no special sign-in
  path. Role-gating of zones stays entirely in the app — guards and server
  filters, not spec metadata.
- **`StudioBridgeHost.attach`** — call it once in your app shell (see
  `lib/core/studio/studio_bridge_binding.dart` in the example). The host is inert
  unless the app runs on web embedded in an iframe; the channel pins the
  origin of the first valid Studio message for its replies.
- **Access is proved by a signature.** Studio presents a short-lived token,
  signed with its own Ed25519 key and issued for a single origin — the address
  your build answers at — and the app accepts the connection only if that token
  passes its `validateAccessToken`. A token taken off the wire is therefore
  useless anywhere else, and it expires on its own.

  Your build holds no secret and copies nothing out of Studio: the public half
  of the pair ships inside the bridge package, and a public key can only check
  signatures, never make them. The build names one thing — where it answers:
  `--dart-define=STUDIO_APP_ORIGIN=https://app.example`, wired through the
  shipped `studioSignedAccessValidator`. Leave the define out and the build
  accepts any connection, which is what makes running Studio against your local
  build a zero-config affair.
- **Features** arrive per screen, as the app navigates: every widget that
  implements `DwFeature` declares its `DwFeatureSpec` next to itself, and the
  binding reports the ones currently mounted. What a feature says about itself
  — `purpose`, `behaviors`, `requirements`, `implementationNotes`,
  `knownIssues` — travels over the bridge on every connect, so Studio renders
  it live and stores none of it: there is nothing that can drift away from the
  code. A feature with a non-empty `knownIssues` is flagged in the catalog, so
  the open questions of a project are visible without opening every passport.

  `manifest.features` stays in the protocol for the *whole-project* catalog,
  but a running app cannot fill it: Dart has no reflection, so only mounted
  widgets are observable. Enumerating every feature of a project is a job for
  static analysis of the sources, not for the app.

- **Tap to inspect.** Studio can point at a spot in the live preview and get
  the feature declared there (`DwFeature.hitTest` on the app side), so a
  passport is reachable by pointing rather than by knowing the feature's id.
  The point crosses the bridge as fractions of the app's viewport, not pixels —
  Studio may be showing the preview scaled or framed, and only the app knows
  its own logical size, so the app converts. A feature is matched on the area
  it actually paints into: something scaled down, scrolled out of its viewport
  or clipped away does not answer for a point where the user sees nothing.

See the package [README](../packages/dartway_studio_bridge/README.md) for the
full API, and `example/dartway_example_flutter/lib/core/studio/` for the reference
integration (manifest, sign-in executor, binding widget).
