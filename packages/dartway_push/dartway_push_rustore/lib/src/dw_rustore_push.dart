import 'dart:convert';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:flutter_rustore_push/pigeons/rustore_push.dart';

const _channel = MethodChannel('dartway_push_rustore');

/// RuStore as a DartWay push transport — Android only.
///
/// ```dart
/// DwPush(config: DwPushConfig(providers: [DwRuStorePush(), DwFirebasePush()]))
/// ```
///
/// Declared alongside FCM it takes Android and stands aside everywhere else,
/// which is the arrangement an app shipping to RuStore and to the App Store
/// wants. On a device without the RuStore app it stands aside too, and the next
/// transport in the list gets its turn.
class DwRuStorePush extends DwPushClientProvider {
  DwRuStorePush();

  bool _isMethodHandlerAttached = false;

  @override
  String get id => DwPushProviderIds.ruStore;

  @override
  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAvailable() async {
    try {
      return await RustorePushClient.available();
    } catch (error) {
      debugPrint('DwRuStorePush: availability check failed: $error');
      return false;
    }
  }

  @override
  Future<DwPushPermission> currentPermission() =>
      _permissionCall('notificationPermissionStatus');

  @override
  Future<DwPushPermission> requestPermission() =>
      _permissionCall('requestNotificationPermission');

  @override
  Future<void> attach(DwPushProviderCallbacks callbacks) async {
    RustorePushClient.attachCallbacks(
      onNewToken: callbacks.onToken,
      onDeletedMessages: () {},
      onMessageReceived: (message) {
        if (message is! Message) return;
        callbacks.onReceived(
          DwPushReceived(
            title: message.notification?.title,
            body: message.notification?.body,
            data: _dataOf(message.data),
          ),
        );
      },
      onError: (errors) => debugPrint('DwRuStorePush: $errors'),
    );

    // The tap arrives through this plugin's own channel rather than the SDK's:
    // the notification may have been drawn by us, and either way the payload
    // was written down when the message arrived, long before the app existed.
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onPushOpened') return null;
      final data = _decodePayload(call.arguments as String?);
      if (data != null) {
        callbacks.onOpened(data, DwPushOpenSource.background);
      }
      return null;
    });
    _isMethodHandlerAttached = true;
  }

  @override
  Future<void> detach() async {
    if (!_isMethodHandlerAttached) return;
    _channel.setMethodCallHandler(null);
    _isMethodHandlerAttached = false;
  }

  @override
  Future<String?> requestToken() async {
    try {
      return await RustorePushClient.getToken();
    } catch (error) {
      debugPrint('DwRuStorePush: requesting the token failed: $error');
      return null;
    }
  }

  @override
  Future<Map<String, String>?> takeInitialPayload() async {
    try {
      final stored = await _channel.invokeMethod<String>('takeInitialPayload');
      final payload = _decodePayload(stored);
      if (payload != null) return payload;
    } catch (error) {
      debugPrint('DwRuStorePush: reading the stored payload failed: $error');
    }

    // Fallback for a message the SDK still holds and this plugin never saw —
    // one delivered while an older build was installed, for instance.
    try {
      final message = await RustorePushClient.getInitialMessage();
      final data = message?.data;
      return data == null ? null : _dataOf(data);
    } catch (error) {
      debugPrint('DwRuStorePush: reading the initial message failed: $error');
      return null;
    }
  }

  Future<DwPushPermission> _permissionCall(String method) async {
    try {
      final answer = await _channel.invokeMethod<String>(method);
      return switch (answer) {
        'granted' => DwPushPermission.granted,
        'denied' => DwPushPermission.denied,
        'permanentlyDenied' => DwPushPermission.permanentlyDenied,
        _ => DwPushPermission.notDetermined,
      };
    } catch (error) {
      debugPrint('DwRuStorePush: $method failed: $error');
      return DwPushPermission.notDetermined;
    }
  }

  Map<String, String>? _decodePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries)
          if (entry.key != null && entry.value != null)
            entry.key.toString(): entry.value.toString(),
      };
    } catch (error) {
      debugPrint('DwRuStorePush: the stored payload is not readable: $error');
      return null;
    }
  }

  Map<String, String> _dataOf(Map<String?, String?>? data) => {
    for (final entry in (data ?? const <String?, String?>{}).entries)
      if (entry.key != null && entry.value != null) entry.key!: entry.value!,
  };
}
