part of 'studio_bridge_message.dart';

/// Studio → app: connection request; the app answers with a manifest message.
/// Sent on Studio start, retried while unconnected, and re-sent whenever an
/// app-ready message arrives (covers reloads of either side).
class StudioConnectMessage extends StudioBridgeMessage {
  const StudioConnectMessage();

  @override
  String get type => StudioBridgeProtocol.studioConnect;
}

/// Studio → app: navigate the live app to the given route path.
class NavigateRequestMessage extends StudioBridgeMessage {
  const NavigateRequestMessage(this.path);

  final String path;

  @override
  String get type => StudioBridgeProtocol.navigateRequest;

  @override
  Map<String, dynamic> payloadToJson() => {'path': path};

  factory NavigateRequestMessage.fromPayload(Map<String, dynamic> payload) =>
      NavigateRequestMessage(payload['path'] as String? ?? '/');
}

/// Studio → app: sign in as the declared persona; the app runs its own auth
/// flow (Studio never learns the credentials).
class PersonaRequestMessage extends StudioBridgeMessage {
  const PersonaRequestMessage(this.personaId);

  final String personaId;

  @override
  String get type => StudioBridgeProtocol.personaRequest;

  @override
  Map<String, dynamic> payloadToJson() => {'personaId': personaId};

  factory PersonaRequestMessage.fromPayload(Map<String, dynamic> payload) =>
      PersonaRequestMessage(payload['personaId'] as String? ?? '');
}

/// Studio → app: sign the current user out.
class SignOutRequestMessage extends StudioBridgeMessage {
  const SignOutRequestMessage();

  @override
  String get type => StudioBridgeProtocol.signOutRequest;
}
