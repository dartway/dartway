import 'package:dartway_example_flutter/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (buildNumber, expected) in [
    ('521', '1.0.0+521'),
    ('', '1.0.0+0'),
  ]) {
    test('platform build $buildNumber maps to $expected', () {
      final info = PackageInfo(
        appName: 'TestApp',
        packageName: 'com.example.testApp',
        version: '1.0.0',
        buildNumber: buildNumber,
      );
      expect(appVersionOf(info), expected);
    });
  }

  test('empty platform version uses the startup fallback', () {
    final info = PackageInfo(
      appName: 'TestApp',
      packageName: 'com.example.testApp',
      version: '',
      buildNumber: '521',
    );
    expect(appVersionOf(info), '0.0.0+0');
  });

  test('platform reading error uses the startup fallback', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(await readAppVersion(), '0.0.0+0');
  });
}
