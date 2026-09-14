import 'package:dartway_example_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app edits exactly the settings the server accepts', () {
    expect(
      {for (final setting in AppSettingKey.values) setting.key},
      {...exampleSettingKeys},
    );
  });
}
