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
  static const version = 3;

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

  // Studio → app.
  static const studioConnect = 'studioConnect';
  static const navigateRequest = 'navigateRequest';
  static const signInRequest = 'signInRequest';
  static const signOutRequest = 'signOutRequest';
  static const localeRequest = 'localeRequest';
}
