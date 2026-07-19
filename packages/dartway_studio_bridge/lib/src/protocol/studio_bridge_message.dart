import 'dart:convert';

import '../models/studio_feature_info.dart';
import '../models/studio_project_manifest.dart';
import '../models/studio_session_state.dart';
import 'studio_bridge_protocol.dart';

part 'studio_app_messages.dart';
part 'studio_request_messages.dart';

/// Base of all bridge messages; see [StudioBridgeProtocol] for the envelope.
sealed class StudioBridgeMessage {
  const StudioBridgeMessage();

  String get type;

  Map<String, dynamic> payloadToJson() => const {};

  String encode() => jsonEncode({
        StudioBridgeProtocol.envelopeKey: StudioBridgeProtocol.version,
        StudioBridgeProtocol.typeKey: type,
        StudioBridgeProtocol.payloadKey: payloadToJson(),
      });

  /// Parses raw postMessage data; null for anything that is not a valid
  /// message of the supported protocol version (foreign messages are common
  /// on `window` and must be ignored silently).
  static StudioBridgeMessage? tryDecode(Object? data) {
    if (data is! String) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded[StudioBridgeProtocol.envelopeKey] !=
        StudioBridgeProtocol.version) {
      return null;
    }
    final payload =
        decoded[StudioBridgeProtocol.payloadKey] as Map<String, dynamic>? ??
            const {};
    return switch (decoded[StudioBridgeProtocol.typeKey]) {
      StudioBridgeProtocol.appReady => const AppReadyMessage(),
      StudioBridgeProtocol.manifest => ManifestMessage.fromPayload(payload),
      StudioBridgeProtocol.routeChanged =>
        RouteChangedMessage.fromPayload(payload),
      StudioBridgeProtocol.sessionChanged =>
        SessionChangedMessage.fromPayload(payload),
      StudioBridgeProtocol.featuresChanged =>
        FeaturesChangedMessage.fromPayload(payload),
      StudioBridgeProtocol.localeChanged =>
        LocaleChangedMessage.fromPayload(payload),
      StudioBridgeProtocol.studioConnect => const StudioConnectMessage(),
      StudioBridgeProtocol.navigateRequest =>
        NavigateRequestMessage.fromPayload(payload),
      StudioBridgeProtocol.signInRequest =>
        SignInRequestMessage.fromPayload(payload),
      StudioBridgeProtocol.signOutRequest => const SignOutRequestMessage(),
      StudioBridgeProtocol.localeRequest =>
        LocaleRequestMessage.fromPayload(payload),
      _ => null,
    };
  }
}
