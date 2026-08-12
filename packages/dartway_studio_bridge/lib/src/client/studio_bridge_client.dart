import 'dart:async';

import '../models/studio_feature_info.dart';
import '../protocol/studio_bridge_message.dart';
import '../transport/studio_message_channel.dart';
import 'studio_bridge_event.dart';

/// Hands over the access token to present to the app, asked for once per
/// connect attempt rather than read once at construction: the token is
/// short-lived, and a preview stays open far longer than one — an app reload
/// hours later re-handshakes and has to carry a token that is still valid.
/// Caching a live one and issuing a new one when it runs out is the supplier's
/// business; the bridge only asks.
typedef StudioAccessTokenSupplier = FutureOr<String> Function();

/// The Studio-side end of the bridge: handshakes with the app in the frame
/// (connect retries survive reloads of either side) and translates protocol
/// messages into [StudioProjectEvent]s.
class StudioBridgeClient {
  StudioBridgeClient({
    required StudioMessageChannel channel,
    StudioAccessTokenSupplier? accessToken,
    this.connectRetryInterval = const Duration(seconds: 2),
  })  : _channel = channel,
        _accessToken = accessToken ?? _noAccessToken;

  static String _noAccessToken() => '';

  final StudioMessageChannel _channel;

  /// Where each connect attempt gets its token. Omitted, it presents nothing —
  /// which only an app in its zero-config local-dev mode accepts.
  final StudioAccessTokenSupplier _accessToken;

  final Duration connectRetryInterval;

  final _events = StreamController<StudioProjectEvent>.broadcast();

  /// Inspect requests still waiting for their answer, by request id. Keyed
  /// rather than kept as a single "latest" future because two taps can be in
  /// flight at once — see [InspectPointRequestMessage.requestId].
  final _pendingInspects = <String, Completer<StudioFeatureInfo?>>{};
  int _inspectCounter = 0;

  StreamSubscription<StudioBridgeMessage>? _subscription;
  Timer? _retryTimer;
  bool _connected = false;
  bool _connecting = false;
  bool _disposed = false;

  Stream<StudioProjectEvent> get events => _events.stream;

  void start() {
    _subscription ??= _channel.messages.listen(_onMessage);
    unawaited(_sendConnect());
    _retryTimer ??= Timer.periodic(connectRetryInterval, (_) {
      if (!_connected) unawaited(_sendConnect());
    });
  }

  /// One connect attempt: fetch a token, then present it.
  ///
  /// Attempts do not overlap — the retry timer keeps ticking while a slow
  /// supplier is still answering, and a queue of stale tokens behind it would
  /// help nobody. A supplier that fails leaves this attempt unsent and the next
  /// tick tries again; saying *why* it failed is the supplier's job, since only
  /// it knows.
  Future<void> _sendConnect() async {
    if (_connecting || _disposed) return;
    _connecting = true;
    try {
      final accessToken = await _accessToken();
      if (!_disposed) {
        _channel.send(StudioConnectMessage(accessToken: accessToken));
      }
    } catch (_) {
      // Nothing to present this time round; the retry timer comes back.
    } finally {
      _connecting = false;
    }
  }

  void _onMessage(StudioBridgeMessage message) {
    switch (message) {
      case AppReadyMessage():
        // The app (re)started — whatever we knew is stale; re-handshake, with
        // a token asked for afresh (the old one may have run out meanwhile).
        _connected = false;
        unawaited(_sendConnect());
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
      case InspectPointResultMessage(:final requestId, :final feature):
        // An answer whose request is gone (already timed out) is dropped, not
        // handed to whoever is waiting now.
        _pendingInspects.remove(requestId)?.complete(feature);
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
  ///
  /// Safe to call again while an earlier call is still pending: each request
  /// resolves with its own answer, and a request abandoned to [timeout] is
  /// forgotten rather than left to catch the next one's result.
  Future<StudioFeatureInfo?> inspectPoint(
    double horizontalFraction,
    double verticalFraction, {
    Duration timeout = const Duration(seconds: 3),
  }) {
    final requestId = 'inspect-${++_inspectCounter}';
    final pending = Completer<StudioFeatureInfo?>();
    _pendingInspects[requestId] = pending;
    _channel.send(
      InspectPointRequestMessage(
        requestId: requestId,
        horizontalFraction: horizontalFraction,
        verticalFraction: verticalFraction,
      ),
    );
    return pending.future.timeout(timeout, onTimeout: () {
      _pendingInspects.remove(requestId);
      return null;
    });
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _events.close();
    // Resolve, don't abandon: a caller awaiting an inspect when the preview
    // closes gets the same "nothing here" as a miss, instead of an error out
    // of a disposed client.
    for (final pending in _pendingInspects.values) {
      if (!pending.isCompleted) pending.complete(null);
    }
    _pendingInspects.clear();
  }
}
