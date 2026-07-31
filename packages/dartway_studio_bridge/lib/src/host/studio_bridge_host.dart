import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/studio_feature_info.dart';
import '../models/studio_project_manifest.dart';
import '../models/studio_session_state.dart';
import '../protocol/studio_bridge_message.dart';
import '../transport/host/studio_host_channel.dart';
import '../transport/studio_message_channel.dart';

/// What the app does when Studio asks — navigation and session actions run
/// inside the app through its regular flows (Studio never learns router
/// types; the sign-in credentials come from Studio's own project config).
abstract interface class StudioBridgeHostDelegate {
  void onNavigateRequest(String path);

  /// Sign in with the given test credentials through the app's normal auth
  /// flow — exactly as if the user typed them ([secret] is a test
  /// verification code for OTP flows, a password for password flows). The
  /// app ships no test users and no special sign-in path.
  Future<void> onSignInRequest(String identifier, String secret);

  Future<void> onSignOutRequest();

  /// Switch the app UI to [locale] (a tag from the manifest's
  /// `supportedLocales`). No-op for apps that declared none.
  void onLocaleRequest(String locale);
}

/// What is declared at a screen point, for the "pencil" tap-to-inspect flow.
/// The point arrives as fractions of the app's own viewport (see
/// [InspectPointRequestMessage]) — convert with the app's own logical
/// viewport size, not any size Studio thinks the frame is.
typedef StudioInspectPoint = FutureOr<StudioFeatureInfo?> Function(
  double horizontalFraction,
  double verticalFraction,
);

/// The app-side end of the Studio bridge: announces the app, answers the
/// handshake with the manifest, reports route/session changes and dispatches
/// Studio's requests to the [StudioBridgeHostDelegate].
class StudioBridgeHost {
  StudioBridgeHost._(
    this._channel,
    this._manifest,
    this._delegate,
    this._currentPath,
    this._currentSession,
    this._currentFeatures,
    this._currentLocale,
    this._validateAccessKey,
    this._inspectPoint,
  ) {
    _subscription = _channel.messages.listen(_onMessage);
    _channel.send(const AppReadyMessage());
  }

  /// True when running on web inside an iframe — the only context where
  /// attaching can succeed.
  static bool get isEmbeddedWebContext => isEmbeddedInStudioFrame;

  /// Attaches the bridge, or returns null when there is nothing to attach to
  /// (not web or not embedded in an iframe). Callers keep the app fully
  /// functional on null.
  static StudioBridgeHost? attach({
    required StudioProjectManifest manifest,
    required StudioBridgeHostDelegate delegate,
    required String Function() currentPath,
    required StudioSessionState Function() currentSession,
    List<StudioFeatureInfo> Function()? currentFeatures,
    String Function()? currentLocale,
    // Decides whether a connecting Studio may drive this app, from the access
    // key it presents. The bridge is agnostic to *how* — pass
    // `studioHashAccessValidator(const String.fromEnvironment('STUDIO_KEY_HASH'))`
    // for the baked-hash check, a server call, or your own scheme. Null (or a
    // validator that always returns true) accepts any Studio — fine for local
    // dev, wide open in production.
    Future<bool> Function(String accessKey)? validateAccessKey,
    // Answers the "pencil" tap-to-inspect flow. Null (the default for an app
    // that hasn't wired it) means every inspect request finds nothing —
    // Studio's own timeout treats that exactly like an old app that doesn't
    // know the message at all.
    StudioInspectPoint? inspectPoint,
  }) {
    final channel = createStudioHostChannel();
    if (channel == null) return null;
    return StudioBridgeHost._(
      channel,
      manifest,
      delegate,
      currentPath,
      currentSession,
      currentFeatures ?? () => const [],
      currentLocale ?? () => '',
      validateAccessKey ?? (_) async => true,
      inspectPoint ?? (_, _) => null,
    );
  }

  final StudioMessageChannel _channel;
  final StudioProjectManifest _manifest;
  final StudioBridgeHostDelegate _delegate;
  final String Function() _currentPath;
  final StudioSessionState Function() _currentSession;
  final List<StudioFeatureInfo> Function() _currentFeatures;
  final String Function() _currentLocale;
  final Future<bool> Function(String accessKey) _validateAccessKey;
  final StudioInspectPoint _inspectPoint;
  late final StreamSubscription<StudioBridgeMessage> _subscription;

  void _onMessage(StudioBridgeMessage message) {
    switch (message) {
      case StudioConnectMessage(:final accessKey):
        // Answer the handshake only if the access key is accepted; on refusal
        // stay silent — the app keeps running, Studio shows "not connected".
        _validateAccessKey(accessKey).then((accepted) {
          if (accepted) _sendManifest();
        });
      case NavigateRequestMessage(:final path):
        _delegate.onNavigateRequest(path);
      case SignInRequestMessage(:final identifier, :final secret):
        unawaited(_delegate.onSignInRequest(identifier, secret));
      case SignOutRequestMessage():
        unawaited(_delegate.onSignOutRequest());
      case LocaleRequestMessage(:final locale):
        _delegate.onLocaleRequest(locale);
      case InspectPointRequestMessage(
          :final requestId,
          :final horizontalFraction,
          :final verticalFraction,
        ):
        unawaited(
          _answerInspectPoint(
            requestId,
            horizontalFraction,
            verticalFraction,
          ),
        );
      default:
        break; // App → Studio messages echoed back are ignored.
    }
  }

  /// Answers an inspect request — and answers it even when the app's own
  /// [StudioInspectPoint] throws. Staying silent would be indistinguishable
  /// from an app that predates the message, so Studio would sit out its whole
  /// timeout and report a crash as "nothing declared here". The error is not
  /// swallowed either: it goes to [FlutterError.reportError], which in a
  /// DartWay app is the same path every other UI error takes.
  Future<void> _answerInspectPoint(
    String requestId,
    double horizontalFraction,
    double verticalFraction,
  ) async {
    StudioFeatureInfo? feature;
    try {
      feature = await _inspectPoint(horizontalFraction, verticalFraction);
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'dartway_studio_bridge',
        context: ErrorDescription('answering a Studio inspect-point request'),
      ));
    }
    _channel.send(
      InspectPointResultMessage(requestId: requestId, feature: feature),
    );
  }

  void _sendManifest() => _channel.send(ManifestMessage(
        manifest: _manifest,
        currentPath: _currentPath(),
        session: _currentSession(),
        features: _currentFeatures(),
        currentLocale: _currentLocale(),
      ));

  void reportRoute(String path, {String? routeName}) =>
      _channel.send(RouteChangedMessage(path, routeName: routeName));

  void reportSession(StudioSessionState session) =>
      _channel.send(SessionChangedMessage(session));

  void reportFeatures(String path, List<StudioFeatureInfo> features) =>
      _channel.send(FeaturesChangedMessage(path: path, features: features));

  void reportLocale(String locale) => _channel.send(LocaleChangedMessage(locale));

  void detach() {
    _subscription.cancel();
    _channel.dispose();
  }
}
