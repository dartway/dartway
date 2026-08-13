import 'dw_push_notification.dart';

/// Identifiers a device reports alongside its token, so the server sends
/// through the transport that issued it instead of guessing.
///
/// The same strings as `DwPushProviders` on the server — pinned by a test on
/// both sides, never shared through a package.
abstract final class DwPushProviderIds {
  static const fcm = 'fcm';
  static const ruStore = 'rustore';
}

/// Whether the user lets this app show notifications.
enum DwPushPermission {
  granted,

  /// Refused, but asking again is still possible.
  denied,

  /// Refused for good; only the system settings screen can change it.
  permanentlyDenied,

  /// Nobody has asked yet.
  notDetermined,

  /// The platform has no such notion — a desktop build, or a transport that
  /// needs no permission at all.
  unsupported,
}

/// What a transport reports back while it is attached.
///
/// Callbacks rather than streams because both vendor SDKs hand out callbacks,
/// and a stream in between adds a lifecycle to get wrong for no gain.
final class DwPushProviderCallbacks {
  const DwPushProviderCallbacks({
    required this.onToken,
    required this.onOpened,
    required this.onReceived,
  });

  /// A token was issued or refreshed. May fire more than once with the same
  /// value; the plugin deduplicates.
  final void Function(String token) onToken;

  /// The user opened a notification.
  final void Function(Map<String, String> data, DwPushOpenSource source)
  onOpened;

  /// A notification arrived while the app was on screen.
  final void Function(DwPushReceived message) onReceived;
}

/// One push transport as the app half sees it: FCM, RuStore, or something an
/// app brings itself.
///
/// The core plugin owns everything that is the same whoever delivers — when to
/// ask for permission, when a token goes to the server, what happens between a
/// tap and a screen. This is the part that differs, and it is deliberately
/// small: five questions and two lifecycle calls.
abstract class DwPushClientProvider {
  const DwPushClientProvider();

  /// What the device reports to the server; see [DwPushProviderIds].
  String get id;

  /// Whether this transport can run on the platform this build is for.
  ///
  /// Answered without touching the SDK, so a plugin that only exists on
  /// Android can be declared by an app that also ships iOS and web, and simply
  /// stands aside there.
  bool get isSupportedPlatform;

  /// Whether it can run on *this device*, right now — the RuStore app being
  /// installed, Google Play services being present. Asked only when
  /// [isSupportedPlatform] is true.
  Future<bool> isAvailable() async => true;

  Future<DwPushPermission> currentPermission();

  /// Asks the user. Returns the resulting state, whatever it is; a refusal is
  /// an answer, not an error.
  Future<DwPushPermission> requestPermission();

  /// Starts listening. Called once, before [requestToken].
  Future<void> attach(DwPushProviderCallbacks callbacks);

  Future<void> detach();

  /// The current token, or null when the platform will not issue one (denied
  /// permission, no network yet, a simulator without APNs).
  Future<String?> requestToken();

  /// The notification that started the app, consumed exactly once.
  ///
  /// Separate from [DwPushProviderCallbacks.onOpened] because a cold start has
  /// nobody to call back to: the tap happened before there was an app.
  Future<Map<String, String>?> takeInitialPayload() async => null;
}
