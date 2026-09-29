import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app edits exactly the settings the server accepts', () {
    expect({
      for (final setting in AppSettingKey.values) setting.key,
    }, AppSettingKeys.all);
  });

  test('a stored value is read as its type, and anything unreadable or absent '
      'is the default', () {
    const stored = [
      AppSetting(id: AppSettingKeys.appName, value: ' Acme '),
      AppSetting(id: AppSettingKeys.signUpEnabled, value: 'no'),
    ];
    expect(stored.valueOf(AppSettingKey.appName), 'Acme');
    expect(stored.valueOf(AppSettingKey.signUpEnabled), isFalse);
    expect(
      const <AppSetting>[].valueOf(AppSettingKey.signUpEnabled),
      AppSettingKey.signUpEnabled.defaultValue,
    );
    expect(AppSettingKey.signUpEnabled.parse('maybe'), isTrue);
  });
}
