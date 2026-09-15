import 'package:dartway_push_shared/dartway_push_shared.dart';

import '../dw_push_transport_client.dart';

/// A transport whose SDK is this object, for widget tests: the token, the
/// permission and the taps come when the test says.
///
/// ```dart
/// final transport = DwFakePushTransport(issuedToken: 'device-1');
/// // build the core with DwPush(transports: [transport]) …
/// transport.open(DwPushData(payload: NewsAlert(id: 12)));
/// ```
final class DwFakePushTransport extends DwPushTransportClient {
  DwFakePushTransport({
    this.transport = DwPushTransport.fcm,
    this.supported = true,
    this.available = true,
    this.granted = true,
    this.issuedToken,
    Map<Object?, Object?>? initialOpen,
  }) : _initialOpen = initialOpen;

  @override
  final DwPushTransport transport;

  final bool supported;
  final bool available;

  /// Whether permission is granted; [requestPermission] grants it.
  bool granted;

  /// The token the platform issues once permission is granted.
  String? issuedToken;

  Map<Object?, Object?>? _initialOpen;
  DwPushTransportEvents? _events;

  /// How many times the plugin attached to it.
  int attachCount = 0;

  /// Whether the plugin is listening.
  bool get isAttached => _events != null;

  @override
  bool get isSupportedPlatform => supported;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DwPushPermission> permission() async =>
      granted ? DwPushPermission.granted : DwPushPermission.notDetermined;

  @override
  Future<DwPushPermission> requestPermission() async {
    granted = true;
    return DwPushPermission.granted;
  }

  @override
  Future<void> attach(DwPushTransportEvents events) async {
    attachCount++;
    _events = events;
  }

  @override
  Future<void> detach() async => _events = null;

  @override
  Future<String?> token() async => granted ? issuedToken : null;

  @override
  Future<Map<Object?, Object?>?> takeInitialOpen() async {
    final open = _initialOpen;
    _initialOpen = null;
    return open;
  }

  DwPushTransportEvents get _attached =>
      _events ?? (throw StateError('No DwPush is attached to this transport'));

  /// The platform refreshed the token.
  void refreshToken(String token) {
    issuedToken = token;
    _attached.onToken(token);
  }

  /// The user opened a notification carrying [data].
  void open(
    DwPushData data, {
    DwPushOpenSource source = DwPushOpenSource.background,
  }) => openRaw(data.toWire(), source: source);

  /// The user opened a notification with this raw provider data map.
  void openRaw(
    Map<Object?, Object?> data, {
    DwPushOpenSource source = DwPushOpenSource.background,
  }) => _attached.onOpened(data, source);

  /// A notification arrived while the app was on screen.
  void receive(Map<Object?, Object?> data, {String? title, String? body}) =>
      _attached.onReceived(title, body, data);
}
