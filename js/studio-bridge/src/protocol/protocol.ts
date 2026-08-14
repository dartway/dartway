/**
 * Wire-level constants of the Studio bridge protocol.
 *
 * Every message is a JSON object encoded as a string:
 * `{"dartwayStudioBridge": 4, "type": "<messageType>", "payload": {...}}`.
 *
 * This is a second implementation of one protocol — the first lives in the
 * Dart package `dartway_studio_bridge`. The two are not generated from a
 * shared schema, so the constants below are copied deliberately and the
 * golden-string tests are what keeps them honest: change one side and the
 * tests here fail rather than the pilot team's preview.
 */
export const studioBridgeProtocol = {
  /**
   * Bumped on breaking schema changes; both sides ignore other versions.
   * See the Dart package for the history of versions 1-3.
   * v4: `studioConnect` presents a short-lived `accessToken` — signed by
   * Studio, issued for the app's own origin — instead of a shared secret.
   *
   * **Adding a message type is not a schema change and must not bump this.**
   * The version is checked strictly on decode, so a bump silences every build
   * already in the field, in both directions, the moment it ships. A new type
   * costs nothing instead: an old side drops the envelope it does not
   * recognise and carries on, which is how `connectRefused` arrived inside v4.
   * Bump only when the *meaning* of an existing message changes.
   */
  version: 4,

  /** Envelope marker key carrying the version. */
  envelopeKey: 'dartwayStudioBridge',

  typeKey: 'type',
  payloadKey: 'payload',

  // App → Studio.
  appReady: 'appReady',
  manifest: 'manifest',
  routeChanged: 'routeChanged',
  sessionChanged: 'sessionChanged',
  featuresChanged: 'featuresChanged',
  localeChanged: 'localeChanged',
  inspectPointResult: 'inspectPointResult',

  /**
   * The refusal of a handshake: the app heard `studioConnect`, understood the
   * token it carried, and would not accept it. Added *inside* version 4 — see
   * `version` for why adding a type is not a schema change.
   */
  connectRefused: 'connectRefused',

  // Studio → app.
  studioConnect: 'studioConnect',
  navigateRequest: 'navigateRequest',
  signInRequest: 'signInRequest',
  signOutRequest: 'signOutRequest',
  localeRequest: 'localeRequest',
  inspectPointRequest: 'inspectPointRequest',
} as const;
