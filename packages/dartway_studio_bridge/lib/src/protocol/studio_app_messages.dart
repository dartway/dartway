part of 'studio_bridge_message.dart';

/// App → Studio: announced on host attach (page load, hot restart).
class AppReadyMessage extends StudioBridgeMessage {
  const AppReadyMessage();

  @override
  String get type => StudioBridgeProtocol.appReady;
}

/// App → Studio: the handshake response — the full manifest plus the current
/// route and session so Studio renders correctly right away.
class ManifestMessage extends StudioBridgeMessage {
  const ManifestMessage({
    required this.manifest,
    required this.currentPath,
    required this.session,
  });

  final StudioProjectManifest manifest;
  final String currentPath;
  final StudioSessionState session;

  @override
  String get type => StudioBridgeProtocol.manifest;

  @override
  Map<String, dynamic> payloadToJson() => {
        'manifest': manifest.toJson(),
        'currentPath': currentPath,
        'session': session.toJson(),
      };

  factory ManifestMessage.fromPayload(Map<String, dynamic> payload) =>
      ManifestMessage(
        manifest: StudioProjectManifest.fromJson(
          payload['manifest'] as Map<String, dynamic>? ?? const {},
        ),
        currentPath: payload['currentPath'] as String? ?? '/',
        session: StudioSessionState.fromJson(
          payload['session'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

/// App → Studio: the app's router moved to a new location.
class RouteChangedMessage extends StudioBridgeMessage {
  const RouteChangedMessage(this.path);

  final String path;

  @override
  String get type => StudioBridgeProtocol.routeChanged;

  @override
  Map<String, dynamic> payloadToJson() => {'path': path};

  factory RouteChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      RouteChangedMessage(payload['path'] as String? ?? '/');
}

/// App → Studio: the session changed (sign-in, sign-out, switch progress).
class SessionChangedMessage extends StudioBridgeMessage {
  const SessionChangedMessage(this.session);

  final StudioSessionState session;

  @override
  String get type => StudioBridgeProtocol.sessionChanged;

  @override
  Map<String, dynamic> payloadToJson() => {'session': session.toJson()};

  factory SessionChangedMessage.fromPayload(Map<String, dynamic> payload) =>
      SessionChangedMessage(
        StudioSessionState.fromJson(
          payload['session'] as Map<String, dynamic>? ?? const {},
        ),
      );
}
