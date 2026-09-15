import 'dart:convert';
import 'dart:io';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:dartway_push_rustore/dartway_push_rustore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeSdk extends DwRuStoreSdk {
  void Function(String token)? onToken;
  Map<Object?, Object?>? held;

  @override
  Future<bool> available() async => true;

  @override
  Future<String?> token() async => 'rustore-token';

  @override
  Future<void> attach({
    required void Function(String token) onToken,
    required void Function(String? title, String? body, Map<Object?, Object?>)
    onReceived,
  }) async => this.onToken = onToken;

  @override
  Future<Map<Object?, Object?>?> initialData() async => held;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(DwRuStorePush.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Map<String, Object?> nativeAnswers;
  setUp(() {
    nativeAnswers = {};
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => nativeAnswers[call.method],
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final payload = {
    ...const DwPushData(link: '/news/12').toWire(),
    DwPushData.titleKey: 'Drawn natively',
  };

  test('registers as the RuStore transport on Android only', () {
    expect(DwRuStorePush(isAndroid: true).transport, DwPushTransport.rustore);
    expect(DwRuStorePush(isAndroid: true).isSupportedPlatform, isTrue);
    expect(DwRuStorePush(isAndroid: false).isSupportedPlatform, isFalse);
  });

  test('reads the permission the native part answers', () async {
    final push = DwRuStorePush(isAndroid: true, sdk: FakeSdk());
    for (final (answer, permission) in [
      ('granted', DwPushPermission.granted),
      ('denied', DwPushPermission.denied),
      ('permanentlyDenied', DwPushPermission.permanentlyDenied),
      ('notDetermined', DwPushPermission.notDetermined),
    ]) {
      nativeAnswers['requestNotificationPermission'] = answer;
      expect(await push.requestPermission(), permission);
    }
  });

  test('a tap handed over by the native part opens with its data', () async {
    final sdk = FakeSdk();
    final push = DwRuStorePush(isAndroid: true, sdk: sdk);
    final opened = <(Map<Object?, Object?>, DwPushOpenSource)>[];
    await push.attach(
      DwPushTransportEvents(
        onToken: (_) {},
        onOpened: (data, source) => opened.add((data, source)),
        onReceived: (_, _, _) {},
      ),
    );
    await messenger.handlePlatformMessage(
      DwRuStorePush.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onPushOpened', jsonEncode(payload)),
      ),
      (_) {},
    );
    expect(opened.single.$1, payload);
    expect(opened.single.$2, DwPushOpenSource.background);
  });

  test('the notification that started the app is read from the native store, '
      'then from the SDK', () async {
    final sdk = FakeSdk()..held = {'dw_link': '/held'};
    final push = DwRuStorePush(isAndroid: true, sdk: sdk);
    nativeAnswers['takeInitialPayload'] = jsonEncode(payload);
    expect(await push.takeInitialOpen(), payload);
    nativeAnswers.remove('takeInitialPayload');
    expect(await push.takeInitialOpen(), {'dw_link': '/held'});
  });

  test('the native renderer reads the keys the server writes', () {
    final kotlin = File(
      'android/src/main/kotlin/dev/dartway/push/rustore/'
      'DwRuStoreNotificationContent.kt',
    ).readAsStringSync();
    String literal(String name) =>
        RegExp('$name = "([^"]+)"').firstMatch(kotlin)!.group(1)!;
    expect(literal('DW_TITLE_DATA_KEY'), DwPushData.titleKey);
    expect(literal('DW_BODY_DATA_KEY'), DwPushData.bodyKey);
    expect(literal('DW_IMAGE_DATA_KEY'), DwPushData.imageKey);
  });
}
