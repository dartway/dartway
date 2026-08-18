import 'dart:async';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'web/dw_push_web_open_channel.dart';

/// Required by FCM before the app starts, and deliberately empty.
///
/// A notification message is drawn by the system without waking Dart; a
/// data-only message needs this handler to exist or the SDK complains. Doing
/// work here means doing it in a second isolate with no app around it — the
/// wrong place for anything an app cares about.
@pragma('vm:entry-point')
Future<void> dwFirebasePushBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging as a DartWay push transport — Android, iOS, web.
///
/// ```dart
/// DwPush(config: DwPushConfig(providers: [DwFirebasePush(webVapidKey: '...')]))
/// ```
///
/// The app is expected to have called `Firebase.initializeApp` already (it owns
/// `firebase_options.dart`); this transport says so plainly rather than
/// initializing a Firebase app of its own with options it would have to guess.
class DwFirebasePush extends DwPushClientProvider {
  DwFirebasePush({this.webVapidKey});

  /// The web push certificate key pair from the Firebase console. Web refuses
  /// to issue a token without it; the other platforms ignore it.
  final String? webVapidKey;

  static bool _backgroundHandlerRegistered = false;

  /// Registers the background handler. Call it in `main()` right after
  /// `Firebase.initializeApp` — FCM wants it before the app starts, and by the
  /// time the widget tree attaches the transport, a message may already have
  /// arrived.
  static void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) return;
    _backgroundHandlerRegistered = true;
    FirebaseMessaging.onBackgroundMessage(dwFirebasePushBackgroundHandler);
  }

  final List<StreamSubscription<Object?>> _subscriptions = [];
  void Function()? _stopListeningToWebOpens;

  @override
  String get id => DwPushProviderIds.fcm;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<bool> isAvailable() async {
    if (Firebase.apps.isNotEmpty) return true;
    debugPrint(
      'DwFirebasePush: no Firebase app is initialized. Call '
      'Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform) '
      'in main() before running the app.',
    );
    return false;
  }

  @override
  Future<DwPushPermission> currentPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _permissionOf(settings.authorizationStatus);
  }

  @override
  Future<DwPushPermission> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _permissionOf(settings.authorizationStatus);
    } catch (error) {
      debugPrint('DwFirebasePush: requesting permission failed: $error');
      return DwPushPermission.denied;
    }
  }

  @override
  Future<void> attach(DwPushProviderCallbacks callbacks) async {
    registerBackgroundHandler();

    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen(
        callbacks.onToken,
        onError: (Object error) =>
            debugPrint('DwFirebasePush: token refresh failed: $error'),
      ),
    );

    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) =>
            callbacks.onOpened(_dataOf(message), DwPushOpenSource.background),
        onError: (Object error) => debugPrint(
          'DwFirebasePush: opening from background failed: $error',
        ),
      ),
    );

    _subscriptions.add(
      FirebaseMessaging.onMessage.listen(
        (message) => callbacks.onReceived(
          DwPushReceived(
            title: message.notification?.title,
            body: message.notification?.body,
            data: _dataOf(message),
          ),
        ),
        onError: (Object error) =>
            debugPrint('DwFirebasePush: foreground message failed: $error'),
      ),
    );

    if (kIsWeb) {
      _stopListeningToWebOpens = listenWebPushOpen(
        (link) => callbacks.onOpened({
          dwPushLinkDataKey: link,
        }, DwPushOpenSource.webLink),
      );
    } else {
      // iOS shows nothing in the foreground unless it is told to. Android draws
      // its own notification and ignores this.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  @override
  Future<void> detach() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _stopListeningToWebOpens?.call();
    _stopListeningToWebOpens = null;
  }

  @override
  Future<String?> requestToken() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS issues an FCM token only once APNs has registered this install.
        // Asking earlier returns null, and asking again later succeeds — so
        // this is a "not yet", not a failure.
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('DwFirebasePush: no APNs token yet');
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken(vapidKey: webVapidKey);
    } catch (error) {
      debugPrint('DwFirebasePush: requesting the token failed: $error');
      return null;
    }
  }

  @override
  Future<Map<String, String>?> takeInitialPayload() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : _dataOf(message);
    } catch (error) {
      debugPrint('DwFirebasePush: reading the initial message failed: $error');
      return null;
    }
  }

  Map<String, String> _dataOf(RemoteMessage message) =>
      message.data.map((key, value) => MapEntry(key, value.toString()));

  DwPushPermission _permissionOf(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => DwPushPermission.granted,
        AuthorizationStatus.denied => DwPushPermission.denied,
        AuthorizationStatus.notDetermined => DwPushPermission.notDetermined,
      };
}
