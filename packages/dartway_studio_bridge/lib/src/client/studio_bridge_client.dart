import 'dart:async';

import '../models/studio_feature_info.dart';
import '../protocol/studio_bridge_message.dart';
import '../transport/studio_message_channel.dart';
import 'studio_bridge_event.dart';

/// The Studio-side end of the bridge: handshakes with the app in the frame
/// (connect retries survive reloads of either side) and translates protocol
/// messages into [StudioProjectEvent]s.
class StudioBridgeClient {
  StudioBridgeClient({
    required StudioMessageChannel channel,
    this.accessKey = '',
    this.connectRetryInterval = const Duration(seconds: 2),
  }) : _channel = channel;

  final StudioMessageChannel _channel;

  /// The project's access secret, sent with every connect attempt so the app
  /// can decide whether to accept this Studio (see `StudioBridgeHost.attach`).
  final String accessKey;

  final Duration connectRetryInterval;

  final _events = StreamController<StudioProjectEvent>.broadcast();
  final _inspectResults = StreamController<StudioFeatureInfo?>.broadcast();
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

  void _sendConnect() =>
      _channel.send(StudioConnectMessage(accessKey: accessKey));

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
      case RouteChangedMessage(:final path, :final routeName):
        _events.add(StudioProjectRouteChanged(path, routeName: routeName));
      case SessionChangedMessage(:final session):
        _events.add(StudioProjectSessionChanged(session));
      case FeaturesChangedMessage(:final path, :final features):
        _events.add(
          StudioProjectFeaturesChanged(path: path, features: features),
        );
      case LocaleChangedMessage(:final locale):
        _events.add(StudioProjectLocaleChanged(locale));
      case InspectPointResultMessage(:final feature):
        _inspectResults.add(feature);
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

  /// The feature at a point given as fractions of the app's viewport (see
  /// [InspectPointRequestMessage]) — the "pencil" tap-to-inspect flow.
  /// Null when nothing is declared there, or the app never answers: an app
  /// built against an older bridge doesn't know this message and simply stays
  /// silent, which [timeout] turns into the same "nothing here" as a real
  /// miss rather than a hang.
  Future<StudioFeatureInfo?> inspectPoint(
    double horizontalFraction,
    double verticalFraction, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    final next = _inspectResults.stream.first;
    _channel.send(
      InspectPointRequestMessage(
        horizontalFraction: horizontalFraction,
        verticalFraction: verticalFraction,
      ),
    );
    return next.timeout(timeout, onTimeout: () => null);
  }

  void dispose() {
    _retryTimer?.cancel();
    _subscription?.cancel();
    _events.close();
    _inspectResults.close();
  }
}
