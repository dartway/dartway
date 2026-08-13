# Changelog

## 0.1.0

First release: the app side of the Studio bridge for JavaScript apps, speaking
**protocol version 4** — the same wire format as the Dart package
`dartway_studio_bridge` 0.7.0. A React or Vue app connects to an unmodified
Studio; nothing on the Studio side knows which implementation it is talking to.

- `attachStudioBridge` — the handshake, the manifest, route/session/locale/
  feature reports and Studio's requests (navigate, sign in with test
  credentials, sign out, switch locale, inspect a point). Returns `null` outside
  an iframe, so the call needs no environment guard.
- **Access is proved by a signature.** The public half of Studio's Ed25519 key
  ships in the package; a build names the origin it answers at and accepts only
  a live token signed for that origin. A build that names none accepts any
  connection — the zero-config local-dev mode.
- **Feature declarations** live in a registry independent of the bridge, so
  declaring is free, cannot fail and does not depend on load order:
  `declareStudioFeature` in plain JS, `<StudioFeature>` / `useStudioFeature` in
  `@dartway/studio-bridge/react` and `@dartway/studio-bridge/vue`. A declaration
  bound to an element also answers Studio's tap-to-inspect.
- Route changes are picked up from `history` and `popstate`, so any router
  reports itself without wiring.
- A token that cannot be **checked** — no WebCrypto (the page is not a secure
  context), a browser without Ed25519, a misconfigured `publicKey` — is refused
  like any other, and the reason is written to the console once. A token that is
  checked and found wanting stays silent: refusing it is the check working.

Two things this implementation did from the start and the Dart one did not:
**every command is gated on the handshake**, not just the manifest, and
**nothing is reported before a Studio has been let in**. Writing them here is
what surfaced the same gap in the Dart host, fixed in `dartway_studio_bridge`
0.7.1 — the two now agree.
