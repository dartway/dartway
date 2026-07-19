import 'dart:async';

import '../protocol/studio_bridge_message.dart';
import '../transport/studio_message_channel.dart';
import 'studio_bridge_event.dart';

/// The Studio-side end of the bridge: handshakes with the app in the frame
/// (connect retries survive reloads of either side) and translates protocol
/// messages into [StudioProjectEvent]s.
class StudioBridgeClient {
  StudioBridgeClient({
    required StudioMessageChannel channel,
    this.connectRetryInterval = const Duration(seconds: 2),
  }) : _channel = channel;

  final StudioMessageChannel _channel;
  final Duration connectRetryInterval;

  final _events = StreamController<StudioProjectEvent>.broadcast();
  StreamSubscription<StudioBridgeMessage>? _subscription;
  Timer? _retryTimer;
  bool _connected = false;

  Stream<StudioProjectEvent> get events => _events.stream;

  void start() {
    _subscription ??= _channel.messages.listen(_onMessage);
    _sendConnect();
    _retryTimer ??= Timer.periodic(connectRetryInterval, (_) {
      if (!_connected) _sendConnect();
    });
  }

  void _sendConnect() => _channel.send(const StudioConnectMessage());

  void _onMessage(StudioBridgeMessage message) {
    switch (message) {
      case AppReadyMessage():
        // The app (re)started — whatever we knew is stale; re-handshake.
        _connected = false;
        _sendConnect();
      case ManifestMessage(
          :final manifest,
          :final currentPath,
          :final session,
          :final features,
          :final currentLocale,
        ):
        _connected = true;
        _events.add(StudioProjectConnected(
          manifest: manifest,
          currentPath: currentPath,
          session: session,
          features: features,
          currentLocale: currentLocale,
        ));
      case RouteChangedMessage(:final path):
        _events.add(StudioProjectRouteChanged(path));
      case SessionChangedMessage(:final session):
        _events.add(StudioProjectSessionChanged(session));
      case FeaturesChangedMessage(:final path, :final features):
        _events.add(
          StudioProjectFeaturesChanged(path: path, features: features),
        );
      case LocaleChangedMessage(:final locale):
        _events.add(StudioProjectLocaleChanged(locale));
      default:
        break; // Studio → app messages echoed back are ignored.
    }
  }

  void requestNavigation(String path) =>
      _channel.send(NavigateRequestMessage(path));

  /// Ask the app to sign in with the given test credentials (from Studio's
  /// project config) through its regular auth flow. [secret] is whatever the
  /// app's auth expects: a test verification code, or a password.
  void requestSignIn({
    required String identifier,
    required String secret,
  }) =>
      _channel.send(SignInRequestMessage(
        identifier: identifier,
        secret: secret,
      ));

  void requestSignOut() => _channel.send(const SignOutRequestMessage());

  void requestLocale(String locale) =>
      _channel.send(LocaleRequestMessage(locale));

  void dispose() {
    _retryTimer?.cancel();
    _subscription?.cancel();
    _events.close();
  }
}
