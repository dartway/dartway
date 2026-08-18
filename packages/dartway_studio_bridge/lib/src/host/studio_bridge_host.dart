import 'dart:async';

import 'package:flutter/foundation.dart';

import '../access/studio_bridge_token.dart';
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
typedef StudioInspectPoint =
    FutureOr<StudioFeatureInfo?> Function(
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
    this._validateAccessToken,
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
    // token it presents. Pass
    // `studioSignedAccessValidator(const String.fromEnvironment('STUDIO_APP_ORIGIN'))`
    // — a token signed by Studio and issued for this app's own address gets in,
    // and a build that names no address stays open for local dev. Null (or a
    // validator that always returns true) accepts any Studio — fine on a
    // laptop, wide open in production.
    Future<bool> Function(String accessToken)? validateAccessToken,
    // Answers the "pencil" tap-to-inspect flow. Null (the default for an app
    // that hasn't wired it) means every inspect request finds nothing —
    // Studio's own timeout treats that exactly like an old app that doesn't
    // know the message at all.
    StudioInspectPoint? inspectPoint,
    // The pipe to talk over. Defaults to the embedding window, which is the
    // only thing an app ever wants; pass one to drive the host from a test, or
    // to embed the app somewhere that is not an iframe.
    StudioMessageChannel? channel,
  }) {
    channel ??= createStudioHostChannel();
    if (channel == null) return null;
    return StudioBridgeHost._(
      channel,
      manifest,
      delegate,
      currentPath,
      currentSession,
      currentFeatures ?? () => const [],
      currentLocale ?? () => '',
      validateAccessToken ?? (_) async => true,
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
  final Future<bool> Function(String accessToken) _validateAccessToken;
  final StudioInspectPoint _inspectPoint;
  late final StreamSubscription<StudioBridgeMessage> _subscription;

  /// Set once a connecting Studio has presented an accepted token, and the
  /// gate on everything that follows. Without it the token would guard the
  /// manifest alone, and an embedding page that presented nothing could still
  /// walk the app through its screens or sign it in — which is precisely what
  /// this class documents that it does not allow.
  bool _connected = false;

  /// True once a Studio has been let in. Nothing crosses the bridge before it,
  /// in either direction, beyond the app-ready announcement.
  bool get isConnected => _connected;

  void _onMessage(StudioBridgeMessage message) {
    if (message case StudioConnectMessage(:final accessToken)) {
      _validateAccessToken(accessToken).then((accepted) {
        if (accepted) {
          _connected = true;
          _sendManifest();
          return;
        }
        // A refusal is answered only when the token was one — see
        // [looksLikeStudioBridgeToken] and [ConnectRefusedMessage]. Anything
        // else (nothing presented, a guess, noise) is met with silence, as it
        // always was: the app keeps running and the sender learns nothing.
        if (looksLikeStudioBridgeToken(accessToken)) {
          _channel.send(const ConnectRefusedMessage());
        }
      });
      return;
    }

    if (!_connected) return;

    switch (message) {
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
          _answerInspectPoint(requestId, horizontalFraction, verticalFraction),
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
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'dartway_studio_bridge',
          context: ErrorDescription('answering a Studio inspect-point request'),
        ),
      );
    }
    _channel.send(
      InspectPointResultMessage(requestId: requestId, feature: feature),
    );
  }

  void _sendManifest() => _channel.send(
    ManifestMessage(
      manifest: _manifest,
      currentPath: _currentPath(),
      session: _currentSession(),
      features: _currentFeatures(),
      currentLocale: _currentLocale(),
    ),
  );

  /// The reports below are dropped until a Studio has been let in. Nothing is
  /// lost by that: whoever connects is handed the whole state in the handshake
  /// response, so an unconnected app has nobody to tell anything to — while a
  /// page that has presented nothing would otherwise be sent the app's feature
  /// passports, `implementationNotes` and `knownIssues` included.
  void reportRoute(String path, {String? routeName}) {
    if (!_connected) return;
    _channel.send(RouteChangedMessage(path, routeName: routeName));
  }

  void reportSession(StudioSessionState session) {
    if (!_connected) return;
    _channel.send(SessionChangedMessage(session));
  }

  void reportFeatures(String path, List<StudioFeatureInfo> features) {
    if (!_connected) return;
    _channel.send(FeaturesChangedMessage(path: path, features: features));
  }

  void reportLocale(String locale) {
    if (!_connected) return;
    _channel.send(LocaleChangedMessage(locale));
  }

  void detach() {
    _connected = false;
    _subscription.cancel();
    _channel.dispose();
  }
}
