import 'dart:convert';

/// Wire-level constants of the Studio bridge protocol.
///
/// Every message is a JSON object encoded as a string:
/// `{"dartwayStudioBridge": 1, "type": "<messageType>", "payload": {...}}`.
abstract final class StudioBridgeProtocol {
  /// Bumped on breaking schema changes; both sides ignore other versions.
  /// v2: passport texts are plain strings (were bilingual objects), locale
  /// switching added (`supportedLocales` / `currentLocale` / locale messages).
  /// v3: demo personas moved from the app manifest into Studio's own project
  /// config — `personaRequest` replaced by `signInRequest` carrying the
  /// credentials, the manifest no longer lists personas, and the session
  /// reports the signed-in `userIdentifier` instead of a persona id.
  /// v4: `studioConnect` presents a short-lived `accessToken` — signed by
  /// Studio, issued for the app's own origin — instead of the shared
  /// per-project secret (`accessKey`) it used to carry.
  ///
  /// **Adding a message type is not a schema change and must not bump this.**
  /// The version is checked strictly on decode, so a bump silences every build
  /// already in the field, in both directions, the moment it ships. A new type
  /// costs nothing instead: an old side drops the envelope it does not
  /// recognise and carries on, which is how [connectRefused] arrived inside
  /// v4. Bump only when the *meaning* of an existing message changes.
  static const version = 4;

  /// Envelope marker key carrying [version].
  static const envelopeKey = 'dartwayStudioBridge';

  static const typeKey = 'type';
  static const payloadKey = 'payload';

  // App → Studio.
  static const appReady = 'appReady';
  static const manifest = 'manifest';
  static const routeChanged = 'routeChanged';
  static const sessionChanged = 'sessionChanged';
  static const featuresChanged = 'featuresChanged';
  static const localeChanged = 'localeChanged';
  static const inspectPointResult = 'inspectPointResult';

  /// The refusal of a handshake: the app heard [studioConnect], understood the
  /// token it carried, and would not accept it. Added *inside* version 4 — see
  /// [version] for why adding a type is not a schema change.
  static const connectRefused = 'connectRefused';

  // Studio → app.
  static const studioConnect = 'studioConnect';
  static const navigateRequest = 'navigateRequest';
  static const signInRequest = 'signInRequest';
  static const signOutRequest = 'signOutRequest';
  static const localeRequest = 'localeRequest';
  static const inspectPointRequest = 'inspectPointRequest';

  /// The envelope version inside raw postMessage [data], or null when there is
  /// no envelope — the data is not ours at all.
  ///
  /// This is the one thing decoding cannot tell you. A message that fails to
  /// decode fails the same way whether it belongs to somebody else or is our
  /// own envelope at another [version], and the two are opposite diagnoses:
  /// ignore the first, repair the second. An app on v3 and a Studio on v4 were
  /// simply quiet at each other for a day because nothing here said which.
  ///
  /// Accepts either the raw string off the wire or an already-decoded map, so a
  /// caller that has parsed the JSON does not parse it twice.
  static int? envelopeVersionOf(Object? data) {
    Object? decoded = data;
    if (data is String) {
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final version = decoded[envelopeKey];
    return version is int ? version : null;
  }
}
