import 'package:dartway_example_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
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
}
