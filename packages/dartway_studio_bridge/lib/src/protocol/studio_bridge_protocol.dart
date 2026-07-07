/// Wire-level constants of the Studio bridge protocol.
///
/// Every message is a JSON object encoded as a string:
/// `{"dartwayStudioBridge": 1, "type": "<messageType>", "payload": {...}}`.
abstract final class StudioBridgeProtocol {
  /// Bumped on breaking schema changes; both sides ignore other versions.
  static const version = 1;

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

  // Studio → app.
  static const studioConnect = 'studioConnect';
  static const navigateRequest = 'navigateRequest';
  static const personaRequest = 'personaRequest';
  static const signOutRequest = 'signOutRequest';
}
