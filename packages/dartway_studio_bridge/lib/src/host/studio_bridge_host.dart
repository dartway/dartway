import 'dart:async';

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
    );
  }

  final StudioMessageChannel _channel;
  final StudioProjectManifest _manifest;
  final StudioBridgeHostDelegate _delegate;
  final String Function() _currentPath;
  final StudioSessionState Function() _currentSession;
  final List<StudioFeatureInfo> Function() _currentFeatures;
  final String Function() _currentLocale;
  late final StreamSubscription<StudioBridgeMessage> _subscription;

  void _onMessage(StudioBridgeMessage message) {
    switch (message) {
      case StudioConnectMessage():
        _channel.send(ManifestMessage(
          manifest: _manifest,
          currentPath: _currentPath(),
          session: _currentSession(),
          features: _currentFeatures(),
          currentLocale: _currentLocale(),
        ));
      case NavigateRequestMessage(:final path):
        _delegate.onNavigateRequest(path);
      case SignInRequestMessage(:final identifier, :final secret):
        unawaited(_delegate.onSignInRequest(identifier, secret));
      case SignOutRequestMessage():
        unawaited(_delegate.onSignOutRequest());
      case LocaleRequestMessage(:final locale):
        _delegate.onLocaleRequest(locale);
      default:
        break; // App → Studio messages echoed back are ignored.
    }
  }

  void reportRoute(String path) => _channel.send(RouteChangedMessage(path));

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
