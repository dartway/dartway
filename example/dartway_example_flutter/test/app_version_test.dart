import 'dart:io';

import 'package:dartway_example_flutter/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the version the app reports is the one in pubspec.yaml', () {
    final version = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);
    expect(exampleAppVersion, version);
  });
}
