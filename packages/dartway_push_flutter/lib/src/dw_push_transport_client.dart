import 'package:dartway_push_shared/dartway_push_shared.dart';

/// How a notification reached the app when the user opened it.
enum DwPushOpenSource {
  /// The notification started the app.
  coldStart,

  /// The app was in the background and came forward.
  background,

  /// A web service worker handled the click and handed over the link.
  webClick,
}

/// Whether the user lets this app show notifications.
enum DwPushPermission {
  granted,

  /// Refused, and asking again is still possible.
  denied,

  /// Refused for good: only the system settings can change it.
  permanentlyDenied,

  /// Nobody has asked yet.
  notDetermined,

  /// The platform has no such permission.
  unsupported,

  /// Did not answer in time — the real state is unknown; ask again later.
  /// Never means "nobody has asked" ([notDetermined]) and never a guess at
  /// what the answer would have been: `DwPush.requestPermission` and
  /// `.permission` return this once their own deadline passes without an
  /// answer, and neither registers a token nor should a caller act as if
  /// permission were granted or refused.
  unanswered,
}

/// What a transport reports while attached. Callbacks, because both vendor
/// SDKs hand out callbacks; `DwPush` turns them into streams.
final class DwPushTransportEvents {
  const DwPushTransportEvents({
    required this.onToken,
    required this.onOpened,
    required this.onReceived,
  });

  /// A token was issued or refreshed; repeats of one value are harmless.
  final void Function(String token) onToken;

  /// The user opened a notification; `data` is its provider data map.
  final void Function(Map<Object?, Object?> data, DwPushOpenSource source)
  onOpened;

  /// A notification arrived while the app was on screen.
  final void Function(String? title, String? body, Map<Object?, Object?> data)
  onReceived;
}

/// One push transport as the app sees it — FCM, RuStore, or one a project
/// brings. `DwPush` owns everything that is the same whoever delivers: when
/// the token goes to the server, and what an opened notification carries.
abstract class DwPushTransportClient {
  const DwPushTransportClient();

  /// What the device registers its token as; the server sends through this
  /// transport's provider only.
  DwPushTransport get transport;

  /// Whether this transport can run on the platform of this build — answered
  /// without touching its SDK.
  bool get isSupportedPlatform;

  /// Whether it can run on this device now (RuStore installed, a Firebase app
  /// initialized). Asked only when [isSupportedPlatform].
  Future<bool> isAvailable() async => true;

  Future<DwPushPermission> permission();

  /// Asks the user; a refusal is an answer, not an error.
  Future<DwPushPermission> requestPermission();

  /// Starts listening. Called once, before [token].
  Future<void> attach(DwPushTransportEvents events);

  Future<void> detach();

  /// The current token, or `null` while the platform will not issue one
  /// (no permission, no APNs token yet).
  Future<String?> token();

  /// The data of the notification that started the app, consumed once.
  Future<Map<Object?, Object?>?> takeInitialOpen() async => null;
}
