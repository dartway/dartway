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

/// Studio → app: sign in with the given test credentials through the app's
/// regular auth flow. The credentials belong to Studio's project config (demo
/// personas are a platform concern) — the app itself ships no test users and
/// no special sign-in path; it uses them exactly like user-typed ones.
class SignInRequestMessage extends StudioBridgeMessage {
  const SignInRequestMessage({
    required this.identifier,
    required this.secret,
  });

  /// The user identifier in the form the app's auth expects (phone, email).
  final String identifier;

  /// Whatever the app's auth flow expects as the second factor: a test
  /// verification code for OTP flows, a password for password flows.
  final String secret;

  @override
  String get type => StudioBridgeProtocol.signInRequest;

  @override
  Map<String, dynamic> payloadToJson() => {
        'identifier': identifier,
        'secret': secret,
      };

  factory SignInRequestMessage.fromPayload(Map<String, dynamic> payload) =>
      SignInRequestMessage(
        identifier: payload['identifier'] as String? ?? '',
        secret: payload['secret'] as String? ?? '',
      );
}

/// Studio → app: sign the current user out.
class SignOutRequestMessage extends StudioBridgeMessage {
  const SignOutRequestMessage();

  @override
  String get type => StudioBridgeProtocol.signOutRequest;
}

/// Studio → app: switch the app UI to the given locale (a language tag from
/// the manifest's `supportedLocales`).
class LocaleRequestMessage extends StudioBridgeMessage {
  const LocaleRequestMessage(this.locale);

  final String locale;

  @override
  String get type => StudioBridgeProtocol.localeRequest;

  @override
  Map<String, dynamic> payloadToJson() => {'locale': locale};

  factory LocaleRequestMessage.fromPayload(Map<String, dynamic> payload) =>
      LocaleRequestMessage(payload['locale'] as String? ?? '');
}
