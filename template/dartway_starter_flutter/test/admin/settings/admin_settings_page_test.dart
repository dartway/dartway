import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

/// The app settings over a fake server: saved one row at a time, and live.
void main() {
  testWidgets('a setting saves its own row, and one saved elsewhere arrives '
      'live', (tester) async {
    final fake = adminWith(const []);
    fake.server.onCommand<SaveAppSetting>((command, call) {
      final saved = AppSetting(id: command.key, value: command.value);
      fake.settings
        ..removeWhere((s) => s.id == saved.id)
        ..add(saved);
      call.publish(settingsChannel, [saved]);
      return DwCallOk(saved);
    });
    final app = await TestApp.start(tester, fake);
    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    await app.tap(tester, find.text('Settings'));

    expect(
      find.widgetWithText(TextField, AppSettingKey.appName.defaultValue),
      findsOneWidget,
    );
    await app.tap(tester, find.byType(Checkbox));
    expect(
      app.server.callsOf<SaveAppSetting>().single.call,
      const SaveAppSetting(key: AppSettingKeys.signUpEnabled, value: 'false'),
    );

    app.server.publish(settingsChannel, [
      const AppSetting(id: AppSettingKeys.appName, value: 'Acme'),
    ]);
    await app.settle(tester);
    expect(find.widgetWithText(TextField, 'Acme'), findsOneWidget);

    await app.stop(tester);
  });
}
