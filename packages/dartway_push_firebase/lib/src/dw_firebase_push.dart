import 'dart:async';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'web/dw_web_push_click.dart';

/// Required by FCM before the app starts, and deliberately empty: a
/// notification message is drawn by the system without Dart, and work here
/// would run in a second isolate with no app around it.
@pragma('vm:entry-point')
Future<void> dwFirebasePushBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging as a push transport — Android, iOS and web.
///
/// The app owns `Firebase.initializeApp` (and its `firebase_options.dart`),
/// called in `main` before `dw.init()`; without an initialized Firebase app
/// this transport reports itself unavailable. On the web copy
/// `web/firebase-messaging-sw.js` of this package into the app's `web/`
/// unchanged except for the config: the order of its handlers is what makes
/// a click open the notification's link.
///
/// On iOS none of FCM's calls answer before APNs has registered the install,
/// and some never answer when that does not happen: in the simulator, which
/// has no APNs, or on a device whose bundle id differs from the one in
/// `GoogleService-Info.plist`. `DwPush` keeps them off the app's start and
/// reports the one that stays silent.
class DwFirebasePush extends DwPushTransportClient {
  DwFirebasePush({this.webVapidKey});

  /// The web push key pair from the Firebase console; the browser issues no
  /// token without it.
  final String? webVapidKey;

  /// The `type` of the message the service worker posts to an open tab.
  static const String webOpenMessageType = 'dw-push-open';

  static bool _backgroundHandlerRegistered = false;

  /// Registers the background handler FCM wants before the app starts: call
  /// it in `main` right after `Firebase.initializeApp`.
  static void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered || kIsWeb) return;
    _backgroundHandlerRegistered = true;
    FirebaseMessaging.onBackgroundMessage(dwFirebasePushBackgroundHandler);
  }

  final List<StreamSubscription<Object?>> _subscriptions = [];
  void Function()? _stopWebClicks;

  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  bool get isSupportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Future<bool> isAvailable() async => Firebase.apps.isNotEmpty;

  @override
  Future<DwPushPermission> permission() async => _permissionOf(
    (await FirebaseMessaging.instance.getNotificationSettings())
        .authorizationStatus,
  );

  @override
  Future<DwPushPermission> requestPermission() async => _permissionOf(
    (await FirebaseMessaging.instance.requestPermission()).authorizationStatus,
  );

  @override
  Future<void> attach(DwPushTransportEvents events) async {
    final messaging = FirebaseMessaging.instance;
    _subscriptions
      ..add(messaging.onTokenRefresh.listen(events.onToken))
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) =>
              events.onOpened(message.data, DwPushOpenSource.background),
        ),
      )
      ..add(
        FirebaseMessaging.onMessage.listen(
          (message) => events.onReceived(
            message.notification?.title,
            message.notification?.body,
            message.data,
          ),
        ),
      );
    if (kIsWeb) {
      _stopWebClicks = listenWebPushClicks(
        (data) => events.onOpened(data, DwPushOpenSource.webClick),
      );
    } else {
      // iOS shows nothing in the foreground unless told to.
      await messaging.setForegroundNotificationPresentationOptions(
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
    _stopWebClicks?.call();
    _stopWebClicks = null;
  }

  @override
  Future<String?> token() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // No FCM token before APNs registered the install: a "not yet" that
      // `onTokenRefresh` answers later.
      if (await FirebaseMessaging.instance.getAPNSToken() == null) return null;
    }
    return FirebaseMessaging.instance.getToken(vapidKey: webVapidKey);
  }

  @override
  Future<Map<Object?, Object?>?> takeInitialOpen() async =>
      (await FirebaseMessaging.instance.getInitialMessage())?.data;

  static DwPushPermission _permissionOf(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => DwPushPermission.granted,
        AuthorizationStatus.denied => DwPushPermission.denied,
        AuthorizationStatus.notDetermined => DwPushPermission.notDetermined,
        // `deniedPermanently` exists from firebase_messaging 16 only; named
        // rather than referenced so both supported majors compile.
        _ when status.name == 'deniedPermanently' =>
          DwPushPermission.permanentlyDenied,
        _ => DwPushPermission.denied,
      };
}
