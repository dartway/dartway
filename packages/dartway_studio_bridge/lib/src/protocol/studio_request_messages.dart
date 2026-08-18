part of 'studio_bridge_message.dart';

/// Studio → app: connection request; the app answers with a manifest message
/// only if it accepts [accessToken]. Sent on Studio start, retried while
/// unconnected, and re-sent whenever an app-ready message arrives (covers
/// reloads of either side).
///
/// [accessToken] is short-lived, signed by Studio and issued for one app
/// origin — see `verifyStudioBridgeToken` for the format and
/// `StudioBridgeHost.attach` for the app's side of the check. Nothing secret
/// travels here: the token is useless at any other address and expires on its
/// own, so a build accepts it while holding only a public key.
class StudioConnectMessage extends StudioBridgeMessage {
  const StudioConnectMessage({this.accessToken = ''});

  final String accessToken;

  @override
  String get type => StudioBridgeProtocol.studioConnect;

  @override
  Map<String, dynamic> payloadToJson() => {'accessToken': accessToken};

  factory StudioConnectMessage.fromPayload(Map<String, dynamic> payload) =>
      StudioConnectMessage(
        accessToken: payload['accessToken'] as String? ?? '',
      );
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
  const SignInRequestMessage({required this.identifier, required this.secret});

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

/// Studio → app: what feature, if any, is at this point on screen — the
/// "pencil" flow's tap-to-inspect. The point is given as *fractions* of the
/// app's own viewport (0.0 top/left, 1.0 bottom/right), not pixels: Studio may
/// be showing the preview scaled or letterboxed, but a fraction of the
/// viewport means the same point regardless of how it is currently displayed.
class InspectPointRequestMessage extends StudioBridgeMessage {
  const InspectPointRequestMessage({
    required this.requestId,
    required this.horizontalFraction,
    required this.verticalFraction,
  });

  /// Ties this request to the one answer that belongs to it. The app echoes it
  /// back untouched in [InspectPointResultMessage.requestId], and the
  /// requester matches on it instead of taking whatever result arrives next:
  /// inspect is the one request that can be in flight twice (a second tap
  /// while a slow first one is still being answered), and without an id the
  /// late answer to the first tap resolves the second — Studio would show a
  /// confidently wrong passport rather than nothing.
  ///
  /// Unique within one requester's session; the app treats it as opaque.
  final String requestId;

  final double horizontalFraction;
  final double verticalFraction;

  @override
  String get type => StudioBridgeProtocol.inspectPointRequest;

  @override
  Map<String, dynamic> payloadToJson() => {
    'requestId': requestId,
    'horizontalFraction': horizontalFraction,
    'verticalFraction': verticalFraction,
  };

  factory InspectPointRequestMessage.fromPayload(
    Map<String, dynamic> payload,
  ) => InspectPointRequestMessage(
    requestId: payload['requestId'] as String? ?? '',
    horizontalFraction:
        (payload['horizontalFraction'] as num?)?.toDouble() ?? 0,
    verticalFraction: (payload['verticalFraction'] as num?)?.toDouble() ?? 0,
  );
}
