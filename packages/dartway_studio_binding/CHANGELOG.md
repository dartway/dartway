# Changelog

## 0.1.1

- Follows `dartway_studio_bridge` to `^0.9.0`. Nothing here changed: the binding
  attaches the host exactly as before. An app that wants the bridge's new
  connection diagnostics (`onMessageDropped`) reaches for
  `StudioBridgeHost.attach` directly for now.

## 0.1.0

- First release. `DwStudioBinding` is the app half of the Studio wiring: one widget in
  `MaterialApp.builder` that attaches the bridge host, reports the route (by declared name as well
  as by path), the mounted `DwFeature` passports, the session and the language, and executes
  Studio's navigation, persona and locale requests.
- The wiring used to be scaffolded into each project and travelled by copy-paste. None of it refers
  to any domain, and the copies had already drifted: the guard that stops an empty passport
  flashing in Studio between screens was in `template/` and missing from `example/`. There is one
  copy now, and a test that fails when the guard is removed.
- A project supplies only what the framework cannot know — the manifest, the screen passports,
  which profile field names the signed-in user (`describeUser`), how the app switches language
  (`DwStudioLocale`) and who may drive it (`validateAccessToken`).
- `dwStudioSpecForRoute` builds a screen passport from a typed route rather than a path string, so
  a path refactor cannot leave the manifest pointing at a screen that is gone.
- A persona switch runs the app's regular OTP flow, so the app ships no test users and no special
  sign-in path. An app configured without an auth key manager says so instead of failing a null
  check mid-flow.
