import 'dart:convert';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:flutter_rustore_push/pigeons/rustore_push.dart';

/// RuStore as a push transport — Android devices with RuStore, inert
/// elsewhere. Declared before FCM it takes Android devices that have
/// RuStore, and the next transport takes the rest:
///
/// ```dart
/// DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)])
/// ```
///
/// Its native part replaces the SDK's messaging service: it writes each
/// message's data down on arrival (a tap may come back to a process that no
/// longer exists), draws data-only messages — the server sends a picture that
/// way — and hands taps back through [channel].
class DwRuStorePush extends DwPushTransportClient {
  DwRuStorePush({
    @visibleForTesting this.channel = const MethodChannel(channelName),
    @visibleForTesting this.sdk = const DwRuStoreSdk(),
    @visibleForTesting bool? isAndroid,
  }) : _isAndroid = isAndroid;

  /// The channel of the native part.
  static const String channelName = 'dartway_push_rustore';

  final MethodChannel channel;
  final DwRuStoreSdk sdk;
  final bool? _isAndroid;

  @override
  DwPushTransport get transport => DwPushTransport.rustore;

  @override
  bool get isSupportedPlatform =>
      _isAndroid ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<bool> isAvailable() => sdk.available();

  @override
  Future<DwPushPermission> permission() =>
      _permission('notificationPermissionStatus');

  @override
  Future<DwPushPermission> requestPermission() =>
      _permission('requestNotificationPermission');

  @override
  Future<void> attach(DwPushTransportEvents events) async {
    await sdk.attach(
      onToken: events.onToken,
      onReceived: (title, body, data) => events.onReceived(title, body, data),
    );
    channel.setMethodCallHandler((call) async {
      if (call.method != 'onPushOpened') return null;
      if (_decode(call.arguments as String?) case final data?) {
        events.onOpened(data, DwPushOpenSource.background);
      }
      return null;
    });
  }

  @override
  Future<void> detach() async => channel.setMethodCallHandler(null);

  @override
  Future<String?> token() => sdk.token();

  @override
  Future<Map<Object?, Object?>?> takeInitialOpen() async =>
      _decode(await channel.invokeMethod<String>('takeInitialPayload')) ??
      // A message the SDK holds and the native part never saw: one that
      // arrived while an older build was installed.
      await sdk.initialData();

  Future<DwPushPermission> _permission(String method) async =>
      switch (await channel.invokeMethod<String>(method)) {
        'granted' => DwPushPermission.granted,
        'denied' => DwPushPermission.denied,
        'permanentlyDenied' => DwPushPermission.permanentlyDenied,
        _ => DwPushPermission.notDetermined,
      };

  /// The stored payload JSON the native part hands over, as a data map.
  static Map<Object?, Object?>? _decode(String? json) {
    if (json == null || json.isEmpty) return null;
    return switch (jsonDecode(json)) {
      final Map<String, Object?> data => data,
      _ => throw FormatException('A RuStore payload is not an object: $json'),
    };
  }
}

/// The calls into `flutter_rustore_push` — a seam, because its static client
/// cannot be reached in a test.
class DwRuStoreSdk {
  const DwRuStoreSdk();

  Future<bool> available() => RustorePushClient.available();

  Future<String?> token() => RustorePushClient.getToken();

  Future<void> attach({
    required void Function(String token) onToken,
    required void Function(String? title, String? body, Map<Object?, Object?>)
    onReceived,
  }) => RustorePushClient.attachCallbacks(
    onNewToken: onToken,
    onDeletedMessages: () {},
    onMessageReceived: (message) {
      if (message is! Message) return;
      onReceived(message.notification?.title, message.notification?.body, {
        ...message.data,
      });
    },
    onError: (errors) => debugPrint('DwRuStorePush: $errors'),
  );

  Future<Map<Object?, Object?>?> initialData() async {
    final message = await RustorePushClient.getInitialMessage();
    return message == null ? null : {...message.data};
  }
}
