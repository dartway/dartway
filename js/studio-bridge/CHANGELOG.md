# Changelog

## 0.3.0

**`studioBridgeEnvelopeVersion(data)` — a protocol version mismatch stops
looking like a stranger's message.** `decodeStudioBridgeMessage` returns null
for both, and they are opposite diagnoses: foreign traffic on `window` is
normal and ignored, while our own envelope at another version means neither
side will hear the other until one is rebuilt. One such handshake — an app on
v3, a Studio on v4 — cost a day, with nothing anywhere to say which it was.

The reader takes the raw string or an already-parsed object, and `decode` now
reads the envelope through it, so the check and the diagnostic cannot disagree
about what an envelope is. The twin of `StudioBridgeProtocol.envelopeVersionOf`
in the Dart package, kept honest by the same golden wire strings.

**The protocol version stays 4.** Nothing on the wire changed.

## 0.2.0

**A refused handshake now gets an answer instead of silence.** The app sends
`connectRefused` when the token it was shown parses as a signed Studio token and
fails the check — expired, or signed by another key. Until now a refusal and a
build with no bridge in it looked identical from the other side: an empty frame.
They are two entirely different repairs, and whoever is connecting a project had
no way to tell which one they were looking at.

**Only a token that parses gets answered.** An empty, absent or garbled token is
still met with silence (`looksLikeStudioBridgeToken`, exported for anyone who
wants the same distinction), so a stranger who guessed the preview URL does not
learn that there is a bridge on this page. Studio signs correctly by
construction, so a refusal it can read means "your signature is stale or your
key is wrong". A build in the zero-config local-dev mode (`appOrigin` left out)
accepts everyone and therefore refuses nobody.

**The protocol version stays 4.** It is checked strictly on decode, so bumping
it would silence every build in the field in *both* directions the moment it
shipped. A new message type is additive instead: a Studio that has never heard
of `connectRefused` drops the envelope and behaves exactly as it did before.
The golden wire string for it is in `test/protocol.test.ts`, character for
character identical to the one in the Dart package's tests.

Ships alongside `dartway_studio_bridge` 0.8.0, which adds the same message and
the same refusal rule, plus a Studio-side one-shot probe that reads it.

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
